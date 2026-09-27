package.path = './addons/oddorg/?.lua;' .. package.path

local calls = { files={}, items={}, images={}, rects={}, lines={}, texts={}, children={}, same_lines={}, style_pushes={}, style_pops=0 }
local file_ids = { ['surface-atlas.png']=101, ['destination-atlas.png']=202 }
package.loaded.ui_textures = {
    file = function(_, name)
        calls.files[#calls.files+1] = name
        return file_ids[name]
    end,
    item = function(id)
        calls.items[#calls.items+1] = id
        return calls.item_id
    end,
    release = function() end,
}

local art = assert(loadfile('./addons/oddorg/ui_art.lua'))()
package.loaded.ui_art = art
local skin = assert(loadfile('./addons/oddorg/ui_skin.lua'))()
skin.configure('addon-root')

local draw = {
    AddImage = function(_, id, min, max, uv_min, uv_max, tint)
        calls.images[#calls.images+1] = {id=id,min=min,max=max,uv_min=uv_min,uv_max=uv_max,tint=tint}
    end,
    AddRect = function(_, min, max) calls.rects[#calls.rects+1] = {min=min,max=max} end,
    AddLine = function(_, start_pos, end_pos, color, thickness)
        calls.lines[#calls.lines+1] = {start_pos=start_pos,end_pos=end_pos,color=color,thickness=thickness}
    end,
    AddText = function(_, pos, _, text) calls.texts[#calls.texts+1] = {pos=pos,text=text} end,
}
local function reset()
    calls.files, calls.items, calls.images = {}, {}, {}
    calls.rects, calls.lines, calls.texts, calls.children, calls.same_lines, calls.style_pushes = {}, {}, {}, {}, {}, {}
    calls.style_pops = 0
    calls.item_id = nil
    file_ids['surface-atlas.png'], file_ids['destination-atlas.png'] = 101, 202
end
local passed = 0
local function test(name, fn)
    reset()
    skin.release()
    fn()
    passed = passed + 1
    print('PASS ' .. name)
end

test('atlas UVs are bounded and destination art is aspect-fit inside its slot', function()
    for name, uv in pairs(art.destinations) do
        assert(#uv == 4 and uv[1] >= 0 and uv[2] >= 0 and uv[3] <= 1 and uv[4] <= 1,
            name .. ' has out-of-range UVs')
        assert(uv[1] < uv[3] and uv[2] < uv[4], name .. ' has an empty UV region')
    end
    for name, uv in pairs(art.surfaces) do
        assert(uv[1] >= 0 and uv[2] >= 0 and uv[3] <= 1 and uv[4] <= 1,
            name .. ' has out-of-range surface UVs')
    end
    local imgui = {
        Dummy=function() end, GetCursorScreenPos=function() return 10,20 end,
        GetWindowDrawList=function() return draw end, IsItemVisible=function() return true end,
        GetColorU32=function() return 0xFFFFFFFF end,
    }
    assert(skin.icon(imgui,'inventory',48))
    local image = calls.images[1]
    assert(image and image.id == 202, 'destination atlas was not drawn')
    assert(#calls.images == 1 and #calls.files == 1 and calls.files[1] == 'destination-atlas.png',
        'icon artwork received an extra material backing')
    assert(image.min[1] >= 10 and image.min[2] >= 20 and image.max[1] <= 58 and image.max[2] <= 68,
        'destination art escaped its measured slot')
    local uv, rendered_ratio = art.destinations.inventory,
        (image.max[1]-image.min[1])/(image.max[2]-image.min[2])
    local source_ratio = ((uv[3]-uv[1])*art.width)/((uv[4]-uv[2])*art.height)
    assert(math.abs(rendered_ratio-source_ratio) < 0.001, 'destination art was stretched')
end)

test('hidden items do not request any texture', function()
    local imgui = {
        Dummy=function() end, GetCursorScreenPos=function() return 0,0 end,
        GetWindowDrawList=function() return draw end, IsItemVisible=function() return false end,
    }
    assert(skin.icon(imgui,'inventory',32,4096))
    assert(#calls.files == 0 and #calls.items == 0 and #calls.images == 0)
end)

test('missing item texture uses an outline without drawing the destination atlas', function()
    local imgui = {
        Dummy=function() end, GetCursorScreenPos=function() return 0,0 end,
        GetWindowDrawList=function() return draw end, IsItemVisible=function() return true end,
        GetColorU32=function() return 0xFFFFFFFF end,
    }
    assert(skin.icon(imgui,'inventory',32,4096))
    assert(#calls.items == 1 and calls.items[1] == 4096)
    assert(#calls.files == 0, 'missing item requested a material or destination texture')
    assert(#calls.images == 0 and #calls.rects == 1)
end)

test('bag mappings cover Safe2 and all eight wardrobes', function()
    assert(art.bags[9] == 'safe2', 'Safe2 destination is missing')
    for bag=8,16 do
        if bag ~= 9 then assert(art.bags[bag] == 'wardrobe', 'Wardrobe mapping missing for bag '..bag) end
    end
end)

test('locations render plain positive storage quantities without artwork or cards', function()
    local imgui = {
        TextWrapped=function(text) calls.texts[#calls.texts+1]={text=text} end,
    }
    skin.locations(imgui,{[0]=3,[5]=0,[9]=-2,[10]=7},{[0]='Inventory',[10]='Wardrobe 7'},1.125)
    local rendered = {}
    for _,entry in ipairs(calls.texts) do rendered[#rendered+1]=entry.text end
    assert(table.concat(rendered,'|') == 'Inventory: 3|Wardrobe 7: 7')
    assert(#calls.children == 0 and #calls.files == 0 and #calls.images == 0,
        'plain location rows restored cards or storage artwork')
end)

test('button overlay strips ImGui id and stays inside the measured rectangle', function()
    local measured
    local imgui = {
        GetItemRectMin=function() return 10,20 end, GetItemRectMax=function() return 130,60 end,
        GetWindowDrawList=function() return draw end, GetColorU32=function() return 0xFFFFFFFF end,
        CalcTextSize=function(text) measured=text; return 48,12 end,
        IsItemFocused=function() return false end,
    }
    skin.button_finish(imgui,'Run organization##oddorg_run',false,false)
    assert(measured == 'Run organization' and calls.texts[1].text == 'Run organization')
    local image = calls.images[1]
    assert(image.min[1] == 11 and image.min[2] == 21 and image.max[1] == 129 and image.max[2] == 59,
        'button art did not use the native measured rectangle')
    local pos = calls.texts[1].pos
    assert(pos[1] >= 10 and pos[1] <= 130 and pos[2] >= 20 and pos[2] <= 60,
        'button label escaped its hit rectangle')
end)

test('button hover eases once to a steady surface and fades on exit', function()
    local now, hovered = 0, true
    local imgui = {
        GetItemRectMin=function() return 10,20 end, GetItemRectMax=function() return 130,60 end,
        GetWindowDrawList=function() return draw end, GetColorU32=function(color) return color end,
        CalcTextSize=function() return 40,12 end, IsItemHovered=function() return hovered end,
        IsItemFocused=function() return false end, GetTime=function() return now end,
    }
    local drawn_lines = 0
    local function render()
        calls.images, calls.rects, calls.lines, calls.texts = {}, {}, {}, {}
        skin.button_finish(imgui,'Preview##run',false,false)
        drawn_lines = drawn_lines + #calls.lines
        return calls.images[1].tint[4]
    end
    local entry = render()
    now = 0.09
    local arriving = render()
    now = 0.18
    local settled = render()
    local settled_rims = #calls.rects
    now = 0.72
    local held = render()
    assert(entry < arriving and arriving < settled,
        'hover material did not ease into its finished appearance')
    assert(settled_rims == 2, 'hover did not reveal its layered cyan edge')
    assert(settled == held, 'hover material continued changing after arrival')
    hovered, now = false, 0.72
    local exit = render()
    now = 0.81
    local leaving = render()
    now = 0.90
    local resting = render()
    assert(exit == settled and leaving > resting and resting < leaving,
        'hover material did not fade smoothly back to rest')
    assert(resting == 0.32, 'button material did not return to its resting strength')
    assert(#calls.rects == 0 and #calls.lines == 0 and drawn_lines == 0,
        'unhovered button retained a highlight or moving glint')
end)

test('selected buttons keep a tactile surface and a persistent focus accent', function()
    local imgui = {
        GetItemRectMin=function() return 10,20 end, GetItemRectMax=function() return 130,60 end,
        GetWindowDrawList=function() return draw end, GetColorU32=function(color) return color end,
        CalcTextSize=function() return 40,12 end, IsItemHovered=function() return false end,
        IsItemFocused=function() return false end,
    }
    skin.button_finish(imgui,'Item rules##tab',true,false)
    assert(calls.images[1].tint[4] >= 0.36, 'selected button lost its textured surface')
    assert(#calls.rects == 1 and #calls.lines == 0,
        'selected button did not retain a quiet persistent accent')
end)

test('text fields receive a quieter textured hover treatment', function()
    local imgui = {
        GetItemRectMin=function() return 8,12 end, GetItemRectMax=function() return 180,42 end,
        GetWindowDrawList=function() return draw end, GetColorU32=function(color) return color end,
        IsItemHovered=function() return true end, IsItemFocused=function() return false end,
        GetTime=function() return 0.45 end,
    }
    assert(skin.control_finish(imgui,nil,false,'test_field'))
    assert(calls.images[1].id == 101 and calls.images[1].tint[4] < 0.2,
        'text field texture overwhelmed its native contents')
    assert(#calls.rects == 2 and #calls.lines == 0,
        'text field hover missed its layered border or drew a moving glint')
end)

test('disabled buttons do not animate or show an enabled focus ring', function()
    local imgui = {
        GetItemRectMin=function() return 10,20 end, GetItemRectMax=function() return 130,60 end,
        GetWindowDrawList=function() return draw end, GetColorU32=function(color) return color end,
        CalcTextSize=function() return 40,12 end, IsItemHovered=function() return true end,
        IsItemFocused=function() return true end, GetTime=function() return 0.45 end,
    }
    skin.button_finish(imgui,'Unavailable',false,true)
    assert(#calls.lines == 0 and #calls.rects == 0,
        'disabled button showed an enabled hover or focus treatment')
    assert(calls.images[1].tint[4] == 0.12, 'disabled button texture was not subdued')
end)

test('hovered switches ease their track color without a halo or recurring glint', function()
    local halos, labels, images, outlines, lines, tracks = {}, {}, {}, {}, {}, {}
    local hover_draw = {
        AddImage=function(_,id) images[#images+1]=id end,
        AddRect=function() outlines[#outlines+1]=true end,
        AddLine=function() lines[#lines+1]=true end,
        AddRectFilled=function(_,_,_,color) tracks[#tracks+1]=color end,
        AddCircleFilled=function(_,center) end,
        AddCircle=function(_,center,radius,color,segments,thickness)
            halos[#halos+1]={center=center,radius=radius,thickness=thickness}
        end,
        AddText=function(_,_,_,text) labels[#labels+1]=text end,
    }
    local now = 0.7
    local imgui = {
        GetWindowDrawList=function() return hover_draw end,
        GetItemRectMin=function() return 10,20 end, GetItemRectMax=function() return 106,54 end,
        GetColorU32=function(color) return color end,
        GetTime=function() return now end,
        IsItemHovered=function() return true end, IsItemFocused=function() return false end,
        Button=function() return false end,
    }
    local changed, next_value = skin.toggle(imgui,'hover_switch',false,false,1)
    assert(not changed and not next_value and labels[#labels] == 'OFF',
        'hover changed the switch value or hid its state label')
    local entry_track = tracks[#tracks]
    now = 0.88
    skin.toggle(imgui,'hover_switch',false,false,1)
    local settled_track = tracks[#tracks]
    assert(entry_track[1] == skin.colors.surface[1] and settled_track[1] == skin.colors.blue_hover[1]
        and settled_track[2] == skin.colors.blue_hover[2],
        'switch track did not ease from its material to the settled hover color')
    assert(#images == 2 and #halos == 0 and #outlines == 4 and #lines == 0,
        'switch hover missed its surface or added a halo or recurring glint')
end)

test('native capability fallbacks tolerate absent optional methods', function()
    assert(not skin.material({},'panel',0,0,10,10))
    assert(pcall(skin.panel,{},'panel'))
    assert(not skin.icon({},'inventory',32))
    assert(pcall(skin.locations,{}, {}, {}, 1))
    assert(pcall(skin.button_finish,{},'Label##id',false,false))
    assert(not skin.control_finish({}), 'missing optional drawing APIs were not tolerated')
end)

print(('PASS %u textured skin renderer cases; inert mocks only'):format(passed))
