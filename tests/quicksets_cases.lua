return function(t)
    t.test('settings refresh uses current layout and protections without addon reload',function()
        local auto, ui, organizer = t.get('automatic'), t.get('ui'), t.get('organizer')
        t.put(0,1,4096,12)
        assert(auto.save_layout({version=1,active='',sets={},overrides={crystals=6}}))
        assert(organizer.error == nil, 'idle save created a cancellation error')
        local organize=t.get('handle_organize')
        organize({'/oddorg','organize','preview','all'})
        assert(ui.preview_plan and #ui.preview_plan.logical_moves > 0)
        organize({'/oddorg','organize','run','all'})
        assert(organizer.running)
        assert(auto.save_layout({version=1,active='',sets={},overrides={crystals=7}}))
        assert(not organizer.running and #organizer.queue == 0)
        assert(ui.preview_plan == nil and ui.bulk_preview_ready == nil)
        assert(organizer.error, 'interrupted run needs a notice')
        organize({'/oddorg','organize','preview','all'})
        assert(organizer.error == nil, 'successful preview retained stale notice')
        organize({'/oddorg','organize','run','all'})
        assert(organizer.running and #organizer.queue > 0)
        for _, move in ipairs(organizer.queue) do
            assert(move.target_container_id == 7, 'run used the previous destination')
        end
        assert(t.get('set_keep_rule')(4096, 'all'))
        assert(t.saved().keep['4096'] == 'all')
        assert(not organizer.running and ui.preview_plan == nil)
        organize({'/oddorg','organize','preview','all'})
        assert(ui.preview_plan and #ui.preview_plan.logical_moves == 0,
            'new protection was not used by the next plan')
        assert(organizer.error == nil)
        organize({'/oddorg','organize','run','all'})
        assert(#organizer.queue == 0, 'run ignored the newly saved protection')
        assert(#t.moves() == 0)
    end)

    local function quickset(active, routes, extra)
        local sets = extra or {}
        sets[active] = routes
        return { version=1, active=active, sets=sets }
    end

    local function activate(routes, active, extra)
        local value = quickset(active or 'Automatic Care', routes, extra)
        t.preferences().storage_layout = value
        return value
    end

    local function snapshot()
        return assert(t.get('collect_live_items')())
    end

    local function plan(scope)
        return t.get('build_organize_plan')(snapshot(), {
            scope=scope or 'all', character_slug='Offline_42'
        })
    end

    local function ready_tick()
        local automatic = t.get('automatic')
        automatic.tick()
        t.advance(2)
        automatic.tick()
        return automatic
    end

    t.test('automatic care uses the active quickset destination without fallback',function()
        activate({crystals=6,['gear.main']=10})
        local prefs=t.preferences()
        prefs.sort_enabled=true
        t.capacity(6,1); t.put(6,1,4097,12)
        t.put(0,1,4096,12)
        local automatic=ready_tick()
        assert(#t.moves()==0,'full routed Sack fell back to another bag')
        assert(automatic.status:find('chosen quickset bag is full or unavailable',1,true),automatic.status)
    end)

    t.test('clearing-only quickset stops once the free-slot goal is met',function()
        activate({crystals=6,['gear.main']=10})
        local prefs=t.preferences()
        prefs.background.enabled=true; prefs.background.free_slots=1
        prefs.sort_enabled=false
        t.capacity(0,4); t.put(0,1,4096,12)
        local automatic=ready_tick()
        assert(#t.moves()==0,'clearing moved an assigned item after reaching its free-slot goal')
        assert(automatic.status:find('Ready.',1,true),automatic.status)
    end)

    t.test('explicit false and Ignore protections beat a quickset assignment',function()
        activate({crystals=6,['gear.main']=10})
        local prefs=t.preferences()
        prefs.sort_enabled=true; prefs.background.items['4096']=false
        t.put(0,1,4096,12)
        ready_tick()
        assert(#t.moves()==0,'explicit false item permission was moved')

        t.reset({['4096']='all'})
        activate({crystals=6,['gear.main']=10})
        prefs=t.preferences(); prefs.sort_enabled=true
        t.put(0,1,4096,12)
        ready_tick()
        assert(#t.moves()==0,'Ignore keep-all crystal was moved')
    end)

    t.test('bulk organization shares quickset routes and becomes idempotent',function()
        activate({crystals=6,['gear.main']=10})
        local prefs=t.preferences()
        prefs.background.enabled=true
        t.put(5,1,4096,12)
        local first=assert(plan('storage'))
        assert(#first.logical_moves==1 and first.logical_moves[1].target_container_id==6,
            'bulk plan did not use the active crystal route')
        t.put(5,1,nil); t.put(6,1,4096,12)
        local second=assert(plan('storage'))
        assert(#second.logical_moves==0,'a completed quickset plan was not idempotent')
    end)

    t.test('unassigned equipment remains in place',function()
        activate({crystals=6,['gear.main']=10})
        t.put(0,1,102,1) -- ring is intentionally unassigned
        local value=assert(plan('all'))
        assert(#value.logical_moves==0,'unassigned ring was moved by the quickset')
    end)

    t.test('bulk quickset rejects a locked or full destination without fallback',function()
        activate({crystals=6})
        t.put(0,1,4096,12); t.capacity(6,0)
        local blocked,err=plan('storage')
        assert(blocked==nil and err:find('destination is unavailable: Sack',1,true),err)
        t.capacity(6,1); t.put(6,1,4097,12)
        blocked,err=plan('storage')
        assert(blocked==nil and err:find('Sack would overfill',1,true),err)
        assert(#t.moves()==0)
    end)

    t.test('unassigned crystals stay out of automatic Moogle deposits',function()
        activate({['gear.main']=10})
        t.put(0,1,4096,12)
        local queue=assert(t.get('build_ephemeral_dump_queue')({scope='all',automatic=true,character_slug='Offline_42'}))
        assert(#queue==0,'unassigned crystals were nominated for an automatic deposit')
        t.preferences().storage_layout.sets['Automatic Care'].crystals=6
        queue=assert(t.get('build_ephemeral_dump_queue')({scope='all',automatic=true,character_slug='Offline_42'}))
        assert(#queue>0,'assigned surplus crystals lost their existing deposit permission')
    end)

    t.test('layout validation rejects a non-equipment route to a wardrobe',function()
        local storage_layout=require('storage_layout')
        local valid,err=storage_layout.validate(quickset('Bad',{crystals=10}))
        assert(not valid and err:find('Only equipment',1,true),err)
    end)

    t.test('saving a quickset round-trips and switching active sets cancels queued work',function()
        local sets={
            ['First Bulk Run']={crystals=5,['gear.main']=10},
        }
        local desired=quickset('Automatic Care',{crystals=6,['gear.main']=10},sets)
        local organizer=t.get('organizer')
        organizer.running=true; organizer.queue={{move_id='old-layout'}}
        assert(t.get('automatic').save_layout(desired))
        assert(not organizer.running and #organizer.queue==0,'layout switch retained queued work')
        assert(t.saved().storage_layout.active=='Automatic Care')
        assert(t.saved().storage_layout.sets['Automatic Care'].crystals==6)

        local switched=quickset('First Bulk Run',{crystals=5,['gear.main']=10},{
            ['Automatic Care']={crystals=6,['gear.main']=10},
        })
        organizer.running=true; organizer.queue={{move_id='second-old-layout'}}
        assert(t.get('automatic').save_layout(switched))
        assert(not organizer.running and t.saved().storage_layout.active=='First Bulk Run')
    end)

    t.test('failed quickset persistence restores the prior layout and pauses automation',function()
        local prior=activate({crystals=5,['gear.main']=10},'Prior')
        t.saved().storage_layout=require('storage_layout').clone(prior)
        local methods=t.settings()
        local original_save=methods.save
        methods.save=function() return false end
        local desired=quickset('Next',{crystals=6,['gear.main']=10})
        local result=t.get('automatic').save_layout(desired)
        methods.save=original_save
        assert(not result,'failed settings save was reported as successful')
        assert(t.preferences().storage_layout.active=='Prior','failed save leaked the new layout')
        assert(t.get('automatic').paused,'failed save did not pause automatic work')
    end)

    t.test('character settings updates do not leak another character quickset',function()
        local first=activate({crystals=6,['gear.main']=10},'Automatic Care')
        t.saved().storage_layout=require('storage_layout').clone(first)
        t.character('Alt',43)
        t.settings_update({keep={},sort_enabled=false,deposit_enabled=false,
            background={enabled=false,free_slots=5,items={}},
            storage_layout={version=1,active='',sets={}}})
        assert(t.preferences().storage_layout.active=='')
        assert(t.preferences().storage_layout.sets['Automatic Care']==nil,
            'new character inherited the previous character quickset')
    end)
end
