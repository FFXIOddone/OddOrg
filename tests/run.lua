-- Run from the repository root with LuaJIT. No Ashita DLLs or game access.
package.path = "./addons/oddorg/?.lua;" .. package.path
local real_print, messages = print, {}
print = function(value) messages[#messages + 1] = tostring(value) end
local callbacks, settings_callback = {}, nil
local bags, capacities, selected_target = {}, {}, 7
local sent_moves, sent_trades, packet_access = {}, {}, 0
local clock = 100
os.time = function() return clock end
os.clock = function() return clock end
local function clone(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, entry in pairs(value) do copy[key] = clone(entry) end
    return copy
end
local settings = { name="Offline", server_id=42, logged_in=true }
local preferences, saved = { keep={}, sort_enabled=false, deposit_enabled=false, background={enabled=false,free_slots=5,items={}} }, { keep={}, sort_enabled=false, deposit_enabled=false, background={enabled=false,free_slots=5,items={}} }
local save_works = true
settings.load = function() return preferences end
settings.register = function(_, _, callback) settings_callback = callback end
settings.save = function() if save_works then saved = clone(preferences) end; return true end
settings.reload = function()
    preferences = clone(saved)
    settings_callback(preferences)
    return true
end
package.preload.common = function() _G.T = function(value) return value end; return {} end
package.preload.settings = function() return settings end
package.preload.chat = function()
    return { header=function() return "" end, message=tostring, error=tostring }
end
package.preload.imgui = function() error("Offline: no native UI") end
ashita = { events={ register=function(event, _, callback) callbacks[event] = callback end } }
addon = {}
local resources_by_id = {
    [4096]={ Name={"Fire Crystal"}, StackSize=12 },
    [4097]={ Name={"Ice Crystal"}, StackSize=12 },
    [4098]={ Name={"Wind Crystal"}, StackSize=12 },
    [4104]={ Name={"Fire Cluster"}, StackSize=12 },
    [4106]={ Name={"Wind Cluster"}, StackSize=12 },
    [900]={ Name={"Quest Keepsake"}, StackSize=1 },
    [901]={ Name={"Copper Ore"}, StackSize=12 },
    [902]={ Name={"Echo Drops"}, StackSize=12 },
    [903]={ Name={"Goblin Armor"}, StackSize=12 },
    [100]={ Name={"Sword A"}, Type=4, Slots=1, StackSize=1 },
    [101]={ Name={"Sword B"}, Type=4, Slots=1, StackSize=1 },
    [102]={ Name={"Ring A"}, Type=5, Slots=0x2000, StackSize=1 },
    [103]={ Name={"Ring B"}, Type=5, Slots=0x2000, StackSize=1 },
}
local resources = { GetItemById=function(_, id) return resources_by_id[id] end }
local player_state = { zoning=0, status=0, zone=100, x=0, y=0, z=0 }
local party = {
    GetMemberIsActive=function() return 1 end,
    GetMemberName=function() return settings.name end,
    GetMemberServerId=function() return settings.server_id end,
    GetMemberZone=function() return player_state.zone end,
    GetMemberTargetIndex=function() return 1 end,
    GetMemberHP=function() return 100 end,
    GetMemberHPPercent=function() return 100 end,
}
local inventory_counter, unstable_counter, inventory_update_flags = 1, false, 0x3FFFF
local inv = {
    GetContainerCountMax=function(_, bag) return capacities[bag] or 0 end,
    GetContainerItem=function(_, bag, slot) return (bags[bag] or {})[slot] end,
    GetEquippedItem=function() return { Index=0 } end,
    GetContainerUpdateCounter=function()
        if unstable_counter then inventory_counter = inventory_counter + 1 end
        return inventory_counter
    end,
    GetContainerUpdateFlags=function() return inventory_update_flags end,
}
local npc = { name="Ephemeral Moogle", id=1007, distance=4 }
local entity = {
    GetName=function(_, index) return index == 7 and npc.name or (index == 1 and settings.name or "") end,
    GetServerId=function(_, index) return index == 7 and npc.id or (index == 1 and settings.server_id or 0) end,
    GetDistance=function(_, index) return index == 7 and npc.distance or nil end,
    GetStatus=function(_, index) return index == 1 and player_state.status or 0 end,
    GetEntityMapSize=function() return 8 end,
    GetZoneId=function() return player_state.zone end,
    GetLocalPositionX=function(_, index) return index == 7 and math.sqrt(npc.distance) or player_state.x end,
    GetLocalPositionY=function() return player_state.y end,
    GetLocalPositionZ=function() return player_state.z end,
    GetMoveDeltaX=function() return 0 end,
    GetMoveDeltaY=function() return 0 end,
    GetMoveDeltaZ=function() return 0 end,
}
local memory = {
    GetInventory=function() return inv end, GetParty=function() return party end,
    GetEntity=function() return entity end,
    GetPlayer=function() return { GetIsZoning=function() return player_state.zoning end } end,
    GetTarget=function() return {
        GetIsSubTargetActive=function() return 0 end,
        GetTargetIndex=function() return selected_target end,
    } end,
}
AshitaCore = {
    GetInstallPath=function() return ".\\tests\\not-an-install\\" end,
    GetMemoryManager=function() return memory end,
    GetResourceManager=function() return resources end,
    GetPacketManager=function() packet_access=packet_access+1; error("Real packet transport forbidden") end,
}
assert(loadfile("addons/oddorg/oddorg.lua"))()

-- Access existing local functions through captured callbacks, without test hooks
-- or a production API added solely for tests.
local function locate(wanted)
    local seen = {}
    local function visit(fn)
        if seen[fn] then return end
        seen[fn] = true
        for index=1, 200 do
            local name, value = debug.getupvalue(fn, index)
            if not name then break end
            if name == wanted then return fn, index, value end
            if type(value) == "function" then
                local owner, slot, result = visit(value)
                if owner then return owner, slot, result end
            end
        end
    end
    for _, callback in pairs(callbacks) do
        local owner, slot, result = visit(callback)
        if owner then return owner, slot, result end
    end
    error("Missing local: " .. wanted)
end
local function get(name) local _, _, value = locate(name); return value end
local function replace(name, fn)
    if name == 'imgui' and type(fn) == 'table' then
        local cursor = {0, 0}
        fn.GetCursorPos = fn.GetCursorPos or function() return cursor[1], cursor[2] end
        fn.SetCursorPos = fn.SetCursorPos or function(value) cursor = value end
        fn.GetFrameHeight = fn.GetFrameHeight or function() return 32 end
        fn.Separator = fn.Separator or function() end
    end
    local owner, index = locate(name); debug.setupvalue(owner, index, fn)
end
replace("send_move_packet", function(move) sent_moves[#sent_moves+1] = clone(move) end)
replace("send_ephemeral_trade_packet", function(target, entries)
    sent_trades[#sent_trades+1] = { target=clone(target), entries=clone(entries) }
end)
local function put(bag, slot, id, count, flags)
    bags[bag] = bags[bag] or {}
    bags[bag][slot] = id and { Id=id, Count=count, Flags=flags or 0 } or nil
end
local function reset(keep)
    bags, capacities = {}, { [0]=4, [1]=8, [4]=8, [5]=8, [6]=8, [7]=8, [8]=2, [10]=2 }
    preferences = { keep=keep or {}, sort_enabled=false, deposit_enabled=false, background={enabled=false,free_slots=5,items={}} }; saved=clone(preferences); save_works=true
    settings.name, settings.server_id, settings.logged_in = "Offline", 42, true
    settings_callback(preferences)
    sent_moves, sent_trades, messages = {}, {}, {}
    selected_target, npc.id, npc.distance, npc.name = 7, 1007, 4, "Ephemeral Moogle"
    player_state.zoning, player_state.status, player_state.zone = 0, 0, 100
    player_state.x, player_state.y, player_state.z, inventory_counter, unstable_counter, inventory_update_flags = 0, 0, 0, inventory_counter + 1, false, 0x3FFFF
    clock = clock + 100
    local ok, auto = pcall(get, "automatic")
    if ok then
        auto.pending, auto.manual_pending, auto.holds, auto.hold_counts, auto.owner, auto.paused = nil, nil, {}, {}, nil, false
        auto.next_check, auto.ready_character, auto.ready_zone = 0, nil, nil
        auto.freed, auto.notice_key, auto.status = 0, nil, nil
    end
    local moogle_ok, moogle_state = pcall(get, "moogle")
    if moogle_ok then moogle_state.pass, moogle_state.next_check = nil, 0 end
    local ui_ok, ui_state = pcall(get, "ui")
    if ui_ok then ui_state.visible, ui_state.notice = false, nil end
end
local cases = 0
local function test(name, fn)
    local filter = os.getenv('ODDORG_TEST_FILTER')
    if filter and not name:find(filter, 1, true) then return end
    reset()
    fn()
    cases = cases + 1
    real_print("PASS " .. name)
end
local rules = require("keep_rules")
local function snapshot() return assert(get("collect_live_items")()) end
local function options(scope) return { scope=scope or "all", character_slug="Offline_42" } end

test("reserves Inventory first, then stored shortfall; all protects every copy", function()
    local items = {
        {container_id=5,index=1,item_id=4096,quantity=12},
        {container_id=0,index=2,item_id=4096,quantity=12},
        {container_id=0,index=1,item_id=4096,quantity=12},
    }
    local reserved = assert(rules.allocate(items, { ["4096"]=30 }))
    assert(reserved["0:1"] == 12 and reserved["0:2"] == 12 and reserved["5:1"] == 6)
    reserved = assert(rules.allocate(items, { ["4096"]="all" }))
    assert(reserved["5:1"] == 12)
    assert(not rules.validate({ ["4096"]=-1 }))
    assert(not rules.validate({ ["4096"]=0/0 }))
    assert(not rules.validate({ [4096]=12 }))
end)

test("quest keep-all and partial crafting reserve survive sorting", function()
    reset({ ["900"]="all", ["901"]=5 })
    put(0,1,900,1); put(0,2,901,12)
    local state = snapshot()
    local plan = assert(get("build_organize_plan")(state, options("storage")))
    assert(plan.kept_quantity == 6)
    assert(#plan.logical_moves == 1 and plan.logical_moves[1].quantity == 7)
    local queue = assert(get("build_physical_queue")(plan.logical_moves, state))
    assert(#queue == 1 and queue[1].quantity == 7)
    assert(get("validate_move")(queue[1]))
    queue[1].quantity = 8
    assert(not get("validate_move")(queue[1]))
end)

test("storage scope ignores unrelated wardrobe capacity", function()
    capacities[8], capacities[10] = 1, 0
    put(8,1,100,1); put(1,1,101,1); put(1,2,902,1)
    local plan = assert(get("build_organize_plan")(snapshot(), options("storage")))
    assert(#plan.logical_moves == 1 and plan.logical_moves[1].item_id == 902)
end)

test("partial reserved stack never manufactures a free staging slot", function()
    reset({ ["901"]=5 })
    capacities[0]=1
    put(0,1,901,12); put(1,1,902,1)
    local state = snapshot()
    local plan = assert(get("build_organize_plan")(state, options("storage")))
    -- Force an incoming move after the partial outgoing move to exercise the
    -- physical scheduler independently of the planner's overflow destination.
    plan.logical_moves[#plan.logical_moves + 1] = {
        move_id="incoming", character_slug="Offline_42", item_id=902, quantity=1,
        item_name="Echo Drops", source_container_id=1, source_index=1,
        target_container_id=0, stack_size=12,
    }
    local queue, err = get("build_physical_queue")(plan.logical_moves, state)
    assert(queue == nil and err:find("no menu%-flow move"))
end)

test("deposit preview excludes reserves and locked stacks, stages incrementally", function()
    reset({ ["4096"]=18 })
    put(0,1,4096,12); put(5,1,4096,12); put(5,2,4097,12); put(0,2,4104,1,1)
    local queue, summary = get("build_ephemeral_dump_queue")(options())
    assert(queue and summary.kept_quantity == 18 and summary.skipped_locked == 1)
    assert(#queue == 4 and queue[1].kind == "stage" and queue[2].kind == "trade")
    assert(queue[3].kind == "stage" and queue[4].kind == "trade")
    assert(queue[1].quantity == 6)
end)

test("a crystal batch cannot consume a reserve across multiple stacks", function()
    reset({ ["4096"]=12 })
    put(0,1,4096,12); put(0,2,4096,12)
    local eph = get("ephemeral")
    local function trade(index)
        return {kind="trade",move_id=tostring(index),character_slug="Offline_42",item_id=4096,
            item_name="Fire Crystal",source_index=index,source_container_id=0,quantity=12,units=12}
    end
    eph.queue = { trade(1), trade(2) }
    assert(get("build_ephemeral_trade_batch")(1) == nil)
    preferences.keep = {}
    eph.queue = { trade(1), trade(1) }
    assert(get("build_ephemeral_trade_batch")(1) == nil)
end)

test("keeps the selected Moogle across batches and rejects identity drift", function()
    local target = assert(get("validate_ephemeral_target")())
    local eph = get("ephemeral")
    eph.target, eph.running = target, true
    selected_target = 0
    assert(get("validate_ephemeral_target")().server_id == 1007)
    npc.id = 1008
    assert(get("validate_ephemeral_target")() == nil)
    npc.id, npc.distance = 1007, nil
    assert(get("validate_ephemeral_target")() == nil)
end)

test("rule changes persist, stop queues, and isolate another character", function()
    get("organizer").running = true
    assert(get("set_keep_rule")(4096, 24))
    assert(saved.keep["4096"] == 24 and not get("organizer").running)
    settings.name, settings.server_id = "Alt", 43
    preferences = { keep={} }; settings_callback(preferences)
    assert(get("current_keep_rules")()["4096"] == nil)
end)

test("failed persistence is reported and retains session protection", function()
    save_works = false
    assert(not get("set_keep_rule")(4096, "all"))
    assert(get("current_keep_rules")()["4096"] == "all")
    assert(get("ui").notice:find("could not be saved",1,true))
end)

test("changing a rule cannot start a second deposit over the pending one", function()
    put(0,1,4096,12); put(0,2,4096,12)
    get("handle_ephemeral")({"/oddorg","ephemeral","dump","inventory"})
    get("run_ephemeral_tick")()
    assert(#sent_trades == 1)
    assert(get("set_keep_rule")(4096,12))
    get("handle_ephemeral")({"/oddorg","ephemeral","dump","inventory"})
    assert(not get("ephemeral").running and #sent_trades == 1)
    assert(messages[#messages]:find("still settling",1,true))
end)

test("advanced moves honor protections and use the same single active queue", function()
    reset({ ["900"]="all" })
    put(0,1,900,1)
    local args = {"/oddorg","move","manual","Offline_42","900","1","0","1","1","Quest Keepsake"}
    get("handle_move")(args)
    assert(not get("organizer").running and #sent_moves == 0)
    preferences.keep = {}
    get("handle_move")(args)
    assert(get("organizer").running and #sent_moves == 0)
    get("handle_move")(args)
    get("run_organizer_tick")()
    assert(#sent_moves == 1 and get("organizer").awaiting_move)
end)

test("equipped gear is rejected by direct moves and rechecked before queued dispatch", function()
    put(8,1,100,1)
    local original = inv.GetEquippedItem
    inv.GetEquippedItem = function(_, slot) return {Index=slot == 0 and 0x0801 or 0} end
    get('handle_move')({'/oddorg','move','manual','Offline_42','100','1','8','1','0','Sword A'})
    assert(not get('organizer').running and #sent_moves == 0)
    inv.GetEquippedItem = original
    reset()
    put(0,1,100,1)
    get('handle_organize')({'/oddorg','organize','run','wardrobes'})
    assert(get('organizer').running and #get('organizer').queue > 0)
    inv.GetEquippedItem = function(_, slot) return {Index=slot == 0 and 1 or 0} end
    get('run_organizer_tick')()
    inv.GetEquippedItem = original
    assert(not get('organizer').running and #sent_moves == 0)
    assert(get('organizer').error == 'source item is currently equipped')
end)

test("unreadable equipment blocks gear dispatch but explicit equipped opt-in remains supported", function()
    put(0,1,100,1)
    local original = inv.GetEquippedItem
    get('handle_organize')({'/oddorg','organize','run','wardrobes'})
    inv.GetEquippedItem = function() return nil end
    get('run_organizer_tick')()
    assert(not get('organizer').running and #sent_moves == 0)
    inv.GetEquippedItem = function(_, slot) return {Index=slot == 0 and 1 or 0} end
    get('handle_organize')({'/oddorg','organize','run','wardrobes','equipped'})
    get('run_organizer_tick')()
    inv.GetEquippedItem = original
    assert(#sent_moves == 1, 'explicit advanced equipped option was lost')
end)

test("organization waits for the transfer and stops on unconfirmed movement", function()
    put(0,1,901,12)
    get("handle_organize")({"/oddorg","organize","run","storage"})
    local org = get("organizer")
    assert(org.running)
    get("run_organizer_tick")()
    assert(#sent_moves == 1 and org.cursor == 1 and org.running)
    get("run_organizer_tick")()
    assert(#sent_moves == 1 and org.running)
    clock=clock+6
    get("run_organizer_tick")()
    assert(not org.running and org.error:find("not confirmed",1,true))
    assert(org.error:find("Stopped at 1/",1,true) and org.error:find("Copper Ore",1,true))
    assert(org.error:find("Inventory",1,true) and #sent_moves == 1)
end)

test("organization exposes planning failure in its UI state", function()
    inventory_update_flags = 0
    get("handle_organize")({"/oddorg","organize","run","storage"})
    assert(not get("organizer").running and #sent_moves == 0)
    assert(get("organizer").error:find("Waiting for Inventory loaded bit",1,true))
end)

test("organization reports completion only after source and destination change", function()
    put(0,1,901,12)
    get("handle_organize")({"/oddorg","organize","run","storage"})
    get("run_organizer_tick")()
    local move = sent_moves[1]
    put(0,1,nil); put(move.target_container_id,1,901,12)
    get("run_organizer_tick")()
    assert(get("organizer").running, "completion skipped the confirmation quiet interval")
    clock = clock + 1
    get("run_organizer_tick")()
    assert(not get("organizer").running and messages[#messages] == "organizer complete: no remaining moves in the selected scope.")
end)

test("organization continues fresh passes and stops repeated states without false completion", function()
    local build = get('build_preview_or_queue')
    local initial = {items={{container_id=0,item_id=901,quantity=12,flags=0}}}
    local moved = {items={{container_id=5,item_id=901,quantity=12,flags=0}}}
    local plan = {snapshot=initial,logical_moves={{}},scope='storage'}
    get('start_organize_queue')({scope='storage'},plan,{{}})
    local org=get('organizer')
    org.cursor=2
    replace('build_preview_or_queue',function()
        return {snapshot=moved,logical_moves={{}},scope='storage'},{{}}
    end)
    get('run_organizer_tick')()
    assert(org.running and org.pass==2 and org.cursor==1 and org.completed_transfers==1)
    org.cursor=2; clock=clock+1
    get('run_organizer_tick')()
    assert(not org.running and org.error:find('bag state repeated',1,true))
    assert(get('ui').bulk_result==nil, 'cycle was presented as completion')
    replace('build_preview_or_queue',build)
end)

test("late confirmation starts a fresh delay before the next organization transfer", function()
    put(0,1,901,12); put(0,2,901,12)
    get("handle_organize")({"/oddorg","organize","run","storage"})
    local org = get("organizer")
    get("run_organizer_tick")()
    assert(#sent_moves == 1 and org.awaiting_move)

    local first = sent_moves[1]
    put(first.source_container_id,first.source_index,nil)
    put(first.target_container_id,1,first.item_id,first.quantity)
    clock=clock+1
    get("run_organizer_tick")()
    assert(#sent_moves == 1, "late confirmation sent the next transfer in the same tick")
    assert(org.running and org.cursor == 2 and not org.awaiting_move,
        "first transfer was not confirmed by the test fixture")

    clock=clock+0.8
    get("run_organizer_tick")()
    assert(#sent_moves == 2 and org.awaiting_move)
    local second = sent_moves[2]
    put(second.source_container_id,second.source_index,nil)
    put(second.target_container_id,2,second.item_id,second.quantity)
    get("run_organizer_tick")()
    clock=clock+1
    get("run_organizer_tick")()
    assert(not org.running and messages[#messages] == "organizer complete: no remaining moves in the selected scope.")
end)

test("manual organization completes through another bag when Safe2 reports locked space", function()
    for _, bag in ipairs({1,2,4,5,6}) do capacities[bag] = 0 end
    capacities[9], capacities[7] = 50, 2
    put(0,1,903,5)
    get("handle_organize")({"/oddorg","organize","run","storage"})
    get("run_organizer_tick")()
    assert(#sent_moves == 1 and sent_moves[1].target_container_id == 7)
    put(0,1,nil); put(7,1,903,5)
    get("run_organizer_tick")()
    clock=clock+1
    get("run_organizer_tick")()
    assert(not get("organizer").running and messages[#messages] == "organizer complete: no remaining moves in the selected scope.")
end)

test("a stored reserve does not absorb a staged organization surplus", function()
    reset({ ["901"]=18 })
    put(0,1,901,12); put(1,1,901,12)
    get("handle_organize")({"/oddorg","organize","run","storage"})
    get("run_organizer_tick")()
    assert(#sent_moves == 1 and sent_moves[1].quantity == 6)
    put(1,1,901,6); put(0,2,901,6)
    clock=clock+1
    get("run_organizer_tick")()
    assert(#sent_moves == 1)
    clock=clock+0.8
    get("run_organizer_tick")()
    assert(#sent_moves == 2 and sent_moves[2].quantity == 6)
    assert(sent_moves[2].source_index == 2)
end)

test("item controls save a reserve and crystal controls honor selected scope", function()
    put(0,1,4096,12); put(5,1,4096,12)
    local clicks, drawn, children = {}, {}, {}
    local noop = function() end
    local fake_imgui = {
        Begin=function() return true end, End=noop, SetNextWindowSize=noop,
        BeginChild=function(id) children[#children+1]=id; return true end,
        EndChild=function() assert(#children > 0); table.remove(children) end, InputText=noop,
        GetContentRegionAvail=function() return 520,480 end,
        InputInt=noop, Selectable=function() return false end,
        Checkbox=noop,
        TextWrapped=function(value) drawn[#drawn+1]=value end,
        TextUnformatted=function(value) drawn[#drawn+1]=value end,
        Button=function(label)
            if label == "Apply item settings##ignore_apply" then
                assert(children[#children] == "oddorg_item_detail", "Apply must be outside the scrolling editor")
            end
            local hit=clicks[label]; clicks[label]=nil; return hit or false
        end,
    }
    replace("imgui", fake_imgui)
    local ui = get("ui")
    ui.visible, ui.page, ui.settings_tab, ui.protections_visible = true, "settings", "ignore", true
    ui.selected_item_id, ui.scope = 4096, "all"
    get("render_ui")()
    ui.item_draft.mode, ui.item_draft.quantity[1] = "number", 5
    clicks["Apply item settings##ignore_apply"] = true
    get("render_ui")()
    assert(saved.keep["4096"] == 5)
    assert(table.concat(drawn," "):find("Reserved from moves: 5 in Inventory; 0 in other bags",1,true))
    assert(#children == 0, "item editor left an ImGui child open")
    save_works = false
    ui.item_draft.quantity[1] = 7
    clicks["Apply item settings##ignore_apply"] = true
    get("render_ui")()
    assert(ui.item_draft.save_failed and saved.keep["4096"] == 5, "failed save must keep Apply available for retry")
    save_works = true
    clicks["Apply item settings##ignore_apply"] = true
    get("render_ui")()
    assert(not ui.item_draft.save_failed and saved.keep["4096"] == 7, "retry must persist the item settings")
    ui.protections_visible, ui.page, ui.settings_tab, ui.scope = false, "settings", "bulk", "crystals"
    clicks["Inventory##crystal_scope"] = true
    clicks["Deposit surplus##oddorg_crystals_dump"] = true
    get("render_ui")()
    local eph = get("ephemeral")
    assert(eph.running and eph.scope == "inventory" and #eph.queue == 1)
    assert(eph.queue[1].quantity == 5)
    replace("imgui", nil)
end)

assert(loadfile("tests/crystal_cases.lua"))()({
    test=test, reset=reset, get=get, put=put,
    capacity=function(bag, count) capacities[bag] = count end,
    advance=function(seconds) clock = clock + seconds end,
    moves=function() return sent_moves end,
    trades=function() return sent_trades end,
    select_target=function(index) selected_target = index end,
    character=function(name, id) settings.name, settings.server_id = name, id end,
})

assert(loadfile("tests/housekeeping_cases.lua"))()({
    test=test, reset=reset, get=get, put=put,
    capacity=function(bag, count) capacities[bag] = count end,
    advance=function(seconds) clock = clock + seconds end,
    moves=function() return sent_moves end,
    preferences=function() return preferences end,
    saved=function() return saved end,
    settings_update=function(value) preferences=value; settings_callback(preferences) end,
    player=function(values) for key, value in pairs(values) do player_state[key] = value end end,
    character=function(name, id) settings.name, settings.server_id = name, id end,
    npc=function(values) for key, value in pairs(values) do npc[key] = value end end,
    select_target=function(index) selected_target = index end,
    packet=function(event) callbacks.packet_out(event) end,
    bump_inventory=function() inventory_counter = inventory_counter + 1 end,
    unstable_counter=function(value) unstable_counter = value end,
    update_flags=function(value) inventory_update_flags = value end,
})

assert(loadfile("tests/automation_cases.lua"))()({
    test=test, get=get, put=put,
    capacity=function(bag, count) capacities[bag] = count end,
    advance=function(seconds) clock = clock + seconds end,
    moves=function() return sent_moves end,
    trades=function() return sent_trades end,
    preferences=function() return preferences end,
    saved=function() return saved end,
    settings_update=function(value) preferences=value; settings_callback(preferences) end,
    update_flags=function(value) inventory_update_flags = value end,
    npc=function(values) for key,value in pairs(values) do npc[key]=value end end,
    select_target=function(index) selected_target=index end,
    packet_out=function(event) callbacks.packet_out(event) end,
    bump_inventory=function() inventory_counter = inventory_counter + 1 end,
    advance=function(seconds) clock = clock + seconds end,
    automatic_tick=function() get('automatic').tick() end,
    moogle_tick=function() get('moogle').tick() end,
    ephemeral_tick=function() get('run_ephemeral_tick')() end,
})

assert(loadfile("tests/quiet_cases.lua"))()({
    test=test, reset=reset, get=get, put=put,
    preferences=function() return preferences end,
    messages=function() return messages end,
    trades=function() return sent_trades end,
    slot=function(bag, index) return (bags[bag] or {})[index] end,
    advance=function(seconds) clock = clock + seconds end,
    npc=function(values) for key,value in pairs(values) do npc[key]=value end end,
    moogle_tick=function() get('moogle').tick() end,
    ephemeral_tick=function() get('run_ephemeral_tick')() end,
})

assert(loadfile("tests/planner_cases.lua"))()({
    test=test, reset=reset, get=get, put=put,
    capacity=function(bag, count) capacities[bag] = count end,
    preferences=function() return preferences end,
    saved=function() return saved end,
    packet_in=function(event) callbacks.packet_in(event) end,
})

assert(loadfile("tests/sorting_cases.lua"))()({
    test=test, get=get, put=put, replace=replace,
    advance=function(seconds) clock = clock + seconds end,
    moves=function() return sent_moves end,
    capacity=function(bag,count) capacities[bag]=count end,
    preferences=function() return preferences end,
    saved=function() return saved end,
    settings_update=function(value) preferences=value; settings_callback(preferences) end,
    packet_in=function(event) callbacks.packet_in(event) end,
    packet_out=function(event) callbacks.packet_out(event) end,
    organizer_tick=function() get('run_organizer_tick')() end,
    messages=function() return messages end,
    unstable_counter=function(value) unstable_counter = value end,
    update_flags=function(value) inventory_update_flags = value end,
    player=function(values) for key, value in pairs(values) do player_state[key] = value end end,
    character=function(name, id) settings.name, settings.server_id = name, id end,
})

assert(loadfile("tests/batching_cases.lua"))()({
    test=test, reset=reset, get=get, put=put,
    capacity=function(bag, count) capacities[bag] = count end,
    advance=function(seconds) clock = clock + seconds end,
    moves=function() return sent_moves end,
    trades=function() return sent_trades end,
    preferences=function() return preferences end,
    slot=function(bag, index) return (bags[bag] or {})[index] end,
    npc=function(values) for key, value in pairs(values) do npc[key] = value end end,
})

assert(loadfile("tests/item_controls_cases.lua"))()({
    test=test, reset=reset, get=get, replace=replace, put=put,
    saved=function() return saved end,
    preferences=function() return preferences end,
    settings_update=function(value) preferences=value; settings_callback(preferences) end,
    character=function(name, id) settings.name, settings.server_id = name, id end,
})

assert(loadfile("tests/automatic_controls_cases.lua"))()({
    test=test, reset=reset, get=get, replace=replace,
    preferences=function() return preferences end,
    saved=function() return saved end,
    settings_update=function(value) preferences=value; settings_callback(preferences) end,
    character=function(name, id) settings.name, settings.server_id = name, id end,
    settings=function() return settings end,
})

assert(loadfile("tests/settings_navigation_cases.lua"))()({
    test=test, reset=reset, get=get, put=put, replace=replace,
    moves=function() return sent_moves end,
    preferences=function() return preferences end,
    saved=function() return saved end,
    settings_update=function(value) preferences=value; settings_callback(preferences) end,
    character=function(name, id) settings.name, settings.server_id = name, id end,
})

assert(loadfile('tests/premium_skin_cases.lua'))()({ test=test })

assert(loadfile('tests/quicksets_cases.lua'))()({
    test=test, reset=reset, get=get, put=put, replace=replace,
    capacity=function(bag,count) capacities[bag]=count end,
    advance=function(seconds) clock=clock+seconds end,
    preferences=function() return preferences end, saved=function() return saved end,
    moves=function() return sent_moves end, messages=function() return messages end,
    settings=function() return settings end,
    character=function(name,id) settings.name,settings.server_id=name,id end,
    settings_update=function(value) preferences=value; settings_callback(preferences) end,
})

assert(loadfile('tests/quicksets_ui_cases.lua'))()({
    test=test, reset=reset, get=get, put=put, replace=replace,
    preferences=function() return preferences end, saved=function() return saved end,
    settings_update=function(value) preferences=value; settings_callback(preferences) end,
    character=function(name,id) settings.name,settings.server_id=name,id end,
})

assert(loadfile('tests/item_rules_cases.lua'))()({ test=test })

assert(packet_access == 0)
real_print(("PASS %u offline cases; zero real packet-manager accesses; no native UI or client activity"):format(cases))
