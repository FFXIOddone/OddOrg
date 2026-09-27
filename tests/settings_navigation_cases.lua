return function(t)
    local active_calls
    local function install_ui()
        local calls={buttons={},button_sizes={},checkboxes={},inputs={},begins={},ends=0,
            children=0,child_ends=0,child_ids={},drawn={},selectables={},item_widths={},
            push_colors=0,pop_colors=0,push_vars=0,pop_vars=0,disabled_begins=0,disabled_ends=0,
            disabled_depth=0,disabled_buttons={},sliders={},child_sizes={},cursor_positions={},
            color_current={},color_stack={},button_colors={},available_width=520,available_height=480,old_globals={}}
        local style_ids={'ImGuiCol_Border','ImGuiCol_Button','ImGuiCol_ButtonActive','ImGuiCol_ButtonHovered',
            'ImGuiCol_CheckMark','ImGuiCol_ChildBg','ImGuiCol_FrameBg','ImGuiCol_FrameBgActive',
            'ImGuiCol_FrameBgHovered','ImGuiCol_Header','ImGuiCol_HeaderActive','ImGuiCol_HeaderHovered',
            'ImGuiCol_ScrollbarBg','ImGuiCol_ScrollbarGrab','ImGuiCol_ScrollbarGrabActive',
            'ImGuiCol_ScrollbarGrabHovered','ImGuiCol_SliderGrab','ImGuiCol_SliderGrabActive','ImGuiCol_Text',
            'ImGuiCol_TextDisabled','ImGuiCol_TitleBg','ImGuiCol_TitleBgActive','ImGuiCol_TitleBgCollapsed','ImGuiCol_WindowBg',
            'ImGuiStyleVar_ChildBorderSize','ImGuiStyleVar_ChildRounding','ImGuiStyleVar_FrameBorderSize',
            'ImGuiStyleVar_FramePadding','ImGuiStyleVar_FrameRounding','ImGuiStyleVar_ItemInnerSpacing',
            'ImGuiStyleVar_ItemSpacing','ImGuiStyleVar_WindowPadding','ImGuiStyleVar_WindowRounding'}
        for index,name in ipairs(style_ids) do calls.old_globals[name]=_G[name] or false; _G[name]=index end
        local imgui={
            Begin=function(name) calls.begins[#calls.begins+1]=name; return true end,
            End=function() calls.ends=calls.ends+1 end,
            BeginChild=function(id,size) calls.children=calls.children+1; calls.child_ids[#calls.child_ids+1]=id; calls.child_sizes[id]=size; return true end,
            EndChild=function() calls.child_ends=calls.child_ends+1 end,
            SetNextWindowSize=function() end,
            GetContentRegionAvail=function() return calls.available_width,calls.available_height end,
            PushItemWidth=function(width) calls.pushed_item_widths=(calls.pushed_item_widths or 0)+1; calls.item_widths[#calls.item_widths+1]=width end,
            PopItemWidth=function() calls.item_width_pops=(calls.item_width_pops or 0)+1 end,
            SetNextItemWidth=function(width) calls.next_item_widths=calls.next_item_widths or {}; calls.next_item_widths[#calls.next_item_widths+1]=width end,
            PushStyleColor=function(slot,color)
                calls.push_colors=calls.push_colors+1
                calls.color_stack[#calls.color_stack+1]={slot=slot,previous=calls.color_current[slot]}
                calls.color_current[slot]=color
            end,
            PopStyleColor=function(count)
                count=count or 1; calls.pop_colors=calls.pop_colors+count
                for _=1,count do local prior=table.remove(calls.color_stack); if prior then calls.color_current[prior.slot]=prior.previous end end
            end,
            PushStyleVar=function() calls.push_vars=calls.push_vars+1 end,
            PopStyleVar=function(count) calls.pop_vars=calls.pop_vars+(count or 1) end,
            BeginDisabled=function() calls.disabled_begins=calls.disabled_begins+1; calls.disabled_depth=calls.disabled_depth+1 end,
            EndDisabled=function() calls.disabled_ends=calls.disabled_ends+1; calls.disabled_depth=calls.disabled_depth-1 end,
            SetCursorPosX=function(value) calls.cursor_positions[#calls.cursor_positions+1]=value end,
            SameLine=function() end,
            TextWrapped=function(value) calls.drawn[#calls.drawn+1]=tostring(value) end,
            TextUnformatted=function(value) calls.drawn[#calls.drawn+1]=tostring(value) end,
            Button=function(label,size)
                calls.buttons[#calls.buttons+1]=label; calls.button_sizes[label]=size
                calls.disabled_buttons[label]=calls.disabled_depth>0
                calls.button_colors[label]={
                    button=calls.color_current[_G.ImGuiCol_Button],
                    hovered=calls.color_current[_G.ImGuiCol_ButtonHovered],
                    active=calls.color_current[_G.ImGuiCol_ButtonActive] }
                local click=calls.click
                if click==label or (type(click)=='string' and click:sub(1,2)=='##' and label:sub(-#click)==click) then
                    calls.click=nil; return true
                end
                return false
            end,
            Checkbox=function(label,value)
                calls.checkboxes[#calls.checkboxes+1]=label
                if calls.checkbox and calls.checkbox.label==label then
                    value[1]=calls.checkbox.value; calls.checkbox=nil; return true
                end
                return false
            end,
            InputInt=function(label,value)
                calls.inputs[#calls.inputs+1]=label
                if calls.input and calls.input.label==label then value[1]=calls.input.value; calls.input=nil; return true end
                return false
            end,
            InputText=function(label) calls.inputs[#calls.inputs+1]=label; return false end,
            Selectable=function(label) calls.selectables[#calls.selectables+1]=label; return false end,
            SliderInt=function(label,value,minimum,maximum)
                calls.sliders[#calls.sliders+1]={label=label,min=minimum,max=maximum}
                if calls.slider and (calls.slider.label==label or label:sub(-#calls.slider.label)==calls.slider.label) then
                    value[1]=calls.slider.value; calls.slider=nil; return true
                end
                return false
            end,
        }
        t.replace('imgui',imgui)
        active_calls=calls
        return calls
    end
    local function finish_ui(t,calls)
        assert(calls.push_colors==calls.pop_colors,'unbalanced ImGui color stack')
        assert(calls.push_vars==calls.pop_vars,'unbalanced ImGui style stack')
        assert(calls.disabled_begins==calls.disabled_ends,'unbalanced disabled widget stack')
        t.replace('imgui',nil)
        for name,value in pairs(calls.old_globals) do _G[name]=value~=false and value or nil end
        active_calls=nil
    end
    local function assert_balanced(calls)
        assert(#calls.begins==calls.ends,'unbalanced native window stack')
        assert(calls.children==calls.child_ends,'unbalanced child stack')
        assert(calls.push_colors==calls.pop_colors,'unbalanced ImGui color stack')
        assert(calls.push_vars==calls.pop_vars,'unbalanced ImGui style stack')
        assert(calls.disabled_begins==calls.disabled_ends,'unbalanced disabled widget stack')
        assert((calls.pushed_item_widths or 0)==(calls.item_width_pops or 0),'unbalanced item width stack')
    end
    local function dim(size,key,index)
        if type(size)~='table' then return nil end
        return size[key] or size[index]
    end
    local function render(t,calls)
        t.get('render_ui')()
        local measured=calls or active_calls
        assert_balanced(measured)
        for _,width in ipairs(measured.item_widths) do assert(width>0 and width<=measured.available_width,'item width exceeds available width') end
        for _,width in ipairs(measured.next_item_widths or {}) do assert(width>0 and width<=measured.available_width,'next item width exceeds available width') end
        for _,size in pairs(measured.button_sizes) do
            local width=dim(size,'x',1) or dim(size,'width',1)
            if width then assert(width>=0 and width<=measured.available_width,'button width exceeds available width') end
        end
        for _,size in pairs(measured.child_sizes) do
            local width=dim(size,'x',1) or dim(size,'width',1)
            if width and width>0 then assert(width<=measured.available_width,'child width exceeds available width') end
        end
    end
    local function assert_bounded(calls)
        for label,size in pairs(calls.button_sizes) do
            local width=dim(size,'x',1) or dim(size,'width',1)
            if width then assert(width>0 and width<=calls.available_width,label .. ' width exceeded available region') end
        end
        for _,width in ipairs(calls.item_widths) do
            assert(width>0 and width<=calls.available_width,'item control width exceeded available region')
        end
        for _,width in ipairs(calls.next_item_widths or {}) do
            assert(width>0 and width<=calls.available_width,'next item width exceeded available region')
        end
    end
    local function has(values,needle) for _,value in ipairs(values) do if value==needle then return true end end; return false end
    local function clear(calls)
        calls.buttons={}; calls.button_sizes={}; calls.checkboxes={}; calls.inputs={}; calls.begins={}; calls.ends=0
        calls.children=0; calls.child_ends=0; calls.child_ids={}; calls.drawn={}; calls.selectables={}
        calls.item_widths={}; calls.next_item_widths={}; calls.pushed_item_widths=0; calls.item_width_pops=0; calls.push_colors=0; calls.pop_colors=0
        calls.push_vars=0; calls.pop_vars=0; calls.disabled_begins=0; calls.disabled_ends=0
        calls.disabled_depth=0; calls.disabled_buttons={}; calls.sliders={}; calls.child_sizes={}; calls.cursor_positions={}
        calls.button_colors={}; calls.color_current={}; calls.color_stack={}
    end

    t.test('home exposes only Settings and settings tabs isolate their sections',function()
        t.reset()
        local calls=install_ui()
        local ui=t.get('ui'); ui.visible=true; ui.page='home'; ui.settings_tab='automatic'; ui.scope='all'; ui.crystal_scope='all'
        render(t)
        assert(#calls.buttons==1 and calls.buttons[1]=='Settings##oddorg_settings')
        assert(#calls.checkboxes==0 and #calls.inputs==0,'home exposed editable settings controls')
        calls.click='Settings##oddorg_settings'; clear(calls); render(t)
        clear(calls); render(t)
        assert(ui.page=='settings' and has(calls.buttons,'Home##oddorg_home'))
        assert(has(calls.buttons,'Automatic care##settings_auto')
            and has(calls.buttons,'Item rules##settings_ignore')
            and has(calls.buttons,'Bulk Run##settings_bulk'))
        assert(has(calls.buttons,'OFF###care_space_toggle'))
        assert(not has(calls.buttons,'Apply automatic settings##care_apply'),
            'clean automatic state exposed Apply')
        assert(has(calls.child_ids,'oddorg_settings_body') and has(calls.child_ids,'##care_space_row'),
            'settings body and feature rows were not laid out')
        local nav_width=calls.button_sizes['Home##oddorg_home'][1]
            +calls.button_sizes['Automatic care##settings_auto'][1]
            +calls.button_sizes['Item rules##settings_ignore'][1]
            +calls.button_sizes['Bulk Run##settings_bulk'][1]+36
        assert(nav_width<=calls.available_width,'top navigation exceeds available width')
        local copy_width=calls.child_sizes['##care_space_copy'][1]
        local control_width=calls.child_sizes['##care_space_control'][1]
        assert(copy_width+12+control_width<=calls.available_width,
            'feature row text, gap, and toggle exceed the available width')
        assert(calls.button_sizes['OFF###care_space_toggle'][1]>0,
            'feature toggle did not receive an explicit hit target width')
        assert(not has(calls.buttons,'Run organization##oddorg_run')
            and not has(calls.inputs,'Find item'))

        calls.click='Item rules##settings_ignore'; clear(calls); render(t)
        assert(not has(calls.buttons,'OFF###care_space_toggle') and #calls.sliders==0,
            'Ignore tab rendered automatic controls')
        assert(has(calls.inputs,'##ignore_search') and calls.children>0,
            'Ignore tab did not render its embedded item body')
        assert(#calls.begins==1 and calls.ends==1,'Ignore tab opened a nested native window')
        assert(calls.children==calls.child_ends,'Ignore body left an unmatched child region')

        calls.click='Bulk Run##settings_bulk'; clear(calls); render(t)
        assert(has(calls.buttons,'View Plan##oddorg_preview')
            and not has(calls.buttons,'Run organization##oddorg_run'), table.concat(calls.buttons,' | '))
        assert(not has(calls.buttons,'OFF###care_space_toggle') and #calls.sliders==0
            and not has(calls.inputs,'Find item'),'Bulk tab rendered controls from another section')
        finish_ui(t,calls)
    end)

    t.test('draft survives navigation and bulk controls preserve selected crystal scope',function()
        t.reset()
        local calls=install_ui()
        local ui=t.get('ui'); ui.visible=true; ui.page='settings'; ui.settings_tab='automatic'; ui.scope='all'; ui.crystal_scope='all'
        t.put(0,1,901,12)
        clear(calls); render(t)
        calls.click='##care_space_toggle'
        clear(calls); render(t)
        local draft=assert(ui.automation_draft)
        assert(draft.enabled[1] and not t.saved().background.enabled,'editing draft persisted')
        calls.slider={label='##care_slots',value=8}
        clear(calls); render(t)
        assert(draft.free_slots[1]==8 and #calls.sliders==1
            and calls.sliders[1].min==1 and calls.sliders[1].max==80,
            'slot slider did not retain a bounded draft value')
        calls.click='Item rules##settings_ignore'; clear(calls); render(t)
        calls.click='Automatic care##settings_auto'; clear(calls); render(t)
        assert(ui.automation_draft==draft and draft.enabled[1],'tab navigation discarded automatic draft')
        assert(not t.saved().background.enabled,'navigation saved automatic draft')

        calls.click='Bulk Run##settings_bulk'; clear(calls); render(t)
        calls.click='View Plan##oddorg_preview'; clear(calls); render(t)
        assert(not ui.preview_visible and ui.preview_plan and #ui.preview_plan.logical_moves>0
            and has(calls.child_ids,'oddorg_bulk_layout_preview'),
            'Bulk preview did not produce a plan for the Inventory Copper Ore fixture')
        ui.scope='crystals'
        calls.click='Inventory##crystal_scope'; clear(calls); render(t)
        assert(ui.crystal_scope=='inventory','crystal source selector ignored selected scope')
        t.put(0,1,4096,12)
        calls.click='Deposit surplus##oddorg_crystals_dump'; clear(calls); render(t)
        assert(t.get('ephemeral').running and t.get('ephemeral').scope=='inventory',
            'Bulk crystal deposit did not use the selected source scope')

        calls.click='Home##oddorg_home'; clear(calls); render(t)
        assert(ui.page=='home','Back did not return home')
        assert(t.saved().background.enabled==false,'navigation persisted the draft')
        t.character('Alt',43)
        t.settings_update({keep={},sort_enabled=false,deposit_enabled=false,
            background={enabled=false,free_slots=5,items={}}})
        assert(ui.page=='home' and ui.automation_draft==nil,
            'character callback did not return home and clear the automatic draft')
        finish_ui(t,calls)
    end)

    t.test('zero-move preview still reveals Run and enlarged View Plan uses the full scope width',function()
        local calls=install_ui()
        local ui=t.get('ui'); ui.visible=true; ui.page='settings'; ui.settings_tab='bulk'; ui.scope='all'
        clear(calls); render(t)
        assert(not has(calls.buttons,'Run organization##oddorg_run'))
        calls.click='View Plan##oddorg_preview'; clear(calls); render(t)
        clear(calls); render(t)
        assert(ui.preview_plan and #ui.preview_plan.logical_moves==0)
        assert(has(calls.buttons,'Run organization##oddorg_run'))
        local size=calls.button_sizes['View Plan##oddorg_preview']
        assert(size[1]==calls.available_width and size[2]==64)
        finish_ui(t,calls)
    end)

    t.test('Run organization starts the selected storage route and Stop cancels before sending',function()
        t.reset()
        local calls=install_ui()
        local ui=t.get('ui'); ui.visible=true; ui.page='settings'; ui.settings_tab='bulk'
        ui.scope='storage'; ui.preview_visible=false
        t.put(0,1,901,12)
        clear(calls); render(t)
        calls.click='View Plan##oddorg_preview'; clear(calls); render(t)
        clear(calls); render(t)
        assert(has(calls.buttons,'Run organization##oddorg_run'),
            'successful preview did not reveal Run organization')
        calls.click='Run organization##oddorg_run'; clear(calls); render(t)
        local organizer=t.get('organizer')
        assert(organizer.running and #organizer.queue>0,'Run organization did not start the queue')
        assert(organizer.scope=='storage' and organizer.queue[1].source_container_id==0
            and organizer.queue[1].target_container_id~=0,
            'Run organization ignored the chosen Storage scope or Inventory route')
        calls.click='Stop##oddorg_stop'; clear(calls); render(t)
        assert(not organizer.running and #t.moves()==0,
            'Stop did not cancel the newly started organization before its first transfer')
        finish_ui(t,calls)
    end)
end
