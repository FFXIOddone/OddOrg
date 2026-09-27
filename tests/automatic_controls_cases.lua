return function(t)
    local function setup(enabled, slots, sorting, depositing)
        return { enabled=enabled, free_slots=slots, sort_enabled=sorting, deposit_enabled=depositing }
    end

    t.test('automatic slot target accepts 80 and rejects 81 without changing saved settings',function()
        local auto=t.get('automatic')
        assert(auto.apply_setup(setup(true,80,false,false)))
        assert(t.saved().background.free_slots==80)
        assert(require('housekeeping').validate(t.preferences().background))
        assert(not auto.apply_setup(setup(true,81,false,false)))
        assert(t.saved().background.free_slots==80)
    end)

    t.test('automatic settings apply together and preserve item protections',function()
        t.reset({['4096']=5})
        local prefs=t.preferences()
        prefs.background.items['4096']=true
        prefs.sort_enabled=false; prefs.deposit_enabled=false
        local automatic=t.get('automatic')
        automatic.paused=true
        assert(automatic.apply_setup(setup(true,8,true,true)))
        local saved=t.saved()
        assert(saved.background.enabled and saved.background.free_slots==8)
        assert(saved.sort_enabled and saved.deposit_enabled)
        assert(saved.keep['4096']==5 and saved.background.items['4096']==true)
        assert(automatic.paused,'saving settings must not resume paused automation')
    end)

    t.test('invalid automatic setup is rejected without changing saved settings',function()
        local before=t.saved()
        assert(not t.get('automatic').apply_setup(setup(true,0,true,true)))
        local after=t.saved()
        assert(after.background.enabled==before.background.enabled
            and after.background.free_slots==before.background.free_slots
            and after.sort_enabled==before.sort_enabled
            and after.deposit_enabled==before.deposit_enabled)
    end)

    t.test('no-op Apply preserves a claimed Moogle pass and active queue',function()
        t.reset()
        local moogle=t.get('moogle')
        local pass={claimed=true,scene={}}
        moogle.pass=pass
        local ephemeral=t.get('ephemeral')
        local queue={{kind='trade',item_id=4096}}
        ephemeral.running=true; ephemeral.queue=queue
        assert(t.get('automatic').apply_setup(setup(false,5,false,false)))
        assert(moogle.pass==pass and moogle.pass.claimed,'no-op Apply discarded a claimed Moogle pass')
        assert(ephemeral.running and ephemeral.queue==queue,'no-op Apply cancelled queued work')
    end)

    t.test('save and reload exceptions cannot enable previously disabled automatic work',function()
        local methods=t.settings()
        local original_save, original_reload=methods.save, methods.reload
        local function attempt(fail_at)
            t.reset()
            methods.save=function()
                if fail_at=='save' then error('simulated save exception') end
                return true
            end
            methods.reload=function()
                if fail_at=='reload' then error('simulated reload exception') end
                return original_reload()
            end
            local result=t.get('automatic').apply_setup(setup(true,9,true,true))
            methods.save, methods.reload=original_save, original_reload
            assert(not result,fail_at .. ' exception was reported as success')
            assert(t.saved().background.enabled==false and t.preferences().background.enabled==false,
                fail_at .. ' exception activated automatic work')
            assert(t.preferences().sort_enabled==false and t.preferences().deposit_enabled==false,
                fail_at .. ' exception activated automatic features')
        end
        attempt('save')
        attempt('reload')
    end)

    t.test('automatic settings draft waits for Apply and resets for another character',function()
        t.reset({['4096']=5})
        t.preferences().background.items['4096']=false
        t.saved().background.items['4096']=false
        local clicks, edits = {}, {}
        local drawn, noop = {}, function() end
        local imgui={
            Begin=function() return true end, End=noop,
            BeginChild=function() return true end, EndChild=noop,
            GetContentRegionAvail=function() return 520,480 end,
            PushItemWidth=noop, PopItemWidth=noop,
            InputText=noop,
            TextWrapped=function(value) drawn[#drawn+1]=tostring(value) end,
            TextUnformatted=function(value) drawn[#drawn+1]=tostring(value) end,
            Button=function(label)
                local hit=clicks[label]
                if hit==nil then
                    for id,value in pairs(clicks) do
                        if type(id)=='string' and id:sub(1,2)=='##' and label:sub(-#id)==id then hit=value; clicks[id]=nil; break end
                    end
                else clicks[label]=nil end
                return hit or false
            end,
            Checkbox=function(label,value)
                if edits[label]~=nil then value[1]=edits[label]; edits[label]=nil; return true end
                return false
            end,
            InputInt=function(label,value)
                if edits[label]~=nil then value[1]=edits[label]; edits[label]=nil; return true end
                return false
            end,
            SliderInt=function(label,value,minimum,maximum)
                for id,entry in pairs(edits) do
                    if type(id)=='string' and id:sub(1,2)=='##' and label:sub(-#id)==id then
                        value[1]=entry; edits[id]=nil; return true
                    end
                end
                return false
            end,
        }
        t.replace('imgui',imgui)
        local ui=t.get('ui')
        ui.visible=true; ui.page='settings'; ui.settings_tab='automatic'
        ui.protections_visible=false; ui.preview_visible=false
        t.get('render_ui')()
        assert(ui.automation_draft and ui.automation_draft.character=='Offline_42')
        clicks['##care_space_toggle']=true
        t.get('render_ui')() -- Enabling care reveals the slider on the next frame.
        edits['##care_slots']=8
        clicks['##care_sort_toggle']=true
        clicks['##care_deposit_toggle']=true
        t.get('render_ui')()
        assert(ui.automation_draft.enabled[1] and ui.automation_draft.free_slots[1]==8
            and ui.automation_draft.sort_enabled[1] and ui.automation_draft.deposit_enabled[1])
        assert(t.saved().background.free_slots==5 and not t.saved().sort_enabled and not t.saved().deposit_enabled,
            'editing the controls persisted before Apply')
        assert(t.get('set_keep_rule')(4096,4),'same-character item rule did not save')
        assert(ui.automation_draft and ui.automation_draft.enabled[1]
            and ui.automation_draft.free_slots[1]==8 and ui.automation_draft.sort_enabled[1]
            and ui.automation_draft.deposit_enabled[1], 'item save discarded the automatic-care draft')
        assert(t.saved().background.free_slots==5 and not t.saved().sort_enabled
            and not t.saved().deposit_enabled and t.saved().keep['4096']==4,
            'item save persisted unsaved automatic-care choices')
        clicks['Apply automatic settings##care_apply']=true
        t.get('render_ui')()
        assert(t.saved().background.free_slots==8 and t.saved().sort_enabled and t.saved().deposit_enabled)
        assert(t.saved().keep['4096']==4,'Apply changed the saved item protection')
        assert(t.saved().background.items['4096']==false,
            'Apply changed an explicit false item override')

        assert(ui.automation_draft==nil,'successful Apply retained its completed draft')
        t.get('render_ui')()
        assert(ui.automation_draft,'render did not create a fresh settings draft')
        t.settings_update({keep={['4096']=4},sort_enabled=false,deposit_enabled=false,
            background={enabled=false,free_slots=6,items={['4096']=false}}})
        assert(ui.automation_draft==nil,'genuine saved automatic-settings change retained a stale draft')
        t.get('render_ui')()
        assert(ui.automation_draft,'render did not initialize the new saved baseline')
        t.get('automatic').paused=true
        t.character('Alt',43)
        t.settings_update({keep={},sort_enabled=false,deposit_enabled=false,
            background={enabled=false,free_slots=5,items={}}})
        assert(ui.automation_draft==nil,'character change retained another character\'s draft')
        assert(ui.page=='home','character change did not return to the home page')
        assert(not t.get('automatic').paused,'new character inherited the previous character\'s pause')
        t.replace('imgui',nil)
    end)
end
