return function(t)
    local function enable_sort(items)
        local p=t.preferences(); p.sort_enabled=true; p.background.items=items or {}
    end
    local function tick() t.get('automatic').tick(); t.advance(2); t.get('automatic').tick() end

    t.test('continuous sort ignores free slot goal and moves eligible Inventory crystal', function()
        enable_sort(); t.put(0,1,4096,12); tick()
        assert(#t.moves()==1 and t.moves()[1].item_id==4096 and t.moves()[1].target_container_id~=2)
    end)

    t.test('continuous sort moves explicit opt in and retains excluded crystal', function()
        enable_sort({['901']=true,['4096']=false}); t.put(0,1,901,12); t.put(0,2,4096,12); tick()
        assert(#t.moves()==1 and t.moves()[1].item_id==901)
    end)

    t.test('continuous sort never moves an already stored item', function()
        enable_sort({['902']=true}); t.put(5,1,902,12); tick(); assert(#t.moves()==0)
    end)

    t.test('continuous sort respects lock and retrieval hold', function()
        enable_sort(); t.put(0,1,4096,12,1); t.put(0,2,4097,12)
        t.get('automatic').holds['4097']=true; t.get('automatic').owner='Offline_42'; tick()
        assert(#t.moves()==0)
    end)

    t.test('combined sorting and clearing warns below goal and again when full', function()
        enable_sort()
        local p=t.preferences(); p.background.enabled=true; p.background.free_slots=2
        p.keep={['4096']='all'}
        t.put(0,1,4096,12); t.put(0,2,900,1); t.put(0,3,902,12,1)
        tick()
        assert(#t.moves()==0 and not t.get('automatic').status:find('sorted',1,true))
        assert(t.get('automatic').status:find('Only 1 free',1,true))
        assert(t.get('automatic').status:find('Item rules',1,true))
        local notices=#t.messages(); assert(notices==1)
        t.advance(2); tick(); assert(#t.messages()==notices)
        t.put(0,4,900,1); t.advance(2); tick()
        assert(t.get('automatic').status:find('Inventory is full',1,true))
        assert(#t.messages()==notices+1 and #t.moves()==0)
        t.advance(2); tick(); assert(#t.messages()==notices+1)
        t.put(0,3,nil); t.put(0,4,nil); t.advance(2); tick()
        assert(t.get('automatic').status:find('sorted',1,true))
        assert(#t.messages()==notices+1)
        t.put(0,3,900,1); t.advance(2); tick()
        assert(#t.messages()==notices+2 and #t.moves()==0)
    end)

    t.test('sorting alone warns when full without enforcing disabled clearing goal', function()
        enable_sort(); t.preferences().background.free_slots=3
        for index=1,3 do t.put(0,index,900,1) end
        tick()
        assert(t.get('automatic').status:find('sorted',1,true) and #t.messages()==0)
        t.put(0,4,900,1); t.advance(2); tick()
        assert(t.get('automatic').status:find('Inventory is full',1,true))
        assert(#t.messages()==1 and #t.moves()==0)
    end)

    t.test('full destination notice escalates when Inventory becomes full', function()
        enable_sort(); t.preferences().background.enabled=true
        for _,bag in ipairs({1,4,5,6,7,8,10}) do t.capacity(bag,0) end
        t.put(0,1,4096,12); t.put(0,2,900,1); t.put(0,3,900,1)
        tick()
        assert(#t.moves()==0 and #t.messages()==1)
        assert(t.get('automatic').status:find('storage room',1,true))
        t.put(0,4,900,1); t.advance(2); tick()
        assert(#t.messages()==2 and t.get('automatic').status:find('Inventory is full',1,true))
        assert(t.get('automatic').status:find('Moogle',1,true))
    end)

    t.test('unloaded target bag prevents automatic sorting', function()
        enable_sort(); t.put(0,1,4096,12); t.update_flags(0x1FFFF-2^5); tick(); assert(#t.moves()==0)
        assert(t.get('automatic').status:find('Satchel loaded bit',1,true))
    end)

    t.test('unavailable loaded flags report a capability error instead of endless generic loading', function()
        enable_sort(); t.put(0,1,4096,12); t.update_flags(nil); tick()
        assert(#t.moves()==0 and t.get('automatic').status:find('flags unavailable',1,true))
    end)

    t.test('feature toggles persist independently', function()
        local auto=t.get('automatic')
        assert(auto.set_feature('sort_enabled',true) and t.saved().sort_enabled)
        assert(auto.set_feature('deposit_enabled',true) and t.saved().deposit_enabled)
        assert(auto.set_feature('sort_enabled',false) and not t.saved().sort_enabled)
    end)

    t.test('quiet counter cannot authorize a partially loaded manual plan', function()
        t.replace('read_account_storage_flags',function() return 0xFC end)
        for _,bag in ipairs({8,10,11,12,13,14,16}) do t.capacity(bag,0) end
        t.capacity(15,80)
        for slot=1,71 do t.put(15,slot,100,1) end
        t.update_flags(0x1FFFF-2^15)
        assert(t.get('collect_live_items')()==nil)
        t.get('handle_organize')({'/oddorg','organize','run','wardrobes'})
        t.get('run_organizer_tick')(); assert(#t.moves()==0)
        t.update_flags(0x1FFFF)
        for slot=72,80 do t.put(15,slot,100,1) end
        local snapshot=assert(t.get('collect_live_items')())
        local plan=t.get('build_organize_plan')(snapshot,{scope='wardrobes',character_slug='Offline_42'})
        if plan then
            for _,move in ipairs(plan.logical_moves) do assert(move.target_container_id~=15) end
        end
        t.get('handle_organize')({'/oddorg','organize','run','wardrobes'})
        t.get('run_organizer_tick')(); assert(#t.moves()==0)
    end)

    t.test('legacy house preference migrates to continuous sorting on callback', function()
        t.settings_update({keep={},house_enabled=true,sort_enabled=false,deposit_enabled=false,
            background={enabled=false,free_slots=5,items={}}})
        assert(t.preferences().sort_enabled==true and t.preferences().house_enabled==false)
        assert(t.saved().sort_enabled==true and t.saved().house_enabled==false)
    end)

    local function zone_event()
        t.packet_in({id=0x00A,injected=false,blocked=false,data=string.rep('\0',0xAC)})
    end

    t.test('idle zone event leaves queue errors clear and automatic sorting resumes', function()
        local p=t.preferences(); p.sort_enabled=true; t.put(0,1,4096,12); t.update_flags(0x3FFFF)
        t.get('organizer').error=nil; t.get('ephemeral').error=nil
        zone_event()
        assert(t.get('organizer').error==nil and t.get('ephemeral').error==nil)
        t.advance(6); t.get('automatic').tick(); t.advance(2); t.get('automatic').tick()
        assert(#t.moves()==1)
        assert(not tostring(t.get('automatic').status):find('waiting for fully loaded bags',1,true))
    end)

    t.test('active organizer zone cancellation is accurate and does not own readiness status', function()
        t.put(0,1,901,12)
        t.get('handle_organize')({'/oddorg','organize','run','storage'})
        assert(t.get('organizer').running)
        zone_event()
        assert(not t.get('organizer').running)
        assert(t.get('organizer').error=='Organization stopped when you changed zones.')
        t.advance(6); t.get('automatic').tick()
        assert(not tostring(t.get('automatic').status):find('waiting for fully loaded bags',1,true))
    end)

    t.test('idle zone event preserves real prior queue errors', function()
        local org,eph=t.get('organizer'),t.get('ephemeral')
        org.error='real organizer failure'; eph.error='real deposit failure'
        zone_event()
        assert(org.error=='real organizer failure' and eph.error=='real deposit failure')
    end)
end
