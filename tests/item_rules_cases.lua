return function(t)
    local rules = require('item_rules')

    t.test('specific item destinations override quicksets without changing defaults', function()
        local fallback = { destination=6, allowed=true, deposit=true }
        local default = { version=1, items={ ['4096']={
            carry_target=24, destination='default', deposit=false,
        } } }
        local exact = { version=1, items={ ['4096']={
            carry_target=24, destination=5, deposit=false,
        } } }
        local stay = { version=1, items={ ['4096']={
            carry_target=24, destination='stay', deposit=false,
        } } }
        assert(rules.validate(nil))
        local rule = assert(rules.for_item(default,4096))
        local destination, mode = rules.destination(rule,fallback.destination)
        assert(destination==6 and mode=='default' and rules.allows_storage(rule,fallback.allowed))
        rule = assert(rules.for_item(exact,4096))
        destination, mode = rules.destination(rule,fallback.destination)
        assert(destination==5 and mode=='specific' and rules.allows_storage(rule,false))
        rule = assert(rules.for_item(stay,4096))
        destination, mode = rules.destination(rule,fallback.destination)
        assert(destination==nil and mode=='stay' and not rules.allows_storage(rule,true))
        assert(not rules.allows_deposit(rule,true),'a saved storage-only rule inherited legacy deposit permission')
        assert(rules.allows_deposit(nil,true),'unconfigured items lost their prior deposit behavior')
    end)

    t.test('item outcome validation requires explicit safe deposit staging', function()
        local function config(item_id, destination, deposit)
            return {version=1,items={[tostring(item_id)]={
                carry_target=24,destination=destination,deposit=deposit,
            }}}
        end
        assert(rules.validate(config(4096,6,true)))
        assert(not rules.validate(config(4096,'default',true)))
        assert(not rules.validate(config(4096,2,true)))
        assert(not rules.validate(config(901,6,true)))
        assert(not rules.validate(config(4096,3,false)))
        local gear={item_id=100,equippable=true}
        local general={item_id=901,equippable=false}
        assert(rules.validate_for_item({destination=10,deposit=false},gear))
        assert(not rules.validate_for_item({destination=10,deposit=false},general))
    end)

    t.test('legacy Ignore reservation and carried target reserve distinct stock', function()
        local stock={
            {container_id=0,index=1,item_id=4096,quantity=3},
            {container_id=5,index=1,item_id=4096,quantity=8},
        }
        local config={version=1,items={ ['4096']={
            carry_target=8,destination=5,deposit=false,
        }}}
        local reserved=assert(rules.allocate(stock,{['4096']=5},config,{}))
        assert(reserved['0:1']==3,'carried target did not protect the current Inventory stock')
        assert(reserved['5:1']==2,'legacy Ignore quantity did not remain protected in storage')
        assert(8-reserved['5:1']==6,'eligible stored stock was over-reserved')
    end)

    t.test('temporary overrides reserve exact item quantities at exact bags', function()
        local stock={
            {container_id=0,index=1,item_id=4096,quantity=12},
            {container_id=6,index=1,item_id=4096,quantity=12},
            {container_id=6,index=2,item_id=4096,quantity=6},
        }
        local config={version=1,items={ ['4096']={
            carry_target=8,destination=6,deposit=false,
        }}}
        local reserved=assert(rules.allocate(stock,{},config,{['4096']={['6']=5}}))
        assert(reserved['0:1']==8,'carried target was not reserved in Inventory')
        assert(reserved['6:1']==5 and (reserved['6:2'] or 0)==0,
            'temporary quantity escaped its selected bag or exceeded its bound')
    end)

    t.test('short carried supply earmarks only eligible stored stock for refill', function()
        local stock={
            {container_id=6,index=1,item_id=4096,quantity=2},
            {container_id=5,index=1,item_id=4096,quantity=4},
            {container_id=2,index=1,item_id=4096,quantity=12},
            {container_id=7,index=1,item_id=4096,quantity=4,locked=true},
        }
        local config={version=1,items={ ['4096']={
            carry_target=5,destination=6,deposit=false,
        }}}
        local protected=assert(rules.allocate(stock,{},config,{}))
        local refill=assert(rules.refill_reservations(stock,protected,config))
        assert(refill['6:1']==2 and refill['5:1']==3,
            'refill did not prefer the saved destination and then use accessible stock')
        assert(refill['2:1']==nil and refill['7:1']==nil,
            'refill reserved restricted or locked stock')
    end)

    t.test('Ignore stock stays protected while only the remaining shortfall is refillable', function()
        local stock={
            {container_id=0,index=1,item_id=4096,quantity=1},
            {container_id=5,index=1,item_id=4096,quantity=5},
        }
        local config={version=1,items={ ['4096']={
            carry_target=4,destination=5,deposit=false,
        }}}
        local protected=assert(rules.allocate(stock,{['4096']=3},config,{}))
        local refill=assert(rules.refill_reservations(stock,protected,config))
        assert(protected['0:1']==1 and protected['5:1']==2)
        assert(refill['5:1']==3,'refill took protected stock or exceeded the carry shortfall')
    end)

    t.test('confirmed partial moves transfer overrides and observed use consumes them', function()
        local overrides={}
        assert(rules.record_manual_move(overrides,4096,6,0,5))
        assert(overrides['4096']['0']==5)
        assert(rules.record_manual_move(overrides,4096,0,5,2))
        assert(overrides['4096']['0']==3 and overrides['4096']['5']==2)
        assert(rules.consume_override(overrides,4096,0,1)==1)
        assert(overrides['4096']['0']==2)
        assert(rules.release_override(overrides,4096) and overrides['4096']==nil)
    end)

    t.test('temporary reservations shrink with consumed stock and never include new copies', function()
        local overrides={ ['4096']={ ['0']=8, ['5']=4 } }
        local previous={ ['4096:0']=12, ['4096:5']=6 }
        local live={
            {container_id=0,index=1,item_id=4096,quantity=7},
            {container_id=5,index=1,item_id=4096,quantity=6},
        }
        local ok
        ok, previous=rules.reconcile_overrides(overrides,live,previous)
        assert(ok and overrides['4096']['0']==3 and overrides['4096']['5']==4,
            'consumed location stock did not reduce the temporary hold')
        live[#live+1]={container_id=0,index=2,item_id=4096,quantity=12}
        ok, previous=rules.reconcile_overrides(overrides,live,previous)
        assert(ok and overrides['4096']['0']==3,
            'newly collected items inherited an old location hold')
        live={
            {container_id=0,index=2,item_id=4096,quantity=12},
            {container_id=5,index=1,item_id=4096,quantity=6},
        }
        ok=rules.reconcile_overrides(overrides,live,previous)
        assert(ok and overrides['4096']['0']==nil and overrides['4096']['5']==4)
    end)
end
