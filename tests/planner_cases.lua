return function(t)
    t.test('partial default storage stacks consolidate while Ignore all stays untouched', function()
        t.preferences().sort_enabled=true
        t.put(5,1,4096,5); t.put(6,1,4096,5)
        local function plan()
            return assert(t.get('build_organize_plan')(assert(t.get('collect_live_items')()),
                {scope='storage',character_slug='Offline_42'}))
        end
        local result=plan()
        assert(#result.logical_moves==1 and result.logical_moves[1].quantity==5)
        local move=result.logical_moves[1]
        assert(move.source_container_id~=move.target_container_id and move.target_container_id~=0)
        t.preferences().keep['4096']='all'
        assert(#plan().logical_moves==0)
    end)

    local function options()
        return {scope='storage',character_slug='Offline_42'}
    end
    local function zero_nonwardrobe()
        for _, bag in ipairs({1,4,5,6,7}) do t.capacity(bag, 0) end
    end
    local function safe2_access(unlocked, character)
        t.preferences().safe2_access = {character=character or 'Offline_42',unlocked=unlocked}
    end
    local function char_sync(flag, target_index, server_id)
        local bytes={}
        for index=1,40 do bytes[index]=0 end
        -- 0x067 Mode 2: packed Mode/Length at 0x04, local target index at
        -- 0x06, local server id at 0x08, and MogExpansionFlag at 0x27.
        local packed=2 + 36 * 64
        bytes[5],bytes[6]=packed % 256,math.floor(packed / 256)
        local index=target_index or 1
        bytes[7],bytes[8]=index % 256,math.floor(index / 256)
        local id=server_id or 42
        for offset=0,3 do bytes[9+offset]=math.floor(id / (256 ^ offset)) % 256 end
        bytes[40]=flag
        return string.char(unpack(bytes))
    end

    t.test('resident overflow stacks are already a fixed point', function()
        zero_nonwardrobe(); t.capacity(0,2); t.capacity(6,1)
        t.put(0,1,903,5); t.put(6,1,903,12)
        local plan = assert(t.get('build_organize_plan')(assert(t.get('collect_live_items')()), options()))
        local actual={}
        for _, move in ipairs(plan.logical_moves) do
            actual[#actual+1]=('%u:%u x%u -> %u'):format(move.source_container_id,move.source_index,move.quantity,move.target_container_id)
        end
        assert(#plan.logical_moves == 0, ('expected fixed point, got %u moves [%s]'):format(#plan.logical_moves,table.concat(actual,', ')))
    end)

    t.test('background eligible stored item stays out of Inventory', function()
        zero_nonwardrobe(); t.capacity(0,2); t.capacity(5,1)
        t.put(5,1,902,12)
        local p=t.preferences(); p.background={enabled=true,free_slots=1,items={['902']=true}}
        local plan=assert(t.get('build_organize_plan')(assert(t.get('collect_live_items')()),options()))
        assert(#plan.logical_moves == 0)
    end)

    t.test('house overflow uses Safe2 before leaving surplus in Inventory', function()
        safe2_access(true)
        zero_nonwardrobe(); t.capacity(0,2); t.capacity(6,1); t.capacity(9,1)
        t.put(0,1,903,5); t.put(6,1,903,12)
        local first=assert(t.get('build_organize_plan')(assert(t.get('collect_live_items')()),options()))
        assert(#first.logical_moves == 1)
        local move=first.logical_moves[1]
        assert(move.item_id == 903 and move.quantity == 5 and move.target_container_id == 9)
        t.put(move.source_container_id,move.source_index,nil); t.put(9,1,903,5)
        local second=assert(t.get('build_organize_plan')(assert(t.get('collect_live_items')()),options()))
        assert(#second.logical_moves == 0)
    end)

    t.test('unknown or locked Safe2 is skipped despite positive capacity', function()
        zero_nonwardrobe(); t.capacity(0,2); t.capacity(2,1); t.capacity(9,1)
        t.put(0,1,903,5)
        local unknown=assert(t.get('build_organize_plan')(assert(t.get('collect_live_items')()),options()))
        assert(#unknown.logical_moves == 1 and unknown.logical_moves[1].target_container_id == 2)
        safe2_access(false)
        local locked=assert(t.get('build_organize_plan')(assert(t.get('collect_live_items')()),options()))
        assert(#locked.logical_moves == 1 and locked.logical_moves[1].target_container_id == 2)
        safe2_access(true,'SomeoneElse_42')
        local wrong_character=assert(t.get('build_organize_plan')(assert(t.get('collect_live_items')()),options()))
        assert(#wrong_character.logical_moves == 1 and wrong_character.logical_moves[1].target_container_id == 2)
    end)

    t.test('native local char sync caches Safe2 unlock and relock', function()
        local function packet(data, overrides)
            local event={id=0x067,injected=false,blocked=false,data=data}
            for key,value in pairs(overrides or {}) do event[key]=value end
            t.packet_in(event)
        end
        packet(char_sync(1))
        assert(t.preferences().safe2_access.character == 'Offline_42')
        assert(t.preferences().safe2_access.unlocked == true)
        assert(t.saved().safe2_access.unlocked == true)
        packet(char_sync(0))
        assert(t.preferences().safe2_access.unlocked == false)
        assert(t.saved().safe2_access.unlocked == false)
    end)

    t.test('invalid char sync cannot change cached Safe2 access', function()
        safe2_access(false)
        local function ignored(data, overrides)
            local event={id=0x067,injected=false,blocked=false,data=data}
            for key,value in pairs(overrides or {}) do event[key]=value end
            t.packet_in(event)
            assert(t.preferences().safe2_access.unlocked == false)
        end
        ignored(char_sync(1):sub(1,39))
        ignored(char_sync(1),{injected=true})
        ignored(char_sync(1),{blocked=true})
        ignored(char_sync(1,2,42))
        ignored(char_sync(1,1,43))
        ignored(char_sync(2))
    end)

    t.test('house overflow uses Storage when Safe2 is unavailable and respects keeps', function()
        t.reset({['900']='all'})
        zero_nonwardrobe(); t.capacity(0,2); t.capacity(2,1); t.capacity(9,0)
        t.put(0,1,903,5); t.put(0,2,900,1)
        local plan=assert(t.get('build_organize_plan')(assert(t.get('collect_live_items')()),options()))
        assert(#plan.logical_moves == 1 and plan.logical_moves[1].target_container_id == 2)
        assert(plan.logical_moves[1].item_id == 903 and plan.kept_quantity == 1)
    end)

    t.test('disabled background preserves manual Inventory assignment', function()
        zero_nonwardrobe(); t.capacity(0,2); t.capacity(5,1)
        t.put(5,1,902,12)
        local plan=assert(t.get('build_organize_plan')(assert(t.get('collect_live_items')()),options()))
        assert(#plan.logical_moves == 1 and plan.logical_moves[1].target_container_id == 0)
    end)

    t.test('applied storage plan with slot renumbering reaches a fixed point', function()
        zero_nonwardrobe(); t.capacity(0,2); t.capacity(5,2)
        t.put(0,2,901,12); t.put(5,2,902,12)
        local first=assert(t.get('build_organize_plan')(assert(t.get('collect_live_items')()),options()))
        assert(#first.logical_moves == 2)
        for _, move in ipairs(first.logical_moves) do
            assert(move.quantity == 12)
            assert((move.item_id == 901 and move.source_container_id == 0 and move.target_container_id == 5)
                or (move.item_id == 902 and move.source_container_id == 5 and move.target_container_id == 0))
            t.put(move.source_container_id,move.source_index,nil)
        end
        -- Apply the actual planned transfers into different destination slots.
        for _, move in ipairs(first.logical_moves) do
            t.put(move.target_container_id,1,move.item_id,move.quantity)
        end
        local second=assert(t.get('build_organize_plan')(assert(t.get('collect_live_items')()),options()))
        assert(#second.logical_moves == 0)
    end)

    t.test('wardrobe overflow preserves resident assignments', function()
        for _, bag in ipairs({8,10,11,12,13,14,15,16}) do t.capacity(bag,0) end
        t.capacity(8,1); t.capacity(10,1)
        -- Neither bag is the rings' primary home. Name ordering would swap them.
        t.put(8,1,103,1); t.put(10,1,102,1)
        local plan=assert(t.get('build_organize_plan')(assert(t.get('collect_live_items')()),
            {scope='wardrobes',character_slug='Offline_42'}))
        assert(#plan.logical_moves == 0)
    end)
end
