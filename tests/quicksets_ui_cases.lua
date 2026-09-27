return function(t)
    local function install_ui()
        local actions={click=nil,combo=nil,input=nil,available_width=520,available_height=480,font_size=16}
        local calls={children=0,child_ends=0,combos=0,combo_ends=0,selectables={},drawn={},
            child_entries={},same_lines={},region_stack={}}
        local noop=function() end
        local imgui={
            GetContentRegionAvail=function()
                local region=calls.region_stack[#calls.region_stack]
                return region and region[1] or actions.available_width,
                    region and region[2] or actions.available_height
            end,
            GetFontSize=function() return actions.font_size end,
            PushItemWidth=noop, PopItemWidth=noop,
            TextWrapped=function(value) calls.drawn[#calls.drawn+1]=tostring(value) end,
            TextUnformatted=function(value) calls.drawn[#calls.drawn+1]=tostring(value) end,
            InputText=function(label,value)
                if label=='##layout_name' and actions.input then value[1]=actions.input; actions.input=nil; return true end
                return false
            end,
            Button=function(label)
                if actions.click==label then actions.click=nil; return true end
                return false
            end,
            BeginCombo=function(id)
                if actions.combo and actions.combo.id==id then calls.combos=calls.combos+1; return true end
                return false
            end,
            Selectable=function(label)
                calls.selectables[#calls.selectables+1]=tostring(label)
                if actions.combo and tostring(label):find(actions.combo.label,1,true) then
                    actions.combo=nil; return true
                end
                return false
            end,
            EndCombo=function() calls.combo_ends=calls.combo_ends+1 end,
            BeginChild=function(id,size)
                calls.children=calls.children+1
                local width=(type(size)=='table' and (size[1] or size.x)) or actions.available_width
                local height=(type(size)=='table' and (size[2] or size.y)) or actions.available_height
                calls.child_entries[#calls.child_entries+1]={id=id,width=width,height=height}
                calls.region_stack[#calls.region_stack+1]={width,height}
                return true
            end,
            EndChild=function() calls.child_ends=calls.child_ends+1; table.remove(calls.region_stack) end,
            SameLine=function(offset,gap) calls.same_lines[#calls.same_lines+1]={offset=offset,gap=gap} end,
        }
        t.replace('imgui',imgui)
        return actions,calls
    end

    local function clear(calls)
        calls.children,calls.child_ends,calls.combos,calls.combo_ends=0,0,0,0
        calls.selectables,calls.drawn,calls.child_entries,calls.same_lines,calls.region_stack={},{},{},{},{}
    end

    local function render(t,calls)
        t.get('render_layout_editor')(false)
        assert(calls.children==calls.child_ends,'layout map left an unmatched child')
        assert(calls.combos==calls.combo_ends,'layout editor left an unmatched combo')
    end

    local function choose(actions,calls,t,id,label)
        actions.combo={id=id,label=label}; clear(calls); render(t,calls)
    end

    local function has(values,needle)
        for _,value in ipairs(values) do if value:find(needle,1,true) then return true end end
        return false
    end

    t.test('base layout draft persists until Set destination and Apply',function()
        local actions,calls=install_ui()
        local ui=t.get('ui')
        clear(calls); render(t,calls)
        local draft=assert(ui.layout_draft)
        assert(draft.category=='crystals' and draft.bag==0)

        choose(actions,calls,t,'##layout_bag','Sack')
        assert(draft.bag==6 and draft.routes.crystals==nil,'bag choice applied before Set destination')
        assert(t.saved().storage_layout==nil,'draft selection wrote settings before Save')
        clear(calls); render(t,calls)
        assert(draft.bag==6,'bag choice did not survive a frame')

        actions.click='Set destination##layout_set'; clear(calls); render(t,calls)
        assert(draft.routes.crystals==6 and t.saved().storage_layout==nil)
        actions.click='Apply layout##layout_save'
        clear(calls); render(t,calls)
        assert(t.saved().storage_layout.active=='')
        assert(t.saved().storage_layout.overrides.crystals==6)

        t.put(5,1,4096,12)
        local snapshot=assert(t.get('collect_live_items')())
        local plan=assert(t.get('build_organize_plan')(snapshot,{scope='storage',character_slug='Offline_42'}))
        assert(#plan.logical_moves==1 and plan.logical_moves[1].target_container_id==6,
            'bulk planner did not read the saved base override')
        t.replace('imgui',nil)
    end)

    t.test('reload reopens the saved layout and character change discards the draft',function()
        local actions,calls=install_ui()
        local desired={version=1,active='Saved Layout',sets={['Saved Layout']={crystals=6,['gear.main']=10}}}
        assert(t.get('automatic').save_layout(desired))
        t.get('ui').layout_draft=nil
        clear(calls); render(t,calls)
        local draft=assert(t.get('ui').layout_draft)
        assert(draft.selected=='Saved Layout' and draft.routes.crystals==6)

        draft.bag=5
        t.character('Alt',43)
        t.settings_update({keep={},sort_enabled=false,deposit_enabled=false,
            background={enabled=false,free_slots=5,items={}},
            storage_layout={version=1,active='',sets={}}})
        clear(calls); render(t,calls)
        assert(t.get('ui').layout_draft.character=='Alt_43')
        assert(t.get('ui').layout_draft.routes.crystals==nil,'new character inherited an unsaved route')
        t.replace('imgui',nil)
    end)

    t.test('item type changes reset destination and wardrobes appear only for gear',function()
        local actions,calls=install_ui()
        clear(calls); render(t,calls)
        local draft=t.get('ui').layout_draft
        draft.bag=6
        choose(actions,calls,t,'##layout_bag','Leave where it is')
        choose(actions,calls,t,'##layout_bag','Sack')
        actions.combo={id='##layout_bag',label='never-selected'}; clear(calls); render(t,calls)
        assert(not has(calls.selectables,'Wardrobe'),'non-equipment destination list exposed a wardrobe')
        actions.combo=nil

        choose(actions,calls,t,'##layout_type','Main weapons')
        assert(draft.category=='gear.main' and draft.bag==0,'type change retained another type destination')
        actions.combo={id='##layout_bag',label='never-selected'}; clear(calls); render(t,calls)
        assert(has(calls.selectables,'Wardrobe2'),'gear destination list omitted Wardrobe2')
        actions.combo=nil
        t.replace('imgui',nil)
    end)

    t.test('layout preview conserves a partially ignored stack across destinations',function()
        t.reset({['4096']=5})
        t.preferences().storage_layout={version=1,active='Care',sets={Care={crystals=6}}}
        t.put(0,1,4096,12)
        t.get('handle_organize')({'/oddorg','organize','preview','storage'})
        local plan=assert(t.get('ui').preview_plan)
        assert(#plan.logical_moves==1 and plan.logical_moves[1].quantity==7)
        local _,calls=install_ui()
        clear(calls); t.get('render_layout_map')(nil,plan)
        assert(calls.children==calls.child_ends,'preview map left an unmatched child')
        assert(has(calls.drawn,'Crystals: 5 items') and has(calls.drawn,'Crystals: 7 items'),
            table.concat(calls.drawn,' | '))
        t.replace('imgui',nil)
    end)

    t.test('layout map keeps useful bag cards within wide and narrow content regions',function()
        local actions,calls=install_ui()
        local routes={furnishing=1,crystals=6,['gear.main']=10}
        actions.available_width,actions.available_height,actions.font_size=900,600,18
        clear(calls); t.get('render_layout_map')(routes,nil)
        assert(calls.children==3 and calls.child_ends==3 and #calls.child_entries==3)
        local first,second,third=calls.child_entries[1],calls.child_entries[2],calls.child_entries[3]
        assert(first.id=='layout_bag_1' and second.id=='layout_bag_6' and third.id=='layout_bag_10')
        assert(first.width>=280*1.125 and first.width<=900 and second.width==first.width,
            'wide cards lost their useful minimum width')
        assert(#calls.same_lines==1 and math.abs((first.width+second.width+calls.same_lines[1].gap)-900)<0.01,
            'wide card row overflowed or wasted its available width')
        assert(first.height==second.height and first.height>0 and third.height>0,
            'cards in the same row did not share a useful height')

        actions.available_width,actions.available_height=520,600
        clear(calls); t.get('render_layout_map')(routes,nil)
        assert(calls.children==3 and #calls.same_lines==0,'narrow map did not collapse to one column')
        for _,entry in ipairs(calls.child_entries) do
            assert(entry.width==520 and entry.width>0 and entry.height>0,
                'narrow card exceeded or failed to use the available width')
        end
        assert(#calls.region_stack==0,'child region stack leaked after map rendering')
        t.replace('imgui',nil)
    end)
end
