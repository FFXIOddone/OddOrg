return function(t)
    local function finish_trade(index)
        for _,entry in ipairs(t.trades()[index].entries) do
            local slot=assert(t.slot(0,entry.source_index),'missing trade source')
            local left=slot.Count-entry.quantity
            t.put(0,entry.source_index,left>0 and slot.Id or nil,left>0 and left or nil,slot.Flags)
        end
        t.ephemeral_tick()
        t.advance(10)
        t.ephemeral_tick()
    end

    t.test('automatic empty pass and confirmed deposit stay quiet',function()
        local prefs=t.preferences(); prefs.deposit_enabled=true
        t.moogle_tick()
        assert(#t.trades()==0 and #t.messages()==0,'empty automatic pass produced routine chat')

        t.reset()
        t.preferences().deposit_enabled=true
        t.put(0,1,4096,12)
        t.moogle_tick()
        assert(t.get('ephemeral').running,'eligible Moogle pass did not start')
        assert(#t.messages()==0,'automatic start produced routine chat')
        t.ephemeral_tick()
        assert(#t.trades()==1 and #t.messages()==0,'automatic send produced routine chat')
        finish_trade(1)
        assert(not t.get('ephemeral').running and #t.messages()==0,
            'confirmed automatic completion produced routine chat')
    end)

    t.test('manual deposit start and confirmed completion remain announced',function()
        t.put(0,1,4096,12)
        t.get('handle_ephemeral')({'/oddorg','ephemeral','dump','inventory'})
        assert(t.get('ephemeral').running and #t.messages()>0,'manual start was not announced')
        t.ephemeral_tick()
        assert(#t.trades()==1)
        finish_trade(1)
        assert(not t.get('ephemeral').running and #t.messages()>1,
            'manual completion was not announced')
    end)

    t.test('automatic departure before send stays quiet and does not retry the claimed pass',function()
        t.preferences().deposit_enabled=true
        t.put(0,1,4096,12)
        t.moogle_tick()
        local pass=t.get('moogle').pass
        t.npc({distance=49}); t.advance(1); t.moogle_tick(); t.ephemeral_tick()
        assert(not t.get('ephemeral').running and #t.trades()==0)
        t.npc({distance=4}); t.moogle_tick(); t.ephemeral_tick()
        assert(t.get('moogle').pass==pass and #t.trades()==0,
            'returning during the same claimed pass retried the automatic deposit')
        assert(#t.messages()==0,'automatic departure produced routine chat')
    end)

    t.test('unconfirmed automatic trade reports failure and never resends',function()
        t.preferences().deposit_enabled=true
        t.put(0,1,4096,12)
        t.moogle_tick(); t.ephemeral_tick()
        assert(#t.trades()==1)
        local before=#t.messages()
        t.advance(16); t.ephemeral_tick()
        assert(not t.get('ephemeral').running and #t.messages()>before,
            'unconfirmed automatic trade failure was hidden')
        t.ephemeral_tick()
        assert(#t.trades()==1,'unconfirmed automatic trade was resent')
    end)
end
