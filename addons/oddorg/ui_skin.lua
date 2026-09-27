local skin = {}
local textures = require('ui_textures')
local art = require('ui_art')
local asset_path = ''

skin.colors = {
    background = { 0.045, 0.055, 0.075, 1.00 },
    panel = { 0.075, 0.095, 0.125, 1.00 },
    surface = { 0.105, 0.135, 0.170, 1.00 },
    border = { 0.23, 0.31, 0.38, 0.90 },
    transparent = { 0.00, 0.00, 0.00, 0.00 },
    text = { 0.91, 0.95, 0.98, 1.00 },
    muted = { 0.60, 0.69, 0.76, 1.00 },
    attention = { 0.97, 0.67, 0.28, 1.00 },
    gold = { 0.88, 0.70, 0.42, 1.00 },
    active = { 0.38, 0.82, 0.52, 1.00 },
    blue = { 0.05, 0.40, 0.57, 0.96 },
    blue_hover = { 0.07, 0.48, 0.63, 1.00 },
    blue_press = { 0.04, 0.30, 0.44, 1.00 },
    blue_outline = { 0.10, 0.65, 0.82, 0.96 },
    blue_highlight = { 0.28, 0.83, 0.98, 1.00 },
    progress_track = { 0.40, 0.53, 0.63, 0.30 },
}

local function color_u32(imgui, color)
    if imgui.GetColorU32 ~= nil then return imgui.GetColorU32(color) end
    return color
end

function skin.configure(path)
    asset_path = type(path) == 'string' and path or ''
end

local function image_region(imgui, id, uv, x, y, width, height, alpha)
    local draw = imgui.GetWindowDrawList and imgui.GetWindowDrawList()
    if not id or not draw or not draw.AddImage or width <= 0 or height <= 0 then return false end
    draw:AddImage(id, {x,y}, {x+width,y+height}, {uv[1],uv[2]}, {uv[3],uv[4]},
        color_u32(imgui, {1,1,1,alpha or 1}))
    return true
end

function skin.material(imgui, kind, x, y, width, height, alpha)
    if not imgui.GetWindowDrawList then return false end
    local draw = imgui.GetWindowDrawList()
    if not draw or not draw.AddImage then return false end
    local uv = art.surfaces[kind]
    if not uv then return false end
    return image_region(imgui, textures.file(asset_path, 'surface-atlas.png'), uv, x,y,width,height,alpha)
end

function skin.panel(imgui, kind, alpha)
    if not imgui.GetWindowPos or not imgui.GetWindowSize then return end
    local x,y = imgui.GetWindowPos()
    local width,height = imgui.GetWindowSize()
    if tonumber(x) and tonumber(y) and tonumber(width) and tonumber(height) then
        skin.material(imgui, kind or 'panel', x,y,width,height,alpha or 0.35)
    end
end

local function animation_time(imgui)
    if not imgui.GetTime then return nil end
    local ok, value = pcall(imgui.GetTime)
    return ok and tonumber(value) or nil
end

local function alpha_color(color, alpha)
    return { color[1], color[2], color[3], alpha }
end

local hover_motion, hover_motion_order = {}, 0
local hover_motion_limit, hover_transition_seconds = 64, 0.18

local function make_hover_room()
    local count, oldest_key, oldest_order = 0, nil, nil
    for key, motion in pairs(hover_motion) do
        count = count + 1
        if oldest_order == nil or motion.order < oldest_order then
            oldest_key, oldest_order = key, motion.order
        end
    end
    if count >= hover_motion_limit and oldest_key ~= nil then
        hover_motion[oldest_key] = nil
    end
end

-- The material and rim make one short eased response to pointer entry, then
-- hold still. State is keyed by the native control identity and tightly capped.
local function hover_amount(imgui, key, hovered, disabled)
    if type(key) ~= 'string' or key == '' then return hovered and 1 or 0 end
    if disabled then
        hover_motion[key] = nil
        return 0
    end
    local motion = hover_motion[key]
    if motion == nil and not hovered then return 0 end
    local now = animation_time(imgui)
    if now == nil then
        hover_motion[key] = nil
        return hovered and 1 or 0
    end
    local target = hovered and 1 or 0
    if motion == nil then
        if target == 0 then return 0 end
        make_hover_room()
        motion = { from=0, value=0, target=1, started=now, order=0 }
        hover_motion[key] = motion
    elseif motion.target ~= target then
        motion.from = motion.value or 0
        motion.target, motion.started = target, now
    end
    hover_motion_order = hover_motion_order + 1
    motion.order = hover_motion_order
    local elapsed = math.max(0, math.min(1, (now - motion.started) / hover_transition_seconds))
    local eased = 1 - (1 - elapsed) * (1 - elapsed) * (1 - elapsed)
    motion.value = motion.from + (motion.target - motion.from) * eased
    if elapsed >= 1 then
        motion.value = motion.target
        if motion.target == 0 then hover_motion[key] = nil end
    end
    return motion.value
end

local function mix_color(from, to, amount)
    amount = math.max(0, math.min(1, tonumber(amount) or 0))
    return {
        from[1] + (to[1] - from[1]) * amount,
        from[2] + (to[2] - from[2]) * amount,
        from[3] + (to[3] - from[3]) * amount,
        from[4] + (to[4] - from[4]) * amount,
    }
end

local function interaction_rim(imgui, draw, x, y, right, bottom, outer_alpha, inner_alpha, rounding)
    if not draw.AddRect then return end
    draw:AddRect({x+1,y+1},{right-1,bottom-1},
        color_u32(imgui,alpha_color(skin.colors.blue_highlight,outer_alpha)),rounding)
    if inner_alpha > 0 and right-x > 6 and bottom-y > 6 then
        draw:AddRect({x+3,y+3},{right-3,bottom-3},
            color_u32(imgui,alpha_color(skin.colors.blue_highlight,inner_alpha)),math.max(1,rounding-2))
    end
end

-- Native Dummy owns layout and clipping; invisible rows never load an icon.
function skin.icon(imgui, kind, size, item_id)
    if not imgui.Dummy or not imgui.GetCursorScreenPos or not imgui.GetWindowDrawList then return false end
    local draw = imgui.GetWindowDrawList()
    if not draw or not draw.AddImage then return false end
    size = math.max(12, tonumber(size) or 32)
    local x,y = imgui.GetCursorScreenPos()
    if not tonumber(x) or not tonumber(y) then return false end
    imgui.Dummy({size,size})
    if imgui.IsItemVisible and not imgui.IsItemVisible() then return true end
    local uv = item_id and {0,0,1,1} or art.destinations[kind]
    local id
    if item_id then id=textures.item(item_id)
    elseif uv then id=textures.file(asset_path,'destination-atlas.png') end
    if uv and id then
        -- Fit measured atlas cells without stretching the artwork.
        local ratio = item_id and 1 or ((uv[3]-uv[1])*art.width)/((uv[4]-uv[2])*art.height)
        local w,h = size,size
        if ratio > 1 then h=size/ratio else w=size*ratio end
        image_region(imgui,id,uv,x+(size-w)/2,y+(size-h)/2,w,h,1)
    elseif draw.AddRect then
        draw:AddRect({x+3,y+3},{x+size-3,y+size-3},color_u32(imgui,skin.colors.border),3)
    end
    return true
end

-- Match TextWrapped at the current font size, including scaled headings.
function skin.text_height(imgui, text, width, factor)
    factor = factor or 1
    width = math.max(1, width / factor)
    if imgui.CalcTextSize then
        local _, height = imgui.CalcTextSize(tostring(text or ''), false, width)
        if tonumber(height) then return height * factor end
    end
    local size = imgui.GetFontSize and imgui.GetFontSize() or 16
    return math.max(1, math.ceil(#tostring(text or '') * size * 0.5 / width)) * size * factor
end

function skin.locations(imgui, locations, names)
    local ordered = {}
    for bag, quantity in pairs(locations or {}) do
        if quantity > 0 then ordered[#ordered+1] = bag end
    end
    table.sort(ordered)
    for _, bag in ipairs(ordered) do
        imgui.TextWrapped((names[bag] or 'Bag') .. ': ' .. tostring(locations[bag]))
    end
end

-- Repaint only the native button's measured rectangle; its ID, hit target,
-- disabled handling and keyboard navigation remain owned by ImGui.
function skin.button_finish(imgui, label, active, disabled)
    if not imgui.GetItemRectMin or not imgui.GetItemRectMax then return end
    local draw = imgui.GetWindowDrawList and imgui.GetWindowDrawList()
    if not draw then return end
    local x,y = imgui.GetItemRectMin()
    local right,bottom = imgui.GetItemRectMax()
    if not tonumber(x) or not tonumber(y) or not tonumber(right) or not tonumber(bottom) then return end
    local hovered = not disabled and imgui.IsItemHovered and imgui.IsItemHovered() == true
    local focused = not disabled and imgui.IsItemFocused and imgui.IsItemFocused() == true
    local response = hover_amount(imgui, 'button:' .. tostring(label or ''), hovered, disabled)
    local material_alpha = disabled and 0.12
        or (active and 0.36 or 0.32) + 0.12 * response
    local textured = skin.material(imgui,'button',x+1,y+1,right-x-2,bottom-y-2,material_alpha)
    if textured and draw.AddText and imgui.CalcTextSize then
        local text = tostring(label):gsub('##.*$','')
        local tw,th = imgui.CalcTextSize(text)
        if tonumber(tw) and tonumber(th) then
            draw:AddText({x+(right-x-tw)/2,y+(bottom-y-th)/2},color_u32(imgui,disabled and skin.colors.muted or skin.colors.text),text)
        end
    end
    if draw.AddRect and (active or focused or hovered) then
        local accent = active or focused
        local outline_alpha = accent and 0.9 or (0.28 + 0.40 * response)
        local inner_alpha = accent and 0 or (0.06 + 0.18 * response)
        interaction_rim(imgui,draw,x,y,right,bottom,outline_alpha,inner_alpha,4)
    end
end

-- Inputs and selectors keep their native text/editing behavior. A light texture
-- wash and the same single-settle response tie them into the button materials.
function skin.control_finish(imgui, selected, disabled, id)
    if not imgui.GetItemRectMin or not imgui.GetItemRectMax then return false end
    local draw = imgui.GetWindowDrawList and imgui.GetWindowDrawList()
    if not draw then return false end
    local x,y = imgui.GetItemRectMin()
    local right,bottom = imgui.GetItemRectMax()
    if not tonumber(x) or not tonumber(y) or not tonumber(right) or not tonumber(bottom) then return false end
    local hovered = not disabled and imgui.IsItemHovered and imgui.IsItemHovered() == true
    local focused = not disabled and imgui.IsItemFocused and imgui.IsItemFocused() == true
    local response = hover_amount(imgui, id and ('control:' .. tostring(id)) or nil, hovered, disabled)
    local alpha = disabled and 0.04 or (selected and 0.12 or 0.075) + 0.055 * response
    skin.material(imgui,'button',x+1,y+1,right-x-2,bottom-y-2,alpha)
    if draw.AddRect and (selected or focused or hovered) then
        local accent = selected or focused
        local outline_alpha = accent and 0.82 or (0.24 + 0.34 * response)
        local inner_alpha = accent and 0 or (0.035 + 0.11 * response)
        interaction_rim(imgui,draw,x,y,right,bottom,outline_alpha,inner_alpha,4)
    end
    return true
end

local function draw_heading(imgui, text, color)
    local colored = color and imgui.PushStyleColor and imgui.PopStyleColor and ImGuiCol_Text ~= nil
    if colored then imgui.PushStyleColor(ImGuiCol_Text, color) end
    if imgui.TextWrapped ~= nil then
        imgui.TextWrapped(tostring(text or ""))
    elseif imgui.TextUnformatted ~= nil then
        imgui.TextUnformatted(tostring(text or ""))
    elseif imgui.TextColored ~= nil then
        imgui.TextColored(color or skin.colors.text, tostring(text or ""))
    else
        imgui.Text(tostring(text or ""))
    end
    if colored then imgui.PopStyleColor() end
end

function skin.heading(imgui, text, factor, color)
    factor = math.max(0.8, math.min(1.8, tonumber(factor) or 1.15))
    local pushed = false
    local manager = AshitaCore and AshitaCore.GetPluginManager and AshitaCore:GetPluginManager()
    local addons_plugin = manager and manager.Get and manager:Get('addons')
    local interface_version = addons_plugin and addons_plugin.GetInterfaceVersion
        and tonumber(addons_plugin:GetInterfaceVersion()) or 0
    if factor ~= 1 and interface_version >= 4.3 and imgui.GetFont ~= nil and imgui.GetFontSize ~= nil and imgui.PushFont ~= nil and imgui.PopFont ~= nil then
        local font = imgui.GetFont()
        local size = tonumber(imgui.GetFontSize())
        if font ~= nil and size ~= nil then
            imgui.PushFont(font, size * factor)
            pushed = true
        end
    end
    if pushed then
        draw_heading(imgui, text, color)
        imgui.PopFont()
        return
    end
    local scaled = false
    if factor ~= 1 and imgui.SetWindowFontScale ~= nil then
        imgui.SetWindowFontScale(factor)
        scaled = true
    end
    draw_heading(imgui, text, color)
    if scaled then imgui.SetWindowFontScale(1.0) end
end

local switch_motion = {}

function skin.toggle(imgui, id, value, disabled, scale)
    scale = math.max(0.75, tonumber(scale) or 1)
    value = value == true
    local width, height = 96 * scale, 34 * scale
    -- Keep keyboard focus when the visible state label changes.
    local label = (value and "ON" or "OFF") .. "###" .. tostring(id)
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil
    local has_draw = draw ~= nil and draw.AddRectFilled ~= nil and draw.AddCircleFilled ~= nil
        and draw.AddText ~= nil and imgui.GetItemRectMin ~= nil and imgui.GetItemRectMax ~= nil
        and imgui.GetColorU32 ~= nil
    local pushed = 0
    if has_draw and imgui.PushStyleColor ~= nil and imgui.PopStyleColor ~= nil and ImGuiCol_Button ~= nil then
        imgui.PushStyleColor(ImGuiCol_Button, skin.colors.transparent); pushed = pushed + 1
        if ImGuiCol_ButtonHovered ~= nil then imgui.PushStyleColor(ImGuiCol_ButtonHovered, skin.colors.transparent); pushed = pushed + 1 end
        if ImGuiCol_ButtonActive ~= nil then imgui.PushStyleColor(ImGuiCol_ButtonActive, skin.colors.transparent); pushed = pushed + 1 end
        if ImGuiCol_Text ~= nil then imgui.PushStyleColor(ImGuiCol_Text, skin.colors.transparent); pushed = pushed + 1 end
    end
    local began_disabled = disabled == true and imgui.BeginDisabled ~= nil and imgui.EndDisabled ~= nil
    if began_disabled then imgui.BeginDisabled(true) end
    local clicked = imgui.Button(label, { width, height }) == true
    if began_disabled then imgui.EndDisabled() end
    if has_draw and imgui.PushStyleColor ~= nil and imgui.PopStyleColor ~= nil and ImGuiCol_Button ~= nil and pushed > 0 then
        imgui.PopStyleColor(pushed)
    end

    if has_draw then
        local min_x, min_y = imgui.GetItemRectMin()
        local max_x, max_y = imgui.GetItemRectMax()
        local x, y = tonumber(min_x), tonumber(min_y)
        local right, bottom = tonumber(max_x), tonumber(max_y)
        if x ~= nil and y ~= nil and right ~= nil and bottom ~= nil then
            local track_w, track_x = 32 * scale, x + 5 * scale
            local track_y = y + (bottom - y - 18 * scale) * 0.5
            local hovered = not disabled and imgui.IsItemHovered and imgui.IsItemHovered() == true
            local focused = not disabled and imgui.IsItemFocused and imgui.IsItemFocused() == true
            local response = hover_amount(imgui, 'toggle:' .. tostring(id), hovered, disabled)
            local now = animation_time(imgui)
            local track_base = disabled and skin.colors.border or value and skin.colors.blue or skin.colors.surface
            local track = hovered and mix_color(track_base, skin.colors.blue_hover, response) or track_base
            local knob_color = disabled and skin.colors.muted or skin.colors.text
            skin.material(imgui,'button',x+1,y+1,right-x-2,bottom-y-2,0.6)
            draw:AddRectFilled({ track_x, track_y }, { track_x + track_w, track_y + 18 * scale }, color_u32(imgui, track), 9 * scale)
            local position = value and 1 or 0
            if now then
                local motion = switch_motion[id]
                if not motion then
                    motion = { target=position, from=position, value=position, started=now }
                    switch_motion[id] = motion
                elseif motion.target ~= position then
                    motion.from, motion.target, motion.started = motion.value, position, now
                end
                local elapsed = math.max(0, math.min(1, (now - motion.started) / 0.14))
                motion.value = motion.from + (motion.target - motion.from) * (1 - (1 - elapsed)^3)
                position = motion.value
            end
            local knob_x = track_x + 9 * scale + (track_w - 18 * scale) * position
            draw:AddCircleFilled({ knob_x, track_y + 9 * scale }, 6 * scale, color_u32(imgui, knob_color))
            draw:AddText({ x + 47 * scale, y + 9 * scale }, color_u32(imgui, disabled and skin.colors.muted or skin.colors.text), value and "ON" or "OFF")
            if (hovered or focused) and draw.AddRect then
                local outline_alpha = focused and 0.88 or (0.20 + 0.40 * response)
                local inner_alpha = focused and 0 or (0.035 + 0.13 * response)
                interaction_rim(imgui,draw,x,y,right,bottom,outline_alpha,inner_alpha,7*scale)
            end
        end
    end
    local next_value = value
    if clicked and not disabled then next_value = not value end
    return not disabled and clicked, next_value
end

local texture, texture_device, attempted_path, warned_texture = nil, nil, nil, false
local ffi, d3d
local backend_failed = false

local function texture_warning(message)
    if warned_texture then return end
    warned_texture = true
    if print ~= nil then print('[OddOrg UI] ' .. tostring(message)) end
end

local function release_texture()
    if texture ~= nil then
        local owned = texture
        texture = nil
        ffi.gc(owned, nil)
        owned:Release()
    end
    texture_device = nil
end

local function ensure_texture(addon_path)
    if not addon_path or addon_path == '' or backend_failed then return nil end
    local path = tostring(addon_path):gsub('[\\/]+$', '') .. '\\assets\\oddorg-seal-banner.png'
    local observed_device = false
    local ok, loaded = pcall(function()
        ffi = ffi or require('ffi')
        d3d = d3d or require('d3d8')
        local device = d3d.get_device()
        -- A temporarily absent device is not a failed asset load.
        if device == nil then return nil end
        observed_device = true
        local device_id = tonumber(ffi.cast('uint32_t', device))
        if attempted_path == path and texture_device == device_id then return texture end
        release_texture()
        attempted_path, texture_device = path, device_id
        ffi.cdef[[ HRESULT __stdcall D3DXCreateTextureFromFileA(IDirect3DDevice8* pDevice, const char* pSrcFile, IDirect3DTexture8** ppTexture); ]]
        local out = ffi.new('IDirect3DTexture8*[1]')
        local hr = ffi.C.D3DXCreateTextureFromFileA(device, path, out)
        if hr ~= ffi.C.S_OK then error(('texture load failed (%08X)'):format(tonumber(hr))) end
        local result = ffi.new('IDirect3DTexture8*', out[0])
        d3d.gc_safe_release(result)
        texture = result
        return result
    end)
    if not ok then
        backend_failed = not observed_device
        texture_warning(loaded)
        return nil
    end
    return loaded
end

function skin.release()
    textures.release()
    release_texture()
    attempted_path = nil
    warned_texture = false
    backend_failed = false
    switch_motion = {}
    hover_motion, hover_motion_order = {}, 0
end

function skin.home_header(imgui, width, character, status, scale, settings_button)
    local inset, gap = 18 * scale, 12 * scale
    local button_width = 104 * scale
    local text_width = math.max(1,width-inset*2)
    local name_factor = 0.85 * 1.5
    local text_y = 10 + skin.text_height(imgui,character,text_width,name_factor) + 8
    local text_bottom = text_y + skin.text_height(imgui,status.label,text_width)
    if status.context ~= '' then text_bottom = text_bottom + 3 + skin.text_height(imgui,status.context,text_width) end
    local button_height = 34 * scale
    local button_y = text_bottom + 8 * scale
    local height = math.ceil(button_y+button_height+7)
    local clicked = false
    if imgui.BeginChild('oddorg_art_header',{width,height},true) then
        skin.panel(imgui,'panel',0.14)
        local spacing = imgui.PushStyleVar and imgui.PopStyleVar and ImGuiStyleVar_ItemSpacing ~= nil
        if spacing then imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing,{gap,3}) end
        local wrap = imgui.PushTextWrapPos and imgui.PopTextWrapPos
        if imgui.SetCursorPos then imgui.SetCursorPos({inset,10}) end
        if wrap then imgui.PushTextWrapPos(inset+text_width) end
        skin.heading(imgui,character,name_factor,status.automation_active and skin.colors.active or skin.colors.gold)
        if imgui.SetCursorPos then imgui.SetCursorPos({inset,text_y}) end
        draw_heading(imgui,status.label,status.color)
        if status.context ~= '' then draw_heading(imgui,status.context,status.context_color) end
        if wrap then imgui.PopTextWrapPos() end
        if imgui.SetCursorPos then imgui.SetCursorPos({inset,button_y}) end
        clicked = settings_button({button_width,button_height})
        if spacing then imgui.PopStyleVar() end
    end
    imgui.EndChild()
    return clicked
end

function skin.banner(imgui, width, title, character, scale, automation_active)
    scale = math.max(0.75, tonumber(scale) or 1)
    width = math.max(1, tonumber(width) or 1)
    local inset, padding, gap = 20*scale, 10*scale, 3*scale
    local text_width = math.max(1,width-inset*2)
    local character_height = skin.text_height(imgui,character,text_width,0.85)
    local title_height = skin.text_height(imgui,title,text_width,1.3)
    local title_y = padding+character_height+gap
    local height = math.ceil(title_y+title_height+padding)
    -- This header owns its insets; inherited child padding/spacing otherwise
    -- adds to the measured content height and can create a scrollbar.
    local pushed = 0
    if imgui.PushStyleVar and imgui.PopStyleVar then
        if ImGuiStyleVar_WindowPadding then imgui.PushStyleVar(ImGuiStyleVar_WindowPadding,{0,0}); pushed=pushed+1 end
        if ImGuiStyleVar_ItemSpacing then imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing,{0,0}); pushed=pushed+1 end
    end
    local flags = (ImGuiWindowFlags_NoScrollbar or 0) + (ImGuiWindowFlags_NoScrollWithMouse or 0)
    if imgui.BeginChild('oddorg_art_header', { width, height }, true, flags) then
        skin.panel(imgui,'panel',0.14)
        local draw = imgui.GetWindowDrawList and imgui.GetWindowDrawList()
        if draw and draw.AddRectFilled and imgui.GetWindowPos then
            local x,y = imgui.GetWindowPos()
            draw:AddRectFilled({x+8*scale,y+padding}, {x+10*scale,y+height-padding},
                color_u32(imgui,automation_active and skin.colors.active or skin.colors.gold))
        end
        local wrap = imgui.PushTextWrapPos and imgui.PopTextWrapPos
        if wrap then imgui.PushTextWrapPos(width-inset) end
        if imgui.SetCursorPos then imgui.SetCursorPos({inset,padding}) end
        skin.heading(imgui,character,0.85,skin.colors.muted)
        if imgui.SetCursorPos then imgui.SetCursorPos({inset,title_y}) end
        skin.heading(imgui,title,1.3,skin.colors.text)
        if wrap then imgui.PopTextWrapPos() end
    end
    imgui.EndChild()
    if pushed > 0 then imgui.PopStyleVar(pushed) end
end

function skin.nav(imgui, label, selected, width, scale)
    scale = math.max(0.75, tonumber(scale) or 1)
    width = math.max(1, tonumber(width) or 160)
    local height = 48 * scale
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil
    local custom = draw ~= nil and draw.AddRectFilled ~= nil and imgui.GetItemRectMin ~= nil and imgui.GetItemRectMax ~= nil
    local pushed = 0
    if custom and imgui.PushStyleColor ~= nil and imgui.PopStyleColor ~= nil then
        if ImGuiCol_Button ~= nil then imgui.PushStyleColor(ImGuiCol_Button, selected and skin.colors.surface or skin.colors.transparent); pushed = pushed + 1 end
        if ImGuiCol_ButtonHovered ~= nil then imgui.PushStyleColor(ImGuiCol_ButtonHovered, skin.colors.surface); pushed = pushed + 1 end
        if ImGuiCol_ButtonActive ~= nil then imgui.PushStyleColor(ImGuiCol_ButtonActive, skin.colors.panel); pushed = pushed + 1 end
        if ImGuiCol_Text ~= nil then imgui.PushStyleColor(ImGuiCol_Text, selected and skin.colors.text or skin.colors.muted); pushed = pushed + 1 end
    end
    local clicked = imgui.Button(tostring(label or ''), { width, height }) == true
    if pushed > 0 then imgui.PopStyleColor(pushed) end
    skin.button_finish(imgui,label,selected,false)
    if custom then
        local min_x, min_y = imgui.GetItemRectMin()
        local max_x, max_y = imgui.GetItemRectMax()
        local x, y, right, bottom = tonumber(min_x), tonumber(min_y), tonumber(max_x), tonumber(max_y)
        if x and y and right and bottom then
            if selected then draw:AddRectFilled({ x, y }, { x + 3 * scale, bottom }, color_u32(imgui, skin.colors.blue_highlight), 2 * scale) end
        end
    end
    return clicked
end

return skin
