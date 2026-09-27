return function(t)
    local skin = require('ui_skin')

    t.test('premium heading restores fallback font scale after rendering', function()
        local calls = { scales = {}, text = nil }
        local imgui = {
            SetWindowFontScale = function(scale) calls.scales[#calls.scales + 1] = scale end,
            TextColored = function(color, text)
                assert(color == skin.colors.gold)
                calls.text = text
            end,
        }
        skin.heading(imgui, 'Automatic care', 1.2, skin.colors.gold)
        assert(calls.text == 'Automatic care')
        assert(calls.scales[1] == 1.2 and calls.scales[2] == 1,
            'heading left fallback font scale modified')
    end)

    t.test('premium heading uses the supported interface font size and balances it', function()
        local calls = { pushes = 0, pops = 0, text = nil }
        local prior_core = _G.AshitaCore
        _G.AshitaCore = {
            GetPluginManager = function()
                return { Get = function(_, name)
                    assert(name == 'addons')
                    return { GetInterfaceVersion = function() return 4.3 end }
                end }
            end,
        }
        local imgui = {
            GetFont = function() return 'body-font' end,
            GetFontSize = function() return 18 end,
            PushFont = function(font, size)
                assert(font == 'body-font' and math.abs(size - 29.7) < 0.001)
                calls.pushes = calls.pushes + 1
            end,
            PopFont = function() calls.pops = calls.pops + 1 end,
            TextWrapped = function(text) calls.text = text end,
        }
        skin.heading(imgui, 'OddOrg', 1.65, skin.colors.text)
        assert(calls.text == 'OddOrg' and calls.pushes == 1 and calls.pops == 1,
            'modern heading did not restore the font stack')
        _G.AshitaCore = prior_core
    end)

    t.test('premium toggle changes only its own value and ignores disabled clicks', function()
        local calls = { labels = {}, color_push = 0, color_pop = 0, disabled = 0, enabled = 0 }
        local imgui = {
            PushStyleColor = function() calls.color_push = calls.color_push + 1 end,
            PopStyleColor = function(count) calls.color_pop = calls.color_pop + count end,
            BeginDisabled = function() calls.disabled = calls.disabled + 1 end,
            EndDisabled = function() calls.enabled = calls.enabled + 1 end,
            Button = function(label, size)
                calls.labels[#calls.labels + 1] = label
                assert(size[1] > 0 and size[2] > 0, 'toggle has no hit target')
                return label == calls.click
            end,
        }
        local old = { _G.ImGuiCol_Button, _G.ImGuiCol_ButtonHovered, _G.ImGuiCol_ButtonActive, _G.ImGuiCol_Text }
        _G.ImGuiCol_Button, _G.ImGuiCol_ButtonHovered = 1, 2
        _G.ImGuiCol_ButtonActive, _G.ImGuiCol_Text = 3, 4

        calls.click = 'OFF###care_space_toggle'
        local changed, next_value = skin.toggle(imgui, 'care_space_toggle', false, false, 1)
        assert(changed and next_value == true)
        calls.click = 'ON###care_sort_toggle'
        changed, next_value = skin.toggle(imgui, 'care_sort_toggle', true, true, 1)
        assert(not changed and next_value == true, 'disabled toggle accepted a click')
        assert(calls.disabled == 1 and calls.enabled == 1, 'disabled region was not balanced')
        assert(calls.color_push == calls.color_pop, 'toggle left color stack unbalanced')
        assert(calls.labels[1] == 'OFF###care_space_toggle'
            and calls.labels[2] == 'ON###care_sort_toggle', 'toggle IDs or state labels changed')
        _G.ImGuiCol_Button, _G.ImGuiCol_ButtonHovered = old[1], old[2]
        _G.ImGuiCol_ButtonActive, _G.ImGuiCol_Text = old[3], old[4]
    end)

    t.test('premium toggle keeps native fallback functional without draw-list methods', function()
        local clicked = false
        local imgui = { Button = function(label)
            assert(label == 'OFF###care_deposit_toggle')
            clicked = true
            return true
        end }
        local changed, next_value = skin.toggle(imgui, 'care_deposit_toggle', false, false, 1)
        assert(clicked and changed and next_value)
    end)

    t.test('premium toggle draws the correct label and keeps its knob inside the track', function()
        local calls = { labels = {}, colors = 0, color_pops = 0, draw_text = {}, circles = {}, tracks = {} }
        local old = { _G.ImGuiCol_Button, _G.ImGuiCol_ButtonHovered, _G.ImGuiCol_ButtonActive, _G.ImGuiCol_Text }
        _G.ImGuiCol_Button, _G.ImGuiCol_ButtonHovered = 1, 2
        _G.ImGuiCol_ButtonActive, _G.ImGuiCol_Text = 3, 4
        local draw = {
            AddRectFilled = function(_, min, max) calls.tracks[#calls.tracks + 1] = { min=min, max=max } end,
            AddCircleFilled = function(_, center, radius) calls.circles[#calls.circles + 1] = { center=center, radius=radius } end,
            AddText = function(_, _, _, text) calls.draw_text[#calls.draw_text + 1] = text end,
        }
        local imgui = {
            GetWindowDrawList = function() return draw end,
            GetItemRectMin = function() return 10, 20 end,
            GetItemRectMax = function() return 106, 54 end,
            GetColorU32 = function(color) return color end,
            PushStyleColor = function() calls.colors=calls.colors+1 end,
            PopStyleColor = function(count) calls.color_pops=calls.color_pops+count end,
            BeginDisabled = function() calls.disabled=(calls.disabled or 0)+1 end,
            EndDisabled = function() calls.enabled=(calls.enabled or 0)+1 end,
            Button = function(label, size)
                calls.labels[#calls.labels + 1] = label
                assert(size[1] == 96 and size[2] == 34)
                return true
            end,
        }
        local changed, next_value = skin.toggle(imgui, 'care_space_toggle', false, false, 1)
        assert(changed and next_value and calls.draw_text[1] == 'OFF')
        local track, knob = calls.tracks[1], calls.circles[1]
        assert(knob.center[1] >= track.min[1] and knob.center[1] <= track.max[1],
            'off knob was drawn outside its track')
        changed, next_value = skin.toggle(imgui, 'care_space_toggle', true, true, 1)
        assert(not changed and next_value and calls.draw_text[2] == 'ON',
            'disabled click changed the toggle or drew the wrong state')
        track, knob = calls.tracks[2], calls.circles[2]
        assert(knob.center[1] >= track.min[1] and knob.center[1] <= track.max[1],
            'on knob was drawn outside its track')
        assert(calls.labels[1] == 'OFF###care_space_toggle' and calls.labels[2] == 'ON###care_space_toggle')
        assert(calls.colors == calls.color_pops and calls.disabled == 1 and calls.enabled == 1,
            'toggle left style or disabled state unbalanced')
        _G.ImGuiCol_Button, _G.ImGuiCol_ButtonHovered = old[1], old[2]
        _G.ImGuiCol_ButtonActive, _G.ImGuiCol_Text = old[3], old[4]
    end)

    t.test('settings banner is compact text-only content with a state accent', function()
        local calls = { begins = 0, ends = 0, texts = {}, accents = 0, pushed = 0, popped = 0 }
        local draw = {
            AddRectFilled = function() calls.accents = calls.accents + 1 end,
            AddImage = function() error('text-only banner must not draw artwork') end,
        }
        local imgui = {
            BeginChild = function(id, size)
                assert(id == 'oddorg_art_header' and size[1] == 320 and size[2] > 0 and size[2] < 110)
                calls.begins = calls.begins + 1
                return true
            end,
            EndChild = function() calls.ends = calls.ends + 1 end,
            GetWindowDrawList = function() return draw end,
            GetWindowPos = function() return 0, 0 end,
            SetCursorPos = function() end,
            TextWrapped = function(text) calls.texts[#calls.texts + 1] = text end,
            GetFont = function() return 'font' end,
            GetFontSize = function() return 16 end,
            PushFont = function() calls.pushed = calls.pushed + 1 end,
            PopFont = function() calls.popped = calls.popped + 1 end,
            PushStyleVar = function() calls.pushed = calls.pushed + 1 end,
            PopStyleVar = function(count) calls.popped = calls.popped + (count or 1) end,
            GetColorU32 = function(color) return color end,
        }
        local old_core = _G.AshitaCore
        _G.AshitaCore = {
            GetPluginManager = function()
                return { Get = function(_, name)
                    assert(name == 'addons')
                    return { GetInterfaceVersion = function() return 4.3 end }
                end }
            end,
        }
        skin.banner(imgui, 320, 'Automatic care', 'Offline', 1, true)
        assert(calls.begins == 1 and calls.ends == 1, 'banner left its child window unbalanced')
        assert(calls.texts[1] == 'Offline' and calls.texts[2] == 'Automatic care',
            'banner did not preserve the character and tab hierarchy')
        assert(calls.accents == 1, 'enabled care did not draw the state accent')
        assert(calls.pushed == calls.popped, 'banner left font or style state unbalanced')
        skin.release()
        _G.AshitaCore = old_core
    end)

    t.test('premium sidebar navigation preserves its stable section ID and bounded hit area', function()
        local requested, button_size = nil, nil
        local imgui = {
            Button = function(label, size)
                requested, button_size = label, size
                return true
            end,
        }
        assert(skin.nav(imgui, 'Automatic care##settings_auto', true, 190, 1.25, 1))
        assert(requested == 'Automatic care##settings_auto')
        assert(button_size[1] == 190 and button_size[2] == 60)
    end)

end
