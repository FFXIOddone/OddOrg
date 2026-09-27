return function(t)
    t.test('nearby deposits default off and do not trade', function()
        t.put(0,1,4096,12); t.moogle_tick(); t.ephemeral_tick(); assert(#t.trades()==0)
    end)

    t.test('incomplete Inventory blocks nearby deposit pass', function()
        t.preferences().deposit_enabled=true; t.put(0,1,4096,12); t.update_flags(0x1FFFF-1)
        t.moogle_tick(); t.advance(3); t.moogle_tick(); t.ephemeral_tick(); assert(#t.trades()==0)
    end)

    t.test('no-op Moogle pass runs once until outside rearm radius for two seconds', function()
        local p=t.preferences(); p.deposit_enabled=true
        t.moogle_tick(); local pass=t.get('moogle').pass
        assert(pass and pass.claimed and not t.get('ephemeral').running)
        t.put(0,1,4096,12); t.advance(1); t.moogle_tick()
        assert(t.get('moogle').pass==pass and not t.get('ephemeral').running)
        t.npc({distance=81}); t.advance(1); t.moogle_tick(); assert(t.get('moogle').pass)
        t.advance(2); t.moogle_tick(); assert(not t.get('moogle').pass)
        t.npc({distance=4}); t.advance(1); t.moogle_tick()
        assert(t.get('ephemeral').running and t.get('ephemeral').automatic)
    end)

    t.test('six to eight yalms preserves claimed pass without sending', function()
        t.preferences().deposit_enabled=true; t.moogle_tick()
        local pass=t.get('moogle').pass; t.npc({distance=49}); t.put(0,1,4096,12)
        t.advance(3); t.moogle_tick(); t.ephemeral_tick()
        assert(t.get('moogle').pass==pass and #t.trades()==0)
    end)

    t.test('Moogle identity drift must clear for two seconds before rearming', function()
        t.preferences().deposit_enabled=true; t.moogle_tick(); assert(t.get('moogle').pass)
        t.npc({id=1008}); t.advance(1); t.moogle_tick(); assert(t.get('moogle').pass)
        t.advance(2); t.moogle_tick(); assert(not t.get('moogle').pass)
    end)

    t.test('manual retrieval cancels automatic deposit and applies hold', function()
        local p=t.preferences(); p.deposit_enabled=true
        t.put(0,1,4096,12); t.put(5,2,4097,12); t.moogle_tick()
        assert(t.get('ephemeral').running)
        local data=string.char(0,0,0,0,12,0,0,0,5,0,2,0)
        t.packet_out({id=0x029,injected=false,blocked=false,data=data})
        assert(not t.get('ephemeral').running and t.get('automatic').manual_pending)
        t.put(5,2,nil); t.put(0,2,4097,12); t.bump_inventory()
        t.advance(2); t.automatic_tick()
        assert(t.get('automatic').holds['4097']['0']==12)
        t.advance(3); t.moogle_tick(); assert(not t.get('ephemeral').running)
    end)

    t.test('automatic deposit trades only surplus and excludes held and Storage stock', function()
        local p=t.preferences(); p.deposit_enabled=true; p.keep={['4096']=6}
        t.capacity(2,1)
        t.get('automatic').owner='Offline_42'; t.get('automatic').holds['4097']=true
        t.put(0,1,4096,12); t.put(0,2,4097,12); t.put(2,1,4104,12)
        t.select_target(0); assert(not t.get('ui').visible)
        t.moogle_tick(); local eph=t.get('ephemeral')
        assert(eph.running)
        for _,entry in ipairs(eph.queue) do assert(entry.item_id==4096 and entry.quantity==6) end
        t.ephemeral_tick()
        assert(#t.trades()==1 and t.trades()[1].entries[1].quantity==6)
        assert(not t.get('ui').visible)
    end)

    t.test('item outcome keeps the carried target and donates only from its chosen bag', function()
        local p=t.preferences()
        p.item_rules={version=1,items={['4096']={
            carry_target=24,destination=6,deposit=true,
        }}}
        t.put(0,1,4096,6)
        t.put(6,1,4096,12)
        t.put(5,1,4096,12)
        local queue,summary=t.get('build_ephemeral_dump_queue')({
            scope='all',character_slug='Offline_42',automatic=true,
        })
        assert(queue and #queue==0 and summary.kept_quantity==18,
            'donation plan consumed stock reserved for the carried target')

        t.put(0,1,4096,12); t.put(0,2,4096,12)
        queue=assert(t.get('build_ephemeral_dump_queue')({
            scope='all',character_slug='Offline_42',automatic=true,
        }))
        assert(#queue==2 and queue[1].kind=='stage'
            and queue[1].stage_move.source_container_id==6
            and queue[1].quantity==12,
            'donation plan did not use only the explicitly selected staging bag')
    end)

    t.test('leaving send radius stops automatic deposit before send', function()
        t.preferences().deposit_enabled=true; t.put(0,1,4096,12); t.moogle_tick()
        t.npc({distance=49}); t.advance(1); t.moogle_tick(); t.ephemeral_tick()
        assert(#t.trades()==0 and not t.get('ephemeral').running)
    end)

    t.test('target identity change stops automatic deposit before send', function()
        t.preferences().deposit_enabled=true; t.put(0,1,4096,12); t.moogle_tick()
        t.npc({id=1008}); t.advance(1); t.moogle_tick(); t.ephemeral_tick()
        assert(#t.trades()==0 and not t.get('ephemeral').running)
    end)

    t.test('range loss after confirmed staging prevents the next automatic trade', function()
        t.preferences().deposit_enabled=true; t.put(5,1,4096,12); t.moogle_tick(); t.ephemeral_tick()
        assert(#t.moves()==1 and #t.trades()==0)
        t.put(5,1,nil); t.put(0,1,4096,12); t.npc({distance=49})
        t.advance(1); t.moogle_tick(); t.ephemeral_tick()
        assert(#t.moves()==1 and #t.trades()==0 and not t.get('ephemeral').running,
            ('moves=%u trades=%u running=%s cursor=%s'):format(#t.moves(),#t.trades(),
                tostring(t.get('ephemeral').running),tostring(t.get('ephemeral').cursor)))
    end)
end
