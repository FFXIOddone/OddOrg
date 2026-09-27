return function(t)
    local function install_ui()
        local actions={clicks={},select=nil,quantity=nil,carry_target=nil,allowed=nil,deposit=nil,combo=nil}
        local drawn={}
        local noop=function() end
        local imgui={
            Begin=function() return true end, End=noop, SetNextWindowSize=noop,
            BeginChild=function() return true end, EndChild=noop,
            BeginCombo=function(label) return actions.combo==label end, EndCombo=noop,
            GetContentRegionAvail=function() return 520,480 end,
            InputText=function() return false end,
            TextWrapped=function(value) drawn[#drawn+1]=tostring(value) end,
            TextUnformatted=function(value) drawn[#drawn+1]=tostring(value) end,
            Selectable=function(label)
                if actions.select and tostring(label):find(actions.select,1,true) then
                    actions.select=nil; return true
                end
                return false
            end,
            Button=function(label)
                local clicked=actions.clicks[label] == true
                actions.clicks[label]=nil
                return clicked
            end,
            InputInt=function(label,value)
                if label=='Items to ignore##ignore_quantity' and actions.quantity~=nil then
                    value[1]=actions.quantity; actions.quantity=nil; return true
                end
                if label=='##item_carry_target' and actions.carry_target~=nil then
                    value[1]=actions.carry_target; actions.carry_target=nil; return true
                end
                return false
            end,
            SliderInt=function(label,value)
                if label=='##ignore_slider' and actions.quantity~=nil then
                    value[1]=actions.quantity; actions.quantity=nil; return true
                end
                return false
            end,
            Checkbox=function(label,value)
                if tostring(label):find('##ignore_auto',1,true) and actions.allowed~=nil then
                    value[1]=actions.allowed; actions.allowed=nil; return true
                end
                if tostring(label):find('##item_deposit',1,true) and actions.deposit~=nil then
                    value[1]=actions.deposit; actions.deposit=nil; return true
                end
                return false
            end,
        }
        t.replace('imgui',imgui)
        return actions,drawn
    end

    local function open_and_select(actions,name)
        local ui=t.get('ui')
        ui.protections_visible=true
        actions.select=name
        t.get('render_protections')()
        assert(ui.selected_item_id and ui.item_draft,'item selection did not initialize a draft')
        return ui
    end

    t.test('item edits remain drafts until one atomic Apply',function()
        t.reset({['4096']=5})
        t.put(0,1,4096,12); t.put(5,1,4096,12)
        t.get('automatic').configure('item','4096',true)
        local actions=install_ui()
        local ui=open_and_select(actions,'Fire Crystal')
        assert(ui.item_draft.item_id==4096 and ui.item_draft.character=='Offline_42')
        assert(ui.item_draft.mode=='number' and ui.item_draft.quantity[1]==5 and ui.item_draft.allowed[1]==true)

        actions.clicks['Ignore amount##ignore_number']=true
        actions.quantity=7
        actions.allowed=false
        t.get('render_protections')()
        assert(ui.item_draft.mode=='number' and ui.item_draft.quantity[1]==7
            and ui.item_draft.allowed[1]==false)
        assert(t.saved().keep['4096']==5 and t.saved().background.items['4096']==true,
            'editing the preview persisted before Apply')

        local organizer=t.get('organizer')
        organizer.running=true; organizer.queue={{}}; organizer.cursor=1
        actions.clicks['Apply item settings##ignore_apply']=true
        t.get('render_protections')()
        local saved=t.saved()
        assert(saved.keep['4096']==7 and saved.background.items['4096']==false)
        assert(saved.background.enabled==false and saved.sort_enabled==false and saved.deposit_enabled==false)
        assert(not organizer.running,'Apply did not cancel the active queue')
    end)

    t.test('Ignore all and Ignore none persist their exact modes',function()
        t.put(0,1,4096,12)
        local actions=install_ui()
        open_and_select(actions,'Fire Crystal')
        actions.clicks['Ignore all##ignore_all']=true
        t.get('render_protections')()
        assert(t.saved().keep['4096']==nil)
        actions.clicks['Apply item settings##ignore_apply']=true
        t.get('render_protections')()
        assert(t.saved().keep['4096']=='all')

        actions.clicks['Ignore none##ignore_none']=true
        t.get('render_protections')() -- The footer appears after the edit is observed.
        actions.clicks['Apply item settings##ignore_apply']=true
        t.get('render_protections')()
        assert(t.saved().keep['4096']==nil)
    end)

    t.test('preview distinguishes quantities from slots and explains partial stack impact',function()
        t.reset({['4096']=5})
        t.put(0,1,4096,12); t.put(5,1,4096,12); t.put(5,2,4096,6)
        t.preferences().background.enabled=true
        t.preferences().deposit_enabled=true
        local actions,drawn=install_ui()
        open_and_select(actions,'Fire Crystal')
        drawn={}
        -- Reinstall captures a fresh output table without altering the draft.
        actions,drawn=install_ui()
        t.get('ui').protections_visible=true
        t.get('render_protections')()
        local text=table.concat(drawn,' ')
        assert(text:find('Inventory: 12',1,true) and text:find('Satchel: 18',1,true))
        assert(text:find('Reserved from moves: 5 in Inventory; 0 in other bags',1,true))
        assert(not text:find('Eligible to store:',1,true), 'zero-only store summary should be hidden')
        local preview=t.get('item_settings_preview')({id=4096,carried=12,locations={[0]=12,[5]=18},stack_size=12},
            assert(t.get('collect_live_items')()),t.get('ui').item_draft)
        assert(preview.store_quantity==0 and preview.store_slots==0 and preview.deposit_quantity==25,
            'partial protected stack or deposit surplus calculation changed')

        actions.quantity=18
        t.get('render_protections')()
        t.get('render_protections')() -- Summary uses the edited value on the following frame.
        text=table.concat(drawn,' ')
        assert(text:find('Reserved from moves: 12 in Inventory; 6 in other bags',1,true))
        assert(t.saved().keep['4096']==5,'quantity preview must not save the edited rule')
    end)

    t.test('character change abandons a draft and temporary pause ends separately',function()
        t.put(0,1,4096,12)
        local actions=install_ui()
        local ui=open_and_select(actions,'Fire Crystal')
        ui.item_draft.mode='all'
        t.character('Alt',43)
        t.settings_update({keep={},sort_enabled=false,deposit_enabled=false,
            background={enabled=false,free_slots=5,items={}}})
        assert(ui.item_draft==nil and ui.selected_item_id==nil)

        t.character('Offline',42)
        t.settings_update({keep={},sort_enabled=false,deposit_enabled=false,
            background={enabled=false,free_slots=5,items={}}})
        t.get('automatic').owner='Offline_42'
        t.get('automatic').holds['4096']=true
        ui.protections_visible=true; ui.selected_item_id=4096
        actions.clicks['Release temporary choice##release_hold']=true
        t.get('render_protections')()
        assert(not t.get('automatic').holds['4096'])
        assert(t.saved().keep['4096']==nil)
    end)

    t.test('Item rules editor saves a destination, carried target, and explicit crystal deposit',function()
        t.put(0,1,4096,6); t.put(5,1,4096,12)
        local actions=install_ui()
        open_and_select(actions,'Fire Crystal')
        actions.combo='##item_destination'
        actions.select='Sack####item_destination6'
        actions.carry_target=24
        actions.deposit=true
        t.get('render_protections')()
        local draft=t.get('ui').item_draft
        assert(draft.destination==6 and draft.carry_target[1]==24 and draft.deposit[1],
            ('draft destination=%s carry=%s deposit=%s'):format(tostring(draft.destination),
                tostring(draft.carry_target[1]),tostring(draft.deposit[1])))
        actions.clicks['Apply item settings##ignore_apply']=true
        t.get('render_protections')()
        local rule=t.saved().item_rules.items['4096']
        assert(rule and rule.destination==6 and rule.carry_target==24 and rule.deposit==true)
        assert(t.saved().background.enabled==false and t.saved().deposit_enabled==false,
            'item rule unexpectedly enabled global automation')
    end)

    t.test('per-item outcomes are validated and isolated to their character',function()
        local save=t.get('set_keep_rule')
        assert(save(4096,nil,nil,{carry_target=24,destination=6,deposit=true}))
        assert(t.saved().item_rules.items['4096'].destination==6)
        assert(not save(900,nil,nil,{carry_target=0,destination=10,deposit=false}),
            'non-equipment was accepted into a wardrobe')
        assert(t.saved().item_rules.items['900']==nil)

        t.character('Alt',43)
        t.settings_update({keep={},sort_enabled=false,deposit_enabled=false,
            background={enabled=false,free_slots=5,items={}}})
        assert(not t.preferences().item_rules or next(t.preferences().item_rules.items)==nil,
            'one character inherited another character item rules')
    end)
end
