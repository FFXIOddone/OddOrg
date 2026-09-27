return function(t)
    local function start(scope, automatic)
        local target = automatic and {index=7,server_id=1007,name='Ephemeral Moogle',zone=100,distance=4} or nil
        t.get('handle_ephemeral')({'/oddorg','ephemeral','dump',scope or 'storage'},target)
        local state=t.get('ephemeral')
        assert(state.running,state.error or 'deposit queue did not start')
        return state
    end

    local function apply_stage(move,destination)
        local source=assert(t.slot(move.source_container_id,move.source_index),'missing staged source')
        local remaining=source.Count-move.quantity
        t.put(move.source_container_id,move.source_index,remaining>0 and source.Id or nil,remaining>0 and remaining or nil,source.Flags)
        local current=t.slot(0,destination)
        if current then
            assert(current.Id==move.item_id,'test attempted an invalid merge')
            t.put(0,destination,current.Id,current.Count+move.quantity,current.Flags)
        else
            t.put(0,destination,move.item_id,move.quantity)
        end
    end

    local function remove_trade(trade)
        for _,entry in ipairs(trade.entries) do
            local current=assert(t.slot(0,entry.source_index),'missing traded source')
            local remaining=current.Count-entry.quantity
            t.put(0,entry.source_index,remaining>0 and current.Id or nil,remaining>0 and remaining or nil,current.Flags)
        end
    end

    local function stage_until_trade(destination_for_move,max_steps)
        local seen=#t.moves()-(t.get('ephemeral').awaiting_inventory and 1 or 0)
        local starting_trades=#t.trades()
        for _=1,max_steps or 30 do
            t.get('run_ephemeral_tick')()
            while seen < #t.moves() do
                seen=seen+1
                local move=t.moves()[seen]
                apply_stage(move,destination_for_move(move,seen))
                t.advance(1)
                t.get('run_ephemeral_tick')()
            end
            if #t.trades()>starting_trades then return seen end
            t.advance(1)
        end
        error('trade was not reached')
    end

    local function confirm_trade(index)
        remove_trade(t.trades()[index])
        t.get('run_ephemeral_tick')()
        t.advance(10)
        t.get('run_ephemeral_tick')()
    end

    t.test('three stored stacks gather before one trade including partial same item',function()
        t.capacity(0,8)
        t.put(5,1,4106,2); t.put(5,2,4106,12); t.put(5,3,4098,4)
        start('storage')
        stage_until_trade(function(_,index) return index end)
        assert(#t.moves()==3 and #t.trades()==1 and #t.trades()[1].entries==3)
        local units=0
        for _,entry in ipairs(t.trades()[1].entries) do units=units+entry.units end
        assert(units==172)
    end)

    t.test('eligible Inventory fills an eight slot batch with stored staging',function()
        t.capacity(0,8)
        for index=1,6 do t.put(0,index,index%2==0 and 4096 or 4097,12) end
        t.put(5,1,4104,12); t.put(5,2,4098,12)
        start('all')
        stage_until_trade(function(_,index) return 6+index end)
        assert(#t.moves()==2 and #t.trades()==1 and #t.trades()[1].entries==8)
    end)

    t.test('ten stored stacks deposit as batches of eight and two',function()
        t.capacity(0,10)
        for index=1,8 do t.put(5,index,index%2==0 and 4096 or 4097,12) end
        t.put(6,1,4098,12); t.put(6,2,4104,12)
        local state=start('storage')
        stage_until_trade(function(_,index) return index end,40)
        assert(#t.moves()==8 and #t.trades()[1].entries==8)
        confirm_trade(1)
        stage_until_trade(function(_,index) return index-8 end,20)
        assert(#t.moves()==10 and #t.trades()==2 and #t.trades()[2].entries==2)
        confirm_trade(2)
        assert(not state.running)
    end)

    t.test('one free Inventory slot preserves stage then trade fallback',function()
        t.capacity(0,2); t.put(0,1,900,1,1)
        t.put(5,1,4096,12); t.put(5,2,4097,12)
        start('storage')
        stage_until_trade(function() return 2 end)
        assert(#t.moves()==1 and #t.trades()==1 and #t.trades()[1].entries==1)
        confirm_trade(1)
        stage_until_trade(function() return 2 end)
        assert(#t.moves()==2 and #t.trades()==2 and #t.trades()[2].entries==1)
    end)

    t.test('merged staged splits share one trade slot without consuming Keep',function()
        t.reset({['4104']=6}); t.capacity(0,3)
        t.put(0,1,4104,6); t.put(5,1,4104,2); t.put(5,2,4104,4)
        start('all')
        stage_until_trade(function() return 1 end)
        assert(#t.moves()==2 and #t.trades()==1 and #t.trades()[1].entries==1)
        assert(t.trades()[1].entries[1].quantity==6)
        confirm_trade(1)
        assert(t.slot(0,1).Id==4104 and t.slot(0,1).Count==6)
    end)

    t.test('a staged quantity split at slot eight retains its remainder until confirmed',function()
        t.reset({['4096']=6}); t.capacity(0,9)
        for index=1,7 do t.put(0,index,4097,12) end
        t.put(0,8,4096,6); t.put(5,1,4096,12)
        local state=start('all')
        t.get('run_ephemeral_tick')()
        assert(#t.moves()==1 and #t.trades()==0)
        -- Server stacks six onto the kept stack and puts six in a new slot.
        t.put(5,1,nil); t.put(0,8,4096,12); t.put(0,9,4096,6)
        t.advance(1); t.get('run_ephemeral_tick')()
        assert(#t.trades()==1 and #t.trades()[1].entries==8)
        assert(t.trades()[1].entries[8].quantity==6)
        local pending=state.queue[state.awaiting_trade.next_cursor]
        assert(pending.quantity==12)
        confirm_trade(1)
        assert(pending.quantity==6 and #t.trades()==2)
        assert(#t.trades()[2].entries==1 and t.trades()[2].entries[1].source_index==9)
        confirm_trade(2)
        assert(not state.running and t.slot(0,8).Count==6 and not t.slot(0,9))
    end)

    t.test('full Inventory deposits carried stock before retrieving stored stock',function()
        t.capacity(0,2); t.put(0,1,900,1); t.put(0,2,4096,12)
        t.put(5,1,4097,12)
        start('all'); t.get('run_ephemeral_tick')()
        assert(#t.moves()==0 and #t.trades()==1)
        confirm_trade(1)
        stage_until_trade(function() return 2 end)
        assert(#t.moves()==1 and #t.trades()==2)
        confirm_trade(2)
        assert(t.slot(0,1).Id==900)
    end)

    t.test('unconfirmed full batch does not consume budgets or send another batch',function()
        t.capacity(0,10)
        for index=1,10 do t.put(0,index,4096,12) end
        local state=start('inventory'); t.get('run_ephemeral_tick')()
        assert(#t.trades()==1 and #t.trades()[1].entries==8)
        t.advance(16); t.get('run_ephemeral_tick')()
        assert(not state.running and state.cursor==1)
        assert(state.queue[1].quantity==12)
        t.get('run_ephemeral_tick')(); assert(#t.trades()==1)
    end)

    t.test('Keep across locked and unlocked stacks survives a gathered deposit',function()
        t.reset({['4096']=18}); t.capacity(0,3)
        t.put(0,1,4096,12,1); t.put(0,2,4096,12); t.put(5,1,4096,4)
        start('all'); stage_until_trade(function() return 3 end)
        assert(#t.trades()==1 and #t.trades()[1].entries==2)
        local quantity=0
        for _,entry in ipairs(t.trades()[1].entries) do
            assert(entry.source_index~=1); quantity=quantity+entry.quantity
        end
        assert(quantity==10)
        confirm_trade(1)
        assert(t.slot(0,1).Count==12 and t.slot(0,2).Count==6)
    end)

    t.test('unconfirmed staging never resends and walkaway stops gathered work',function()
        t.put(5,1,4096,12); start('storage')
        t.get('run_ephemeral_tick')(); assert(#t.moves()==1)
        t.advance(6); t.get('run_ephemeral_tick')()
        assert(not t.get('ephemeral').running and #t.moves()==1 and #t.trades()==0)

        t.reset(); t.put(5,1,4096,12); t.put(5,2,4097,12); start('storage',true)
        t.get('run_ephemeral_tick')(); local move=t.moves()[1]
        apply_stage(move,1); t.npc({distance=49}); t.advance(1); t.get('run_ephemeral_tick')()
        assert(not t.get('ephemeral').running and #t.moves()==1 and #t.trades()==0)
    end)
end
