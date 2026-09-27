return function(t)
    local function enable(slots, items)
        local p = t.preferences()
        p.background = { enabled=true, free_slots=slots or 1, items=items or {} }
    end
    local function settle()
        t.get('automatic').tick()
        t.advance(2)
        t.get('automatic').tick()
    end

    t.test('enabled care refills the explicit carried target from its chosen bag', function()
        local p = t.preferences()
        p.background = { enabled=true, free_slots=1, items={} }
        p.item_rules = { version=1, items={
            ['4096']={ carry_target=24, destination=5, deposit=false },
        } }
        t.put(0,1,4096,6)
        t.put(0,2,4097,12)
        t.put(5,1,4096,12)
        t.put(5,2,4096,12)

        settle()
        local move = t.moves()[1]
        assert(move and move.purpose=='refill' and move.item_id==4096
            and move.source_container_id==5 and move.target_container_id==0 and move.quantity==12,
            'did not refill from the selected destination first')

        t.put(5,1,nil); t.put(0,3,4096,12); t.bump_inventory()
        t.advance(2); t.get('automatic').tick()
        t.advance(2); t.get('automatic').tick()
        move = t.moves()[2]
        assert(move and move.purpose=='refill' and move.quantity==6 and move.source_index==2,
            'did not refill only the remaining carried shortfall')
    end)

    t.test('background clearing discovers an exact route outside portable bags', function()
        local p=t.preferences()
        p.background={enabled=true,free_slots=1,items={}}
        p.item_rules={version=1,items={['901']={
            carry_target=0,destination=1,deposit=false,
        }}}
        t.capacity(0,1)
        t.capacity(1,1)
        t.put(0,1,901,12)
        settle()
        assert(#t.moves()==1 and t.moves()[1].target_container_id==1,
            'automatic snapshot did not include the exact per-item destination')
    end)

    t.test('manual and automatic item routes stay exact when the chosen bag is full', function()
        local p=t.preferences()
        p.item_rules={version=1,items={['901']={
            carry_target=0,destination=6,deposit=false,
        }}}
        t.put(0,1,901,12)
        local state=assert(t.get('collect_live_items')())
        local plan=assert(t.get('build_organize_plan')(state,{
            scope='storage',character_slug='Offline_42',
        }))
        local queue=assert(t.get('build_physical_queue')(plan.logical_moves,state))
        assert(#queue==1 and queue[1].target_container_id==6,
            'manual organization did not use the exact item destination')

        t.capacity(0,1); t.capacity(6,1); t.put(6,1,902,12)
        state=assert(t.get('collect_live_items')())
        plan=assert(t.get('build_organize_plan')(state,{
            scope='storage',character_slug='Offline_42',
        }))
        queue=select(1,t.get('build_physical_queue')(plan.logical_moves,state))
        assert(queue==nil,'manual organization fell back from the full exact destination')

        p.background={enabled=true,free_slots=1,items={}}
        settle()
        assert(#t.moves()==0,'automatic clearing fell back from the full exact destination')
    end)

    t.test('background disabled never moves an item', function()
        t.put(0, 1, 4096, 12)
        t.get('automatic').tick()
        t.advance(5); t.get('automatic').tick()
        assert(#t.moves() == 0)
    end)

    t.test('enabled background waits for a stable scene then moves whole crystal stack', function()
        enable(4)
        t.put(0, 1, 4096, 12)
        t.get('automatic').tick()
        assert(#t.moves() == 0)
        t.advance(2); t.get('automatic').tick()
        assert(#t.moves() == 1 and t.moves()[1].quantity == 12)
        assert(t.moves()[1].source_container_id == 0 and t.moves()[1].target_container_id == 5)
    end)

    t.test('noncrystal requires explicit opt in while exclusions and protections win', function()
        enable(4, { ['901']=true, ['4097']=false })
        t.put(0,1,901,12); t.put(0,2,4097,12); t.put(0,3,900,1); t.put(0,4,902,12,1)
        settle()
        assert(#t.moves() == 1 and t.moves()[1].item_id == 901)
    end)

    t.test('keep reserve prevents partial protected stack from being moved', function()
        t.reset({ ['4096']=6 })
        enable(4)
        t.put(0,1,4096,12); t.put(0,2,4097,12)
        settle()
        assert(#t.moves() == 1 and t.moves()[1].item_id == 4097)
    end)

    t.test('full portable bags still use matching stack capacity only', function()
        enable(4)
        t.capacity(5,1); t.capacity(6,1); t.capacity(7,1)
        t.put(0,1,4096,6); t.put(5,1,4096,6); t.put(6,1,901,12); t.put(7,1,902,12)
        settle()
        assert(#t.moves() == 1 and t.moves()[1].target_container_id == 5)
        assert(t.moves()[1].quantity == 6)
    end)

    t.test('pending background transfer does not resend and timeout pauses', function()
        enable(4); t.put(0,1,4096,12); settle()
        assert(#t.moves() == 1 and t.get('automatic').pending)
        t.get('automatic').tick(); assert(#t.moves() == 1)
        t.advance(6); t.get('automatic').tick()
        assert(#t.moves() == 1 and t.get('automatic').paused)
    end)

    t.test('confirmed background transfer clears pending without an immediate resend', function()
        enable(4); t.put(0,1,4096,12); settle()
        local move = t.moves()[1]
        t.put(0,1,nil); t.put(move.target_container_id,1,4096,12); t.bump_inventory()
        t.get('automatic').tick()
        assert(not t.get('automatic').pending and #t.moves() == 1)
    end)

    t.test('zoning and event status prevent background work', function()
        enable(4); t.put(0,1,4096,12)
        for _, state in ipairs({ {zoning=1,status=0}, {zoning=0,status=4} }) do
            t.player(state); t.get('automatic').tick(); t.advance(3); t.get('automatic').tick()
            assert(#t.moves() == 0)
        end
    end)

    t.test('unknown character identity and inaccessible destinations prevent work', function()
        enable(4); t.put(0,1,4096,12)
        t.character('Offline', 0); settle(); assert(#t.moves() == 0)
        t.character('Offline', 42); t.capacity(5,0); t.capacity(6,0); t.capacity(7,0)
        t.get('automatic').next_check = 0; settle(); assert(#t.moves() == 0)
    end)

    t.test('manual retrieval holds item and cancels queue; injected staging is ignored', function()
        enable(4); t.put(5,2,4096,12); t.put(0,1,4097,12); settle()
        local auto = t.get('automatic')
        assert(auto.pending)
        local data = string.char(0,0,0,0,12,0,0,0,5,0,2,0)
        t.packet({id=0x029, injected=false, blocked=false, data=data})
        assert(auto.manual_pending and not auto.holds['4096'] and auto.pending == nil)
        t.put(5,2,nil); t.put(0,2,4096,12); t.bump_inventory()
        t.advance(2); auto.tick()
        assert(auto.holds['4096'] and auto.holds['4096']['0']==12)
        auto.holds = {}
        t.packet({id=0x029, injected=true, blocked=false, data=data})
        assert(not auto.holds['4096'])
    end)

    t.test('native retrieval hold protects sorting and deposit until released', function()
        t.put(5,2,4096,12)
        local data = string.char(0,0,0,0,12,0,0,0,5,0,2,0)
        t.packet({id=0x029, injected=false, blocked=false, data=data})
        t.put(5,2,nil); t.put(0,1,4096,12); t.bump_inventory()
        t.advance(2); t.get('automatic').tick()
        t.put(5,2,nil); t.put(0,1,4096,12)
        local snapshot = assert(t.get('collect_live_items')())
        local reserved = assert(t.get('get_keep_reservations')(snapshot))
        assert(reserved['0:1'] == 12)
        local plan = assert(t.get('build_organize_plan')(snapshot, {scope='storage',character_slug='Offline_42'}))
        assert(#plan.logical_moves == 0)
        local queue, summary = t.get('build_ephemeral_dump_queue')({scope='all',character_slug='Offline_42'})
        assert(queue and #queue == 0 and summary.kept_quantity == 12)
        t.get('automatic').holds['4096'] = nil
        queue = assert(t.get('build_ephemeral_dump_queue')({scope='all',character_slug='Offline_42'}))
        assert(#queue == 1 and queue[1].item_id == 4096)
    end)

    t.test('confirmed partial manual moves hold only moved stock and shrink after use', function()
        t.put(5,1,4096,12)
        local data = string.char(0,0,0,0,6,0,0,0,5,0,1,0)
        t.packet({id=0x029,injected=false,blocked=false,data=data})
        assert(not t.get('automatic').holds['4096'], 'unconfirmed move changed item policy')
        t.put(5,1,4096,6); t.put(0,1,4096,6); t.bump_inventory()
        t.advance(2); t.get('automatic').tick()
        local auto=t.get('automatic')
        assert(auto.holds['4096']['0']==6,'temporary hold did not match the confirmed partial quantity')

        t.put(0,2,4096,12); t.bump_inventory()
        local snapshot=assert(t.get('collect_live_items')())
        local reserved=assert(t.get('get_keep_reservations')(snapshot))
        assert(reserved['0:1']==6 and (reserved['0:2'] or 0)==0,
            'new copies inherited the old manual move override')

        t.put(0,1,4096,3); t.bump_inventory()
        snapshot=assert(t.get('collect_live_items')())
        reserved=assert(t.get('get_keep_reservations')(snapshot))
        assert(reserved['0:1']==3,'used carried stock did not reduce the temporary hold')
    end)

    t.test('locked eligible crystal is never moved by background clearing', function()
        enable(4); t.put(0,1,4096,12,1); settle()
        assert(#t.moves() == 0)
    end)

    t.test('background snapshot rejects a changing global inventory counter', function()
        t.put(0,1,4096,12); t.unstable_counter(true)
        assert(t.get('automatic').snapshot() == nil)
    end)

    t.test('background configuration persists on off slots and item choices', function()
        local auto = t.get('automatic')
        auto.configure('on'); assert(t.saved().background.enabled == true)
        auto.configure('slots', '3'); assert(t.saved().background.free_slots == 3)
        auto.configure('item', '901', true); assert(t.saved().background.items['901'] == true)
        auto.configure('off'); assert(t.saved().background.enabled == false)
    end)

    t.test('settings callback isolates retrieval holds across characters', function()
        local auto = t.get('automatic')
        auto.owner, auto.holds = 'Offline_42', { ['4096']=true }
        t.character('Alt', 43)
        t.settings_update({keep={},background={enabled=false,free_slots=5,items={}}})
        assert(auto.owner == 'Alt_43' and next(auto.holds) == nil)
    end)

    t.test('Moogle discovery works without a selected target and saved identity is zone bound', function()
        t.select_target(0)
        local target = assert(t.get('validate_ephemeral_target')())
        assert(target.index == 7 and target.server_id == 1007)
        local eph = t.get('ephemeral'); eph.target, eph.running = target, true
        t.npc({id=1008}); assert(t.get('validate_ephemeral_target')() == nil)
        t.npc({id=1007}); t.player({zone=101}); assert(t.get('validate_ephemeral_target')() == nil)
    end)
end
