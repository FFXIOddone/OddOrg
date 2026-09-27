addon.name = "oddorg"
addon.author = "Odd"
addon.version = "1.12.0"
addon.desc = "Keep inventory space free, protect carried items, and deposit surplus crystals."

require("common")
local bit = require("bit")
local chat = require("chat")
local settings = require("settings")
local keep_rules = require("keep_rules")
local item_rules = require("item_rules")
local storage_layout = require("storage_layout")
local housekeeping = require("housekeeping")
local skin = require("ui_skin")
skin.configure(addon.path or '')
local preferences = settings.load(T{ keep = T{}, house_enabled=false, sort_enabled=false, deposit_enabled=false,
    background = T{ enabled=false, free_slots=5, items=T{} },
    storage_layout = T{ version=1, active="", sets=T{} } })
-- Preserve an enabled 1.3 preference under the new inventory-arrival workflow.
if preferences.house_enabled == true then
    preferences.sort_enabled, preferences.house_enabled = true, false
    pcall(settings.save)
end
local imgui_ok, imgui = pcall(require, "imgui")
if not imgui_ok then
    imgui = nil
end

local MOVE_PACKET_ID = 0x029
local EPHEMERAL_TRADE_PACKET_ID = 0x036
local EPHEMERAL_TRADE_BATCH_SIZE = 8
local EPHEMERAL_TRADE_ANIMATION_DELAY = 10
local EPHEMERAL_UNIT_CAP = 5000
local DESTINATION_AUTO_INDEX = 0x52
local INVENTORY_CONTAINER_ID = 0
local PROBES_ENABLED = false
local STACKING_IS_LIVE_VALIDATION_ONLY = true
local ASSUME_UNVERIFIED_OPTIONAL_CONTAINERS = false
local BAG_ACCESS_SIGNATURE = "A1????????8B88B4000000C1E907F6C101E9"
local MENU_FLOW_SUFFIXES = {
    pull = { suffix = "pull" },
    put = { suffix = "put" },
}

local CONTAINERS = {
    [0] = "Inventory",
    [1] = "Safe",
    [2] = "Storage",
    [3] = "Temporary",
    [4] = "Locker",
    [5] = "Satchel",
    [6] = "Sack",
    [7] = "Case",
    [8] = "Wardrobe",
    [9] = "Safe2",
    [10] = "Wardrobe2",
    [11] = "Wardrobe3",
    [12] = "Wardrobe4",
    [13] = "Wardrobe5",
    [14] = "Wardrobe6",
    [15] = "Wardrobe7",
    [16] = "Wardrobe8",
}

local SCANNED_CONTAINERS = { 0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }

local GEAR_ONLY_CONTAINERS = {
    [8] = true,
    [10] = true,
    [11] = true,
    [12] = true,
    [13] = true,
    [14] = true,
    [15] = true,
    [16] = true,
}

local WARDROBE_CONTAINER_IDS = {
    [8] = true,
    [10] = true,
    [11] = true,
    [12] = true,
    [13] = true,
    [14] = true,
    [15] = true,
    [16] = true,
}

local OPTIONAL_FLAGGED_CONTAINERS = {
    [11] = 0x04,
    [12] = 0x08,
    [13] = 0x10,
    [14] = 0x20,
    [15] = 0x40,
    [16] = 0x80,
}

local SOCIAL_ITEM_IDS = {
    [512] = true,
    [513] = true,
    [514] = true,
    [515] = true,
}

local SOCIAL_ITEM_NAMES = {
    linkshell = true,
    pearlsack = true,
    linkpearl = true,
}

local WARDROBE_BUCKETS = {
    { container_id = 8, label = "Wardrobe1", description = "main-only weapons", categories = { "main" } },
    { container_id = 10, label = "Wardrobe2", description = "main/sub weapons and offhands", categories = { "main_sub", "sub" } },
    { container_id = 11, label = "Wardrobe3", description = "ranged, ammo, capes, and belt utility", categories = { "range", "ammo", "back", "waist" } },
    { container_id = 12, label = "Wardrobe4", description = "head and neck armor", categories = { "head", "neck" } },
    { container_id = 13, label = "Wardrobe5", description = "body armor and first hands", categories = { "body", "hands" } },
    { container_id = 14, label = "Wardrobe6", description = "remaining hands and first legs", categories = { "hands", "legs" } },
    { container_id = 15, label = "Wardrobe7", description = "remaining legs, feet, and utility overflow", categories = { "legs", "feet", "waist", "neck", "ear", "back" } },
    { container_id = 16, label = "Wardrobe8", description = "rings and remaining earrings", categories = { "ring", "ear" } },
}

local EPHEMERAL_ITEMS = {
    [4096] = { element = "fire", kind = "crystal", unit_value = 1, name = "Fire Crystal" },
    [4097] = { element = "ice", kind = "crystal", unit_value = 1, name = "Ice Crystal" },
    [4098] = { element = "wind", kind = "crystal", unit_value = 1, name = "Wind Crystal" },
    [4099] = { element = "earth", kind = "crystal", unit_value = 1, name = "Earth Crystal" },
    [4100] = { element = "lightning", kind = "crystal", unit_value = 1, name = "Lightning Crystal" },
    [4101] = { element = "water", kind = "crystal", unit_value = 1, name = "Water Crystal" },
    [4102] = { element = "light", kind = "crystal", unit_value = 1, name = "Light Crystal" },
    [4103] = { element = "dark", kind = "crystal", unit_value = 1, name = "Dark Crystal" },
    [4104] = { element = "fire", kind = "cluster", unit_value = 12, name = "Fire Cluster" },
    [4105] = { element = "ice", kind = "cluster", unit_value = 12, name = "Ice Cluster" },
    [4106] = { element = "wind", kind = "cluster", unit_value = 12, name = "Wind Cluster" },
    [4107] = { element = "earth", kind = "cluster", unit_value = 12, name = "Earth Cluster" },
    [4108] = { element = "lightning", kind = "cluster", unit_value = 12, name = "Lightning Cluster" },
    [4109] = { element = "water", kind = "cluster", unit_value = 12, name = "Water Cluster" },
    [4110] = { element = "light", kind = "cluster", unit_value = 12, name = "Light Cluster" },
    [4111] = { element = "dark", kind = "cluster", unit_value = 12, name = "Dark Cluster" },
}

local organizer = {
    running = false,
    queue = {},
    cursor = 1,
    next_send_at = 0,
    delay = 0.8,
    inventory_wait_timeout = 5.0,
    scope = "all",
    started_at = 0,
    error = nil,
    summary = nil,
    awaiting_inventory = nil,
}

local ephemeral = {
    running = false,
    queue = {},
    cursor = 1,
    last_send = 0,
    delay = 0.8,
    inventory_wait_timeout = 5.0,
    scope = "all",
    started_at = 0,
    error = nil,
    target = nil,
    summary = nil,
    awaiting_inventory = nil,
    animation_wait_until = nil,
    animation_wait_last_probe = 0,
}

local ui = {
    visible = false,
    page = "home",
    settings_tab = "automatic",
    scope = "all",
    crystal_scope = "all",
    protections_visible = false,
    filter = { "" },
    item_draft = nil,
    item_draft_cache = {},
    selected_item_id = nil,
    notice = nil,
}

local bag_access_pointer = nil
local resource_name_matches
local collect_live_items
local settling_until = 0
local automatic = { holds={}, hold_counts={}, owner=nil, pending=nil, manual_pending=nil, paused=false, next_check=os.time() + 6,
    status="Background clearing is off.", freed=0, notice_key=nil }
local moogle = { pass=nil, next_check=0, status="Nearby deposits are off." }

local function settle_pending_actions()
    if automatic.pending then settling_until = math.max(settling_until, automatic.pending.started_at + 5) end
    local move = organizer.awaiting_move
    local stage = ephemeral.awaiting_inventory and ephemeral.awaiting_inventory.observation
    local trade = ephemeral.awaiting_trade
    if move then settling_until = math.max(settling_until, move.started_at + 5) end
    if stage then settling_until = math.max(settling_until, stage.started_at + 5) end
    for _, observation in pairs({ automatic.pending, move, stage }) do
        if observation.stack_sent_at then settling_until = math.max(settling_until, observation.stack_sent_at + 5) end
    end
    if trade then settling_until = math.max(settling_until, trade.started_at + EPHEMERAL_TRADE_ANIMATION_DELAY + 5) end
end

local function new_run_ready()
    if automatic.manual_acquisition then return false, "Manual item receipt is being confirmed; wait before starting another run." end
    if automatic.pending then return false, "Background transfer is settling; try again in a moment." end
    if automatic.manual_pending then return false, "Manual bag movement is being confirmed; wait before starting another run." end
    settle_pending_actions()
    local remaining = settling_until - os.time()
    if remaining > 0 then
        return false, ("Previous action is still settling. Check Inventory and try again in %u seconds."):format(remaining)
    end
    return true
end

local function cancel_queues(reason)
    settle_pending_actions()
    automatic.pending = nil
    for _, state in ipairs({ organizer, ephemeral }) do
        -- Saving and reloading can cancel twice. Only interrupted work earns a notice.
        if state.running or reason == nil then state.error = reason end
        state.running = false
        state.queue = {}
        state.cursor = 1
        state.awaiting_inventory = nil
        state.awaiting_move = nil
        state.awaiting_trade = nil
        state.stack_bags = nil
    end
    ephemeral.target = nil
    ephemeral.animation_wait_until = nil
    ui.preview_plan = nil
    ui.bulk_preview_ready, ui.bulk_preview_displayed = nil, nil
    ui.preview_visible = false
end

local function automation_settings_signature(source)
    local background = source.background or {}
    return table.concat({ tostring(background.enabled == true), tostring(background.free_slots or 5),
        tostring(source.sort_enabled == true), tostring(source.deposit_enabled == true) }, ":")
end

settings.register("settings", "oddorg_settings", function(updated)
    local draft = ui.automation_draft
    local owner = tostring(settings.name or "") .. "_" .. tostring(settings.server_id or 0)
    local owner_changed = automatic.owner ~= owner
    preferences = updated
    if preferences.house_enabled == true then
        preferences.sort_enabled, preferences.house_enabled = true, false
        pcall(settings.save)
    end
    local draft_matches = type(draft) == "table" and draft.owner == owner
        and draft.saved_signature ~= nil and draft.saved_signature == automation_settings_signature(preferences)
    cancel_queues("Settings updated; active work stopped. View Plan or start a new deposit to continue. No addon reload needed.")
    if owner_changed then
        automatic.house_access = nil
        automatic.manual_acquisition, automatic.moogle_menu = nil, nil
        automatic.holds, automatic.hold_counts, automatic.manual_pending, automatic.freed, automatic.notice_key = {}, {}, nil, 0, nil
        if automatic.owner ~= nil then
            automatic.paused = false
            ui.page, ui.settings_tab = "home", "automatic"
        end
        automatic.owner = owner
        automatic.ready_character, automatic.ready_zone = nil, nil
        automatic.next_check = os.time() + 6
        moogle.pass = nil
    end
    automatic.next_check = math.max(automatic.next_check, os.time() + 2)
    ui.selected_item_id = nil
    ui.item_draft = nil
    if owner_changed then ui.item_draft_cache = {} end
    ui.layout_draft = nil
    ui.bulk_quickset = nil
    ui.notice = nil
    ui.bulk_notice = nil
    ui.automatic_saved_until = nil
    ui.layout_saved_until = nil
    ui.bulk_result = nil
    ui.items_snapshot = nil
    ui.items_checked_at = nil
    ui.preview_plan = nil
    ui.bulk_preview_ready, ui.bulk_preview_displayed = nil, nil
    ui.preview_visible = false
    if not draft_matches then ui.automation_draft = nil end
end)

local function install_path()
    local path = AshitaCore:GetInstallPath()
    path = path:gsub("/", "\\")
    if not path:match("\\$") then
        path = path .. "\\"
    end
    return path
end

local function audit_path()
    return install_path() .. "config\\addons\\oddorg\\events.tsv"
end

local function probe_path()
    return install_path() .. "config\\addons\\oddorg\\probes.tsv"
end

local function plan_path()
    return install_path() .. "config\\addons\\oddorg\\last_plan.tsv"
end

local function clean_field(value)
    local cleaned = tostring(value or ""):gsub("\t", " "):gsub("\r", " "):gsub("\n", " ")
    return cleaned
end

local function write_tsv(path, fields, mode)
    local file = io.open(path, mode or "ab")
    if file == nil then
        return false
    end
    file:write(table.concat(fields, "\t"))
    file:write("\n")
    file:close()
    return true
end

local function write_audit(move_id, status, message, details)
    write_tsv(audit_path(), {
        os.date("!%Y-%m-%dT%H:%M:%SZ"),
        clean_field(move_id),
        clean_field(status),
        clean_field(message),
        clean_field(details),
    }, "ab")
end

local function write_probe(event, status, message, details)
    if not PROBES_ENABLED then
        return
    end
    write_tsv(probe_path(), {
        os.date("!%Y-%m-%dT%H:%M:%SZ"),
        clean_field(event),
        clean_field(status),
        clean_field(message),
        clean_field(details),
    }, "ab")
end

local function set_probes_enabled(enabled)
    PROBES_ENABLED = enabled and true or false
    write_probe("probe_state", "OK", PROBES_ENABLED and "enabled" or "disabled", "")
end

local function clear_probes()
    local file = io.open(probe_path(), "wb")
    if file ~= nil then
        file:close()
    end
end

local function say(message)
    print(chat.header("OddOrg") .. chat.message(message))
end

local function fail_move(move_id, message, details)
    write_audit(move_id, "REJECT", message, details)
    write_probe("validation_reject", "REJECT", message, details)
    print(chat.header("OddOrg") .. chat.error(message))
end

local function safe_call(default, fn)
    local ok, value = pcall(fn)
    if ok then
        return value
    end
    return default
end

local function table_len(value)
    local count = 0
    for _ in pairs(value or {}) do
        count = count + 1
    end
    return count
end

local function item_key(container_id, index)
    return tostring(container_id) .. ":" .. tostring(index)
end

local function contains(values, needle)
    for _, value in ipairs(values) do
        if value == needle then
            return true
        end
    end
    return false
end

local function get_player_slug()
    local party = AshitaCore:GetMemoryManager():GetParty()
    local name = "Unknown"
    local server_id = 0

    if party ~= nil and safe_call(0, function() return party:GetMemberIsActive(0) end) == 1 then
        name = safe_call(name, function() return party:GetMemberName(0) end)
        server_id = safe_call(server_id, function() return party:GetMemberServerId(0) end)
    end

    return ("%s_%u"):format(name or "Unknown", tonumber(server_id) or 0)
end

local function current_keep_rules()
    local owner = ("%s_%u"):format(settings.name or "", tonumber(settings.server_id) or 0)
    if settings.logged_in ~= true or owner ~= get_player_slug() then
        return nil, "waiting for this character's item protections"
    end
    local keep = type(preferences) == "table" and preferences.keep or nil
    local ok, err = keep_rules.validate(keep)
    if not ok then return nil, err .. "; fix the OddOrg settings before moving items" end
    return keep
end

local function get_keep_reservations(snapshot)
    local keep, err = current_keep_rules()
    if not keep then return nil, err end
    local overrides = automatic.owner == get_player_slug() and automatic.holds or {}
    if automatic.owner == get_player_slug() then
        local _, current_totals = item_rules.reconcile_overrides(overrides, snapshot.items, automatic.hold_counts)
        automatic.hold_counts = current_totals or {}
    end
    local effective, effective_err = item_rules.with_default_supplies(snapshot,keep,preferences.item_rules,
        overrides,preferences.storage_layout,preferences.background and preferences.background.free_slots or 5)
    if effective_err then return nil,effective_err end
    local reserved, reserve_err = item_rules.allocate(snapshot.items, keep, effective, overrides)
    if not reserved then return nil, reserve_err end
    local refill, refill_err = item_rules.refill_reservations(snapshot.items, reserved, effective)
    if not refill then return nil, refill_err end
    return reserved, nil, refill, effective
end

local function get_carried_surplus(item_id, carry_floor, snapshot, reserved)
    local snapshot_err, reserve_err, ignored
    if not snapshot then snapshot, ignored, snapshot_err = collect_live_items() end
    if not snapshot then return nil, snapshot_err or "inventory unavailable" end
    if not reserved then reserved, reserve_err = get_keep_reservations(snapshot) end
    if not reserved then return nil, reserve_err end
    local surplus = 0
    local carried = 0
    for _, item in ipairs(snapshot.items) do
        if item.container_id == INVENTORY_CONTAINER_ID and item.item_id == item_id then
            carried = carried + item.quantity
            if carry_floor == nil then
                local protected = tonumber(reserved[item_key(item.container_id, item.index)]) or 0
                surplus = surplus + math.max(0, item.quantity - protected)
            end
        end
    end
    if carry_floor ~= nil then
        local rule, rule_err = item_rules.for_item(preferences.item_rules, item_id)
        if rule_err then return nil, rule_err end
        local floor = math.max(tonumber(carry_floor) or 0, item_rules.carry_target(rule))
        return math.max(0, carried - floor)
    end
    return surplus
end

local function parse_int(value, field)
    local parsed = tonumber(value)
    if parsed == nil then
        return nil, field .. " must be an integer"
    end
    parsed = math.floor(parsed)
    return parsed, nil
end

local function get_container_capacity(inv, container_id)
    return safe_call(0, function() return inv:GetContainerCountMax(container_id) end) or 0
end

-- Ashita IInventory / XiPackets 0x001D: each bit marks a loaded container.
-- A quiet update counter alone does not establish that all bags have arrived.
local readiness_note, completion_note
local function inventory_readiness_problem(inv, message, detail)
    local key = message .. ":" .. tostring(detail)
    if readiness_note ~= key then
        readiness_note = key
        write_probe("inventory_readiness", "WAIT", message, tostring(detail))
    end
    return message
end

local function report_inventory_ready()
    if readiness_note then
        readiness_note = nil
        write_probe("inventory_readiness", "READY", "Required bags loaded; inventory snapshot is coherent.", "")
    end
end

local function read_inventory_counter(inv)
    local ok, value = pcall(function() return inv:GetContainerUpdateCounter() end)
    local counter = ok and tonumber(value) or nil
    if counter == nil then
        return nil, inventory_readiness_problem(inv, "Inventory update counter unavailable; see readiness probe.", tostring(value))
    end
    return counter
end

local function container_is_loaded(inv, container_id)
    local ok, value = pcall(function() return inv:GetContainerUpdateFlags() end)
    local flags = ok and tonumber(value) or nil
    if flags == nil then
        return false, inventory_readiness_problem(inv, "Loaded-bag flags unavailable; see readiness probe.", tostring(value))
    end
    if bit.band(flags, bit.lshift(1, container_id)) ~= 0 then return true end
    local message = ("Waiting for %s loaded bit (flags=0x%X)."):format(CONTAINERS[container_id], flags)
    local detail = ("bag=%u used=%s capacity=%s counter=%s"):format(container_id,
        tostring(safe_call(nil, function() return inv:GetContainerCount(container_id) end)),
        tostring(get_container_capacity(inv, container_id)), tostring(read_inventory_counter(inv)))
    return false, inventory_readiness_problem(inv, message, detail)
end

local function read_account_storage_flags()
    if ashita == nil or ashita.memory == nil then
        return nil, "ashita.memory unavailable"
    end

    if bag_access_pointer == nil then
        bag_access_pointer = safe_call(0, function()
            return ashita.memory.find("FFXiMain.dll", 0, BAG_ACCESS_SIGNATURE, 0, 0)
        end) or 0
    end
    if bag_access_pointer == 0 then
        return nil, "storage flag signature unavailable"
    end

    local base_pointer = safe_call(0, function()
        return ashita.memory.read_uint32(bag_access_pointer + 1)
    end) or 0
    if base_pointer == 0 then
        return nil, "storage flag base unavailable"
    end

    local flags_pointer = safe_call(0, function()
        return ashita.memory.read_uint32(base_pointer)
    end) or 0
    if flags_pointer == 0 then
        return nil, "storage flag pointer unavailable"
    end

    local flags = safe_call(nil, function()
        return ashita.memory.read_uint8(flags_pointer + 0xB4)
    end)
    if flags == nil then
        return nil, "storage flags unavailable"
    end

    return tonumber(flags) or 0, nil
end

-- Safe2 can report a capacity even while locked. Native local-player 0x067
-- Mode 2 carries MogExpansionFlag at 0x27; it is independent of wardrobe flags.
-- Cache this permanent unlock per character so reloading needs no extra trip.
-- Contract: XiPackets server/0x0067 and LandSandBoat packets/char_sync.cpp.
function automatic.flush_storage_access()
    local observation = automatic.safe2_observation
    if type(observation) ~= "table" then return false end
    local party = AshitaCore:GetMemoryManager():GetParty()
    local current_id = party and safe_call(0, function() return party:GetMemberServerId(0) end) or 0
    local current_index = party and safe_call(0, function() return party:GetMemberTargetIndex(0) end) or 0
    local character = get_player_slug()
    local owner = ("%s_%u"):format(settings.name or "", tonumber(settings.server_id) or 0)
    if not party or safe_call(0, function() return party:GetMemberIsActive(0) end) ~= 1
        or observation.server_id ~= current_id or observation.index ~= current_index
        or observation.character ~= character then
        automatic.safe2_observation = nil
        return false
    end
    if settings.logged_in ~= true or owner ~= character then return false end

    automatic.safe2_observation = nil
    local previous = preferences.safe2_access
    if observation.unlocked ~= true then
        -- The unlock is permanent. A later negative cannot revoke a previously
        -- confirmed positive, and negatives are not durable cache evidence.
        write_probe("storage_access", "OBSERVED",
            type(previous) == "table" and previous.character == character and previous.unlocked == true
                and "Safe2 negative ignored; permanent unlock already confirmed" or "Safe2 locked",
            character .. "; session observation")
        return true
    end
    if type(previous) == "table" and previous.character == character and previous.unlocked == true then
        return true
    end
    preferences.safe2_access = { character=character, unlocked=true }
    local ok, saved = pcall(settings.save)
    write_probe("storage_access", "OBSERVED", "Safe2 unlocked",
        character .. ((ok and saved == true) and "; cached" or "; session only: cache save failed"))
    return true
end

local function observe_storage_access(e)
    if e.id ~= 0x067 or e.injected ~= false or e.blocked == true then return end
    local data = e.data
    if type(data) ~= "string" or #data < 0x28 then return end
    local mode_length = data:byte(5) + data:byte(6) * 256
    local length = math.floor(mode_length / 64)
    if bit.band(mode_length, 0x3F) ~= 2 or length < 36 or #data < length + 4 then return end
    local index = data:byte(7) + data:byte(8) * 256
    local server_id = 0
    for position=12,9,-1 do server_id = server_id * 256 + data:byte(position) end
    local party = AshitaCore:GetMemoryManager():GetParty()
    if not party or server_id == 0 or index == 0
        or safe_call(0, function() return party:GetMemberIsActive(0) end) ~= 1
        or server_id ~= safe_call(0, function() return party:GetMemberServerId(0) end)
        or index ~= safe_call(0, function() return party:GetMemberTargetIndex(0) end) then return end
    local flag = data:byte(0x28)
    if flag ~= 0 and flag ~= 1 then return end
    automatic.safe2_observation = {
        character=get_player_slug(), server_id=server_id, index=index, unlocked=flag == 1,
    }
    automatic.flush_storage_access()
end

local function container_is_unlocked(inv, container_id, raw_capacity, account_flags, flags_err)
    raw_capacity = raw_capacity
    if raw_capacity == nil then
        raw_capacity = get_container_capacity(inv, container_id)
    end
    raw_capacity = tonumber(raw_capacity) or 0

    if raw_capacity <= 0 then
        return false, 0, "capacity unavailable"
    end

    if container_id == 9 then
        local access = preferences.safe2_access
        if type(access) ~= "table" or access.character ~= get_player_slug() or access.unlocked ~= true then
            return false, 0, "Safe2 unlock not confirmed"
        end
    end

    local required_flag = OPTIONAL_FLAGGED_CONTAINERS[container_id]
    if required_flag == nil then
        return true, raw_capacity, "capacity available"
    end

    if account_flags == nil then
        if ASSUME_UNVERIFIED_OPTIONAL_CONTAINERS then
            return true, raw_capacity, flags_err or "flags unverified but allowed"
        end
        return false, 0, flags_err or "storage flags unavailable"
    end

    if bit.band(account_flags, required_flag) == required_flag then
        return true, raw_capacity, ("flag=0x%02X flags=0x%02X"):format(required_flag, account_flags)
    end

    return false, 0, ("missing flag=0x%02X flags=0x%02X"):format(required_flag, account_flags)
end

local function collect_container_access(inv)
    local started = os.time()
    local account_flags, flags_err = read_account_storage_flags()
    local access_by_container = {}
    local details = {}
    local unlocked_count = 0
    local locked_count = 0
    local unavailable_count = 0

    for _, container_id in ipairs(SCANNED_CONTAINERS) do
        if os.time() - started >= 2 then return nil, "Storage scan took too long; movement stopped." end
        local raw_capacity = get_container_capacity(inv, container_id)
        if os.time() - started >= 2 then return nil, "Storage scan took too long; movement stopped." end
        local unlocked, effective_capacity, reason = container_is_unlocked(inv, container_id, raw_capacity, account_flags, flags_err)
        local label = CONTAINERS[container_id] or tostring(container_id)
        access_by_container[container_id] = {
            unlocked = unlocked,
            raw_capacity = raw_capacity,
            capacity = effective_capacity,
            reason = reason,
        }

        if unlocked then
            unlocked_count = unlocked_count + 1
        elseif raw_capacity > 0 then
            locked_count = locked_count + 1
        else
            unavailable_count = unavailable_count + 1
        end

        table.insert(details, ("%s=%s(%u/%u)"):format(
            label,
            unlocked and "unlocked" or "locked",
            effective_capacity,
            raw_capacity
        ))
        write_probe(
            "container_access",
            unlocked and "OK" or "SKIP",
            ("%s storage tab %s"):format(label, unlocked and "validated" or "not usable"),
            ("effective=%u raw=%u reason=%s"):format(effective_capacity, raw_capacity, reason or "")
        )
    end

    write_probe(
        "container_access_summary",
        locked_count > 0 and "WARN" or "OK",
        "storage tabs validated",
        ("unlocked=%u locked=%u unavailable=%u %s"):format(
            unlocked_count,
            locked_count,
            unavailable_count,
            table.concat(details, " ")
        )
    )
    return access_by_container
end

local function get_container_item(inv, container_id, index)
    return safe_call(nil, function() return inv:GetContainerItem(container_id, index) end)
end

local function is_real_item(item)
    return item ~= nil and item.Id ~= nil and item.Id > 0 and item.Id ~= 65535 and (tonumber(item.Count) or 0) > 0
end

local function count_used_slots(inv, container_id)
    local capacity = get_container_capacity(inv, container_id)
    local used = 0
    for index = 1, capacity, 1 do
        local item = get_container_item(inv, container_id, index)
        if is_real_item(item) then
            used = used + 1
        end
    end
    return used, capacity
end

local function first_resource_name(resource)
    if resource == nil then
        return ""
    end
    local candidates = {
        safe_call("", function() return resource.Name[1] end),
        safe_call("", function() return resource.LogNameSingular[1] end),
        safe_call("", function() return resource.LogNamePlural[1] end),
    }
    for _, name in ipairs(candidates) do
        if name ~= nil and tostring(name) ~= "" then
            return tostring(name)
        end
    end
    return ""
end

local function is_equipment(resource)
    if resource == nil then
        return false
    end
    local item_type = tonumber(resource.Type) or 0
    local slots = tonumber(resource.Slots) or 0
    return item_type == 4 or item_type == 5 or slots > 0
end

local function stack_size_for(resource)
    return tonumber(resource and (resource.StackSize or resource.Stack)) or 1
end

local function slot_name_from_mask(slots)
    slots = tonumber(slots) or 0
    local has_main = bit.band(slots, 0x0001) ~= 0
    local has_sub = bit.band(slots, 0x0002) ~= 0

    if has_main and has_sub then
        return "main_sub"
    end
    if has_main then
        return "main"
    end
    if has_sub then
        return "sub"
    end
    if bit.band(slots, 0x0004) ~= 0 then
        return "range"
    end
    if bit.band(slots, 0x0008) ~= 0 then
        return "ammo"
    end
    if bit.band(slots, 0x0010) ~= 0 then
        return "head"
    end
    if bit.band(slots, 0x0020) ~= 0 then
        return "body"
    end
    if bit.band(slots, 0x0040) ~= 0 then
        return "hands"
    end
    if bit.band(slots, 0x0080) ~= 0 then
        return "legs"
    end
    if bit.band(slots, 0x0100) ~= 0 then
        return "feet"
    end
    if bit.band(slots, 0x0200) ~= 0 then
        return "neck"
    end
    if bit.band(slots, 0x0400) ~= 0 then
        return "waist"
    end
    if bit.band(slots, 0x0800) ~= 0 or bit.band(slots, 0x1000) ~= 0 then
        return "ear"
    end
    if bit.band(slots, 0x2000) ~= 0 or bit.band(slots, 0x4000) ~= 0 then
        return "ring"
    end
    if bit.band(slots, 0x8000) ~= 0 then
        return "back"
    end
    return "other"
end

local function is_social_item(item)
    if item == nil then
        return false
    end
    local name = string.lower(tostring(item.item_name or ""))
    return SOCIAL_ITEM_IDS[tonumber(item.item_id) or 0] == true or SOCIAL_ITEM_NAMES[name] == true
end

local function can_stack_into_target(inv, resource, move)
    local stack_size = tonumber(resource and (resource.StackSize or resource.Stack)) or tonumber(move.stack_size) or 1
    if stack_size <= 1 then
        return false
    end

    -- 0x029 combines into an explicit slot only when moving the whole source
    -- stack. A split still needs a new slot, regardless of destination room.
    local source = get_container_item(inv, move.source_container_id, move.source_index)
    if not is_real_item(source) or tonumber(source.Count) ~= move.quantity then return false end
    local blocked = {}
    if organizer.running and organizer.queue[organizer.cursor] == move then
        for index=organizer.cursor + 1, #organizer.queue do
            local queued = organizer.queue[index]
            if queued.source_container_id == move.target_container_id then blocked[queued.source_index] = true end
        end
    end

    local capacity = get_container_capacity(inv, move.target_container_id)
    local best_index, best_count = false, -1
    for index = 1, capacity, 1 do
        local item = get_container_item(inv, move.target_container_id, index)
        if not blocked[index] and is_real_item(item) and tonumber(item.Id) == move.item_id
            and (tonumber(item.Flags) or 0) == 0 then
            local count = tonumber(item.Count) or 0
            if count + move.quantity <= stack_size and count > best_count then
                best_index, best_count = index, count
            end
        end
    end

    return best_index
end

local function resolve_inventory_source(inv, resources, move)
    if move.source_container_id ~= 0 or move.source_index ~= 0 then
        return true, nil
    end

    local capacity = get_container_capacity(inv, 0)
    local fallback_index = nil
    for index = 1, capacity, 1 do
        local item = get_container_item(inv, 0, index)
        if is_real_item(item) and tonumber(item.Id) == move.item_id and tonumber(item.Count) >= move.quantity then
            local resource = resources:GetItemById(item.Id)
            if resource_name_matches(resource, move.item_name) and bit.band(tonumber(item.Flags) or 0, 1) == 0 then
                if tonumber(item.Count) == move.quantity then
                    move.source_index = index
                    return true, item
                end
                fallback_index = fallback_index or index
            end
        end
    end

    if fallback_index ~= nil then
        move.source_index = fallback_index
        return true, get_container_item(inv, 0, fallback_index)
    end

    return false, nil
end

function resource_name_matches(resource, expected_name)
    local expected = string.lower(expected_name or "")
    if expected == "" or resource == nil then
        return false
    end

    local names = {
        safe_call("", function() return resource.Name[1] end),
        safe_call("", function() return resource.LogNameSingular[1] end),
        safe_call("", function() return resource.LogNamePlural[1] end),
    }

    for _, name in ipairs(names) do
        if name ~= nil and string.lower(name) == expected then
            return true
        end
    end

    return false
end

local function validate_move(move, allow_equipped)
    local validation_started = os.time()
    if move.character_slug ~= get_player_slug() then
        return false, "character mismatch", "expected=" .. move.character_slug .. " actual=" .. get_player_slug()
    end

    if CONTAINERS[move.source_container_id] == nil then
        return false, "unknown source container", tostring(move.source_container_id)
    end
    if CONTAINERS[move.target_container_id] == nil then
        return false, "unknown target container", tostring(move.target_container_id)
    end
    if move.source_container_id == move.target_container_id then
        return false, "source and target containers match", tostring(move.source_container_id)
    end
    if move.quantity <= 0 then
        return false, "quantity must be positive", tostring(move.quantity)
    end

    local inv = AshitaCore:GetMemoryManager():GetInventory()
    local resources = AshitaCore:GetResourceManager()
    if inv == nil or resources == nil then
        return false, "inventory resources unavailable", ""
    end
    if not container_is_loaded(inv, move.source_container_id) or not container_is_loaded(inv, move.target_container_id) then
        return false, "inventory is still loading; wait before moving items", ""
    end

    local account_flags, flags_err = read_account_storage_flags()
    local source_unlocked, source_capacity, source_reason = container_is_unlocked(
        inv,
        move.source_container_id,
        nil,
        account_flags,
        flags_err
    )
    local target_unlocked, target_capacity, target_reason = container_is_unlocked(
        inv,
        move.target_container_id,
        nil,
        account_flags,
        flags_err
    )
    if not source_unlocked then
        return false, "source storage tab locked", ("%s: %s"):format(CONTAINERS[move.source_container_id], source_reason or "")
    end
    if not target_unlocked then
        return false, "target storage tab locked", ("%s: %s"):format(CONTAINERS[move.target_container_id], target_reason or "")
    end
    if move.source_index < 1 or move.source_index > source_capacity then
        if move.source_container_id ~= 0 or move.source_index ~= 0 then
            return false, "source index out of range", tostring(move.source_index)
        end
    end

    local resolved, resolved_item = resolve_inventory_source(inv, resources, move)
    if not resolved then
        return false, "inventory source item not found", ("%s x%u"):format(move.item_name, move.quantity)
    end

    local item = resolved_item or get_container_item(inv, move.source_container_id, move.source_index)
    if not is_real_item(item) then
        return false, "source slot is empty", tostring(move.source_index)
    end
    if tonumber(item.Id) ~= move.item_id then
        return false, "source item id mismatch", ("expected=%u actual=%u"):format(move.item_id, tonumber(item.Id) or 0)
    end
    if tonumber(item.Count) < move.quantity then
        return false, "source quantity too small", ("expected=%u actual=%u"):format(move.quantity, tonumber(item.Count) or 0)
    end
    if bit.band(tonumber(item.Flags) or 0, 1) ~= 0 then
        return false, "source item is locked", tostring(move.source_index)
    end

    local resource = resources:GetItemById(item.Id)
    if not resource_name_matches(resource, move.item_name) then
        return false, "source item name mismatch", move.item_name
    end
    if is_equipment(resource) and not allow_equipped then
        -- Recheck at dispatch: equipment can change after the plan was built.
        for slot = 0, 15 do
            local equipped = safe_call(nil, function() return inv:GetEquippedItem(slot) end)
            local index = equipped and tonumber(equipped.Index)
            if index == nil then return false, "equipped items unavailable; wait before moving gear", "" end
            if bit.band(index, 0x00FF) == move.source_index
                and bit.band(index, 0xFF00) / 256 == move.source_container_id then
                return false, "source item is currently equipped", move.item_name
            end
        end
    end
    if GEAR_ONLY_CONTAINERS[move.target_container_id] and not is_equipment(resource) then
        return false, "target wardrobe is gear-only", move.item_name
    end

    local keep, keep_err = current_keep_rules()
    if not keep then return false, keep_err, "protections" end
    if keep[tostring(move.item_id)] == "all" then
        return false, "item protected: keep all", move.item_name
    end
    local snapshot, _, snapshot_err = collect_live_items()
    if not snapshot then return false, snapshot_err, "protections" end
    local reserved, reserve_err, refill_reserved = get_keep_reservations(snapshot)
    if not reserved then return false, reserve_err, "protections" end
    local source_key = item_key(move.source_container_id, move.source_index)
    if move.purpose == "refill" then
        if move.source_container_id == INVENTORY_CONTAINER_ID or move.target_container_id ~= INVENTORY_CONTAINER_ID
            or move.quantity > (tonumber(refill_reserved[source_key]) or 0) then
            return false, "refill source is protected or the carried shortfall changed", move.item_name
        end
    elseif move.source_container_id == INVENTORY_CONTAINER_ID
        and (move.source_index == 0 or move.carried_reserve ~= nil) then
        local surplus, surplus_err = get_carried_surplus(move.item_id, move.carried_reserve, snapshot, reserved)
        if surplus == nil or move.quantity > surplus then
            return false, surplus_err or "move would use your carried reserve", move.item_name
        end
    else
        local protected = (tonumber(reserved[source_key]) or 0) + (tonumber(refill_reserved[source_key]) or 0)
        if move.quantity > tonumber(item.Count) - protected then
            return false, move.source_container_id == INVENTORY_CONTAINER_ID
                and "move would use your carried reserve" or "move would use your stored reserve", move.item_name
        end
    end

    local used, capacity = count_used_slots(inv, move.target_container_id)
    move.target_index = can_stack_into_target(inv, resource, move) or DESTINATION_AUTO_INDEX
    if used >= capacity and move.target_index == DESTINATION_AUTO_INDEX then
        return false, "target container is full", ("%s %u/%u"):format(CONTAINERS[move.target_container_id], used, capacity)
    end

    if os.time() - validation_started >= 2 then
        return false, "storage validation took too long; movement stopped", move.item_name
    end
    return true, "validated", ("%s[%u] -> %s"):format(CONTAINERS[move.source_container_id], move.source_index, CONTAINERS[move.target_container_id])
end

local function container_item_count(container_id, item_id)
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    if not inv then return nil end
    local capacity = get_container_capacity(inv, container_id)
    if capacity <= 0 then return nil end
    local total = 0
    for index = 1, capacity do
        local item = get_container_item(inv, container_id, index)
        if is_real_item(item) and tonumber(item.Id) == item_id then
            total = total + (tonumber(item.Count) or 0)
        end
    end
    return total
end

local function capture_move_observation(move)
    local source = container_item_count(move.source_container_id, move.item_id)
    local target = container_item_count(move.target_container_id, move.item_id)
    if source == nil or target == nil then return nil, "inventory state unavailable" end
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    local slot = get_container_item(inv, move.source_container_id, move.source_index)
    if not is_real_item(slot) or tonumber(slot.Id) ~= move.item_id then
        return nil, "source slot changed before transfer"
    end
    return { move=move, source_before=source, target_before=target,
        source_slot_before=tonumber(slot.Count), started_at=os.time() }
end

-- Native Auto Sort merges partial stacks within one bag. Never infer success
-- from sending it: require unchanged quantities and consolidated partial stacks.
-- Wire layout: Windower/Lua addons/libs/packets/fields.lua, outgoing 0x03A.
function automatic.stack_snapshot(bag)
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    local resources = AshitaCore:GetResourceManager()
    if not inv or not resources or not container_is_loaded(inv, bag) then return nil end
    local flags, flags_err = read_account_storage_flags()
    local unlocked, capacity = container_is_unlocked(inv, bag, nil, flags, flags_err)
    if not unlocked then return nil end
    local snapshot = { totals={}, partials={}, eligible={}, needed=false }
    for index=1, capacity do
        local item = get_container_item(inv, bag, index)
        if is_real_item(item) then
            local id, quantity = tonumber(item.Id), tonumber(item.Count)
            local resource = resources:GetItemById(id)
            local maximum = tonumber(resource and (resource.StackSize or resource.Stack)) or 1
            snapshot.totals[id] = (snapshot.totals[id] or 0) + quantity
            if maximum > 1 and quantity < maximum then
                snapshot.partials[id] = (snapshot.partials[id] or 0) + 1
                if (tonumber(item.Flags) or 0) == 0 then
                    snapshot.eligible[id] = (snapshot.eligible[id] or 0) + 1
                    if snapshot.eligible[id] > 1 then snapshot.needed = true end
                end
            end
        end
    end
    return snapshot
end

function automatic.stack_after_move(observation)
    local move = observation.move
    local bulk = organizer.awaiting_move == observation
    if not observation.stack_bags then
        local resources = AshitaCore:GetResourceManager()
        local resource = resources and resources:GetItemById(move.item_id)
        local maximum = tonumber(resource and (resource.StackSize or resource.Stack)) or tonumber(move.stack_size) or 1
        local bags = bulk and (organizer.stack_bags or {}) or {}
        if move.target_container_id ~= INVENTORY_CONTAINER_ID and maximum > 1 then
            bags[move.target_container_id] = true
        end
        if bulk then organizer.stack_bags = bags end
        observation.stack_bags = bags
    end
    for _, bag in ipairs(SCANNED_CONTAINERS) do
        local deferred = false
        if bulk then
            for index=organizer.cursor + 1, #organizer.queue do
                if organizer.queue[index].source_container_id == bag then deferred = true; break end
            end
        end
        if observation.stack_bags[bag] and not deferred then
            local current = automatic.stack_snapshot(bag)
            if not current then return "failed", "destination unavailable while stacking " .. CONTAINERS[bag] end
            local waiting = observation.stack_wait
            if waiting then
                local complete = true
                for id, quantity in pairs(waiting.before.totals) do
                    if current.totals[id] ~= quantity then complete = false end
                    local eligible = waiting.before.eligible[id] or 0
                    local remaining = (waiting.before.partials[id] or 0) - eligible + 1
                    if eligible > 1 and (current.partials[id] or 0) > remaining then complete = false end
                end
                for id in pairs(current.totals) do
                    if not waiting.before.totals[id] then complete = false end
                end
                if not complete then
                    if os.time() - observation.stack_sent_at >= 5 then
                        return "failed", "Auto Sort not confirmed in " .. CONTAINERS[bag] .. "; check the bag before resuming"
                    end
                    return "pending"
                end
                write_probe("destination_stack", "OK", "partial stacks consolidated", CONTAINERS[bag])
                observation.stack_wait = nil
                observation.stack_bags[bag] = nil
            elseif current.needed then
                -- Native servers throttle stack requests; leave at least two seconds per bag.
                automatic.last_stack = automatic.last_stack or {}
                if os.clock() < (automatic.last_stack[bag] or -2) + 2 then return "pending" end
                observation.stack_wait = { bag=bag, before=current }
                observation.stack_sent_at = os.time()
                automatic.last_stack[bag] = os.clock()
                local packet = struct.pack('IBBH', 0, bag, 0, 0):totable()
                AshitaCore:GetPacketManager():AddOutgoingPacket(0x03A, packet)
                automatic.status = "Stacking items in " .. CONTAINERS[bag] .. "."
                write_probe("destination_stack", "SENT", "Auto Sort after confirmed storage transfer", CONTAINERS[bag])
                return "pending"
            else
                observation.stack_bags[bag] = nil
            end
        end
    end
    return "confirmed"
end

local function check_move_observation(observation)
    local move = observation.move
    if get_player_slug() ~= move.character_slug then return "failed", "character changed" end
    if observation.transferred then return automatic.stack_after_move(observation) end
    local source = container_item_count(move.source_container_id, move.item_id)
    local target = container_item_count(move.target_container_id, move.item_id)
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    local slot = inv and get_container_item(inv, move.source_container_id, move.source_index)
    local slot_count = is_real_item(slot) and tonumber(slot.Id) == move.item_id and tonumber(slot.Count) or 0
    if source and target and source <= observation.source_before - move.quantity
        and target >= observation.target_before + move.quantity
        and slot_count <= observation.source_slot_before - move.quantity then
        observation.transferred = true
        return automatic.stack_after_move(observation)
    end
    if os.time() - observation.started_at >= 5 then
        local details = ("source=%s/%s target=%s/%s source_slot=%s/%s (before/current)")
            :format(tostring(observation.source_before), tostring(source),
                tostring(observation.target_before), tostring(target),
                tostring(observation.source_slot_before), tostring(slot_count))
        return "failed", "transfer not confirmed; check accessible storage and inventory before starting again", details
    end
    return "pending"
end

local function send_move_packet(move)
    local packet = struct.pack('IIBBBB', 0, move.quantity, move.source_container_id, move.target_container_id,
        move.source_index, move.target_index or DESTINATION_AUTO_INDEX):totable()
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x029, packet)
end

local function move_to_command_label(move)
    return ("%s x%u %s[%u] -> %s"):format(
        move.item_name,
        move.quantity,
        CONTAINERS[move.source_container_id] or tostring(move.source_container_id),
        move.source_index,
        CONTAINERS[move.target_container_id] or tostring(move.target_container_id)
    )
end

local function build_move_from_args(args)
    if #args < 10 then
        return nil, "usage: /oddorg move <move_id> <character_slug> <item_id> <quantity> <src_container_id> <src_index> <dst_container_id> \"<name>\""
    end

    local item_id, item_err = parse_int(args[5], "item_id")
    local quantity, quantity_err = parse_int(args[6], "quantity")
    local source_container_id, source_container_err = parse_int(args[7], "source_container_id")
    local source_index, source_index_err = parse_int(args[8], "source_index")
    local target_container_id, target_container_err = parse_int(args[9], "target_container_id")
    local err = item_err or quantity_err or source_container_err or source_index_err or target_container_err
    if err ~= nil then
        return nil, err
    end

    return {
        move_id = args[3],
        character_slug = args[4],
        item_id = item_id,
        quantity = quantity,
        source_container_id = source_container_id,
        source_index = source_index,
        target_container_id = target_container_id,
        item_name = args[10],
        stack_size = 1,
    }, nil
end

local function handle_move(args)
    if organizer.running or ephemeral.running then
        say("Stop the active housekeeping run before requesting a separate move.")
        return
    end
    local ready, ready_err = new_run_ready()
    if not ready then say(ready_err); return end
    local move, err = build_move_from_args(args)
    if move == nil then
        fail_move(args[3] or "unknown", err, table.concat(args, " "))
        return
    end

    local ok, message, details = validate_move(move)
    if not ok then
        fail_move(move.move_id, message, details)
        return
    end

    organizer.options = nil
    organizer.queue = { move }
    organizer.stack_bags = nil
    organizer.cursor = 1
    organizer.next_send_at = 0
    organizer.awaiting_move = nil
    organizer.error = nil
    organizer.running = true
    organizer.scope = "single move"
    ui.visible = true
    say(("queued %s: %s x%u to %s"):format(move.move_id, move.item_name, move.quantity, CONTAINERS[move.target_container_id]))
end

local function collect_equipped_keys(quiet)
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    local equipped = {}
    local count = 0

    if inv == nil then
        write_probe("equipped_scan_done", "REJECT", "inventory unavailable", "")
        return equipped
    end

    for slot_id = 0, 15, 1 do
        local equipped_item = safe_call(nil, function() return inv:GetEquippedItem(slot_id) end)
        local raw_index = tonumber((equipped_item and equipped_item.Index) or 0) or 0
        local index = bit.band(raw_index, 0x00FF)
        local container_id = bit.band(raw_index, 0xFF00) / 256
        if index ~= 0 and container_id ~= nil then
            equipped[item_key(container_id, index)] = true
            count = count + 1
        end
    end

    if not quiet then write_probe("equipped_scan_done", "OK", "equipped items scanned", "count=" .. tostring(count)) end
    return equipped
end

collect_live_items = function()
    local scan_started = os.time()
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    local resources = AshitaCore:GetResourceManager()
    local items = {}
    local capacities = {}
    local counts = {}
    local equipment_count = 0
    local non_equipment_count = 0

    write_probe("snapshot_start", "OK", "collecting live items", get_player_slug())

    if inv == nil or resources == nil then
        write_probe("snapshot_done", "REJECT", "inventory resources unavailable", "")
        return nil, nil, "inventory resources unavailable"
    end

    local container_access, access_err = collect_container_access(inv)
    if not container_access then return nil, nil, access_err end
    local counter, counter_err = read_inventory_counter(inv)
    if counter == nil then return nil, nil, counter_err end
    for _, container_id in ipairs(SCANNED_CONTAINERS) do
        if os.time() - scan_started >= 2 then
            return nil, nil, "Storage scan took too long; movement stopped."
        end
        local access = container_access[container_id] or {
            unlocked = false,
            capacity = 0,
            raw_capacity = 0,
            reason = "access missing",
        }
        capacities[container_id] = access.capacity
        counts[container_id] = 0
        if access.unlocked and access.capacity > 0 then
            local loaded, loaded_err = container_is_loaded(inv, container_id)
            if not loaded then
                return nil, nil, loaded_err
            end
            for index = 1, access.capacity, 1 do
                if os.time() - scan_started >= 2 then
                    return nil, nil, "Storage scan took too long; movement stopped."
                end
                local entry = get_container_item(inv, container_id, index)
                if is_real_item(entry) then
                    local resource = resources:GetItemById(entry.Id)
                    local name = first_resource_name(resource)
                    if name == "" then
                        name = "Item " .. tostring(entry.Id)
                    end
                    local item = {
                        container_id = container_id,
                        index = index,
                        item_id = tonumber(entry.Id) or 0,
                        quantity = tonumber(entry.Count) or 1,
                        flags = tonumber(entry.Flags) or 0,
                        locked = bit.band(tonumber(entry.Flags) or 0,1) ~= 0,
                        item_name = name,
                        stack_size = stack_size_for(resource),
                        equippable = is_equipment(resource),
                        resource_type = tonumber(resource and resource.Type) or 0,
                        resource_flags = tonumber(resource and resource.Flags) or 0,
                        slot_category = slot_name_from_mask(tonumber(resource and resource.Slots) or 0),
                        level = tonumber(resource and resource.Level) or 0,
                    }
                    table.insert(items, item)
                    counts[container_id] = counts[container_id] + 1
                    if item.equippable then
                        equipment_count = equipment_count + 1
                    else
                        non_equipment_count = non_equipment_count + 1
                    end
                end
            end
        end
    end

    if os.time() - scan_started >= 2 then
        return nil, nil, "Storage scan took too long; movement stopped."
    end
    if counter == nil or counter ~= safe_call(nil, function() return inv:GetContainerUpdateCounter() end) then
        return nil, nil, "Inventory changed during the scan; wait for it to settle."
    end

    write_probe(
        "snapshot_done",
        "OK",
        "live items collected",
        ("items=%u equipment=%u non_equipment=%u containers=%u"):format(#items, equipment_count, non_equipment_count, table_len(capacities))
    )
    write_probe("snapshot_counts", "OK", "current container counts", counts_to_details(counts, capacities))
    report_inventory_ready()
    return {
        items = items,
        capacities = capacities,
        counts = counts,
        available_containers = container_access,
    }, resources, nil
end

function counts_to_details(counts, capacities)
    local parts = {}
    for _, container_id in ipairs(SCANNED_CONTAINERS) do
        table.insert(parts, ("%s=%u/%u"):format(
            CONTAINERS[container_id] or tostring(container_id),
            counts[container_id] or 0,
            capacities[container_id] or 0
        ))
    end
    return table.concat(parts, " ")
end

local function category_counts(items)
    local equipment = 0
    local non_equipment = 0
    local social = 0
    for _, item in ipairs(items) do
        if item.equippable then
            equipment = equipment + 1
        else
            non_equipment = non_equipment + 1
        end
        if is_social_item(item) then
            social = social + 1
        end
    end
    return equipment, non_equipment, social
end

local function clone_counts(counts)
    local copy = {}
    for container_id, count in pairs(counts or {}) do
        copy[container_id] = count
    end
    return copy
end

local function sorted_candidates(candidates, target_container_id)
    table.sort(candidates, function(left, right)
        local left_same = left.container_id == target_container_id and 0 or 1
        local right_same = right.container_id == target_container_id and 0 or 1
        if left_same ~= right_same then
            return left_same < right_same
        end
        local left_name = string.lower(left.item_name or "")
        local right_name = string.lower(right.item_name or "")
        if left_name ~= right_name then
            return left_name < right_name
        end
        if (left.level or 0) ~= (right.level or 0) then
            return (left.level or 0) < (right.level or 0)
        end
        if left.item_id ~= right.item_id then
            return left.item_id < right.item_id
        end
        if left.container_id ~= right.container_id then
            return left.container_id < right.container_id
        end
        return left.index < right.index
    end)
end

local function group_items_by_category(items, classify)
    local grouped = {}
    for _, item in ipairs(items) do
        local category = classify(item)
        grouped[category] = grouped[category] or {}
        table.insert(grouped[category], item)
    end
    return grouped
end

local function pop_best(grouped, category, target_container_id)
    local candidates = grouped[category]
    if candidates == nil or #candidates == 0 then
        return nil
    end
    sorted_candidates(candidates, target_container_id)
    local item = candidates[1]
    table.remove(candidates, 1)
    return item
end

local function collect_leftovers(grouped, classify)
    local leftovers = {}
    for _, candidates in pairs(grouped) do
        for _, item in ipairs(candidates) do
            table.insert(leftovers, item)
        end
    end
    table.sort(leftovers, function(left, right)
        local left_category = classify(left)
        local right_category = classify(right)
        if left_category ~= right_category then
            return left_category < right_category
        end
        local left_name = string.lower(left.item_name or "")
        local right_name = string.lower(right.item_name or "")
        if left_name ~= right_name then
            return left_name < right_name
        end
        if left.item_id ~= right.item_id then
            return left.item_id < right.item_id
        end
        if left.container_id ~= right.container_id then
            return left.container_id < right.container_id
        end
        return left.index < right.index
    end)
    return leftovers
end

-- Overflow is a fallback home, not a request to reshuffle identical stacks.
-- Prefer an existing resident before filling this bag from another location.
local function pop_overflow(leftovers, target_container_id)
    for index, item in ipairs(leftovers) do
        if item.container_id == target_container_id then
            return table.remove(leftovers, index)
        end
    end
    return table.remove(leftovers, 1)
end

local function add_assignment(plan, item, target_container_id, bucket, category, reason)
    local key = item_key(item.container_id, item.index)
    plan.assignments[key] = {
        item = item,
        target_container_id = target_container_id,
        bucket = bucket,
        category = category,
        reason = reason,
    }
    -- A partially reserved source already occupies its original slot.
    if not (item.reserved_quantity and target_container_id == item.container_id) then
        plan.target_counts[target_container_id] = (plan.target_counts[target_container_id] or 0) + 1
    end
end

local function reserve_pinned(plan, item, reason)
    add_assignment(plan, item, item.container_id, {
        label = CONTAINERS[item.container_id] or tostring(item.container_id),
        description = reason,
    }, "pinned", reason)
end

local function item_outcome(item)
    local rule, rule_err = item_rules.for_item(preferences.item_rules, item.item_id)
    if rule_err then return nil, rule_err end
    if rule then
        local valid, item_err = item_rules.validate_for_item(rule, item)
        if not valid then return nil, item_err end
    end
    local routes, layout_err = storage_layout.active_routes(preferences.storage_layout)
    if layout_err then return nil, layout_err end
    local base_target = storage_layout.target(preferences.storage_layout,item)
    local default_destination = base_target ~= false and base_target or nil
    local default_allowed = storage_layout.effective_allowed(preferences.storage_layout, preferences.background, item)
    local destination, mode = item_rules.destination(rule, default_destination)
    if base_target == false and mode == 'default' then mode='stay' end
    return {
        rule=rule,
        destination=destination,
        mode=mode,
        allowed=item_rules.allows_storage(rule, default_allowed),
        deposit=item_rules.allows_deposit(rule, default_allowed),
        carry_target=item_rules.carry_target(rule),
    }
end

local function build_wardrobe_plan(plan, movable_items, capacities)
    local grouped = group_items_by_category(movable_items, function(item)
        return item.slot_category or "other"
    end)

    for _, bucket in ipairs(WARDROBE_BUCKETS) do
        local capacity = capacities[bucket.container_id] or 0
        for _, category in ipairs(bucket.categories) do
            while (plan.target_counts[bucket.container_id] or 0) < capacity do
                local item = pop_best(grouped, category, bucket.container_id)
                if item == nil then
                    break
                end
                add_assignment(
                    plan,
                    item,
                    bucket.container_id,
                    bucket,
                    category,
                    "wardrobe standard: " .. bucket.description .. "; category=" .. category
                )
            end
        end
    end

    local leftovers = collect_leftovers(grouped, function(item) return item.slot_category or "other" end)
    for _, bucket in ipairs(WARDROBE_BUCKETS) do
        local capacity = capacities[bucket.container_id] or 0
        while (plan.target_counts[bucket.container_id] or 0) < capacity and #leftovers > 0 do
            local item = pop_overflow(leftovers, bucket.container_id)
            local category = item.slot_category or "other"
            add_assignment(
                plan,
                item,
                bucket.container_id,
                bucket,
                category,
                "wardrobe overflow standard: " .. bucket.description .. "; category=" .. category
            )
        end
    end

    if #leftovers > 0 then
        return false, "not enough wardrobe capacity for " .. tostring(#leftovers) .. " equipment items"
    end
    return true, nil
end

local function build_storage_plan(plan, movable_items, capacities)
    -- Reserve resident slots before any inbound assignment. Otherwise a later
    -- resident with nowhere to go can overbook an earlier incoming assignment.
    for _,item in ipairs(movable_items) do
        if not item.reserved_quantity then
            plan.target_counts[item.container_id]=(plan.target_counts[item.container_id] or 0)+1
        end
    end
    table.sort(movable_items,function(a,b)
        if a.item_id~=b.item_id then return a.item_id<b.item_id end
        if a.container_id~=b.container_id then return a.container_id<b.container_id end
        return a.index<b.index
    end)
    local pending=movable_items
    while #pending>0 do
        local remaining,progressed={},false
        for _,item in ipairs(pending) do
            local target
            for _,bag in ipairs(storage_layout.default_route(item)) do
                if (capacities[bag] or 0)>0 and ((bag==item.container_id and (plan.target_counts[bag] or 0)<=capacities[bag])
                    or (plan.target_counts[bag] or 0)<capacities[bag]) then target=bag; break end
            end
            if target then
                if not item.reserved_quantity then plan.target_counts[item.container_id]=plan.target_counts[item.container_id]-1 end
                add_assignment(plan,item,target,{label=CONTAINERS[target],description='item-type home or overflow'},
                    storage_layout.classify(item),'non-equipment standard: item-type home or overflow')
                progressed=true
            else remaining[#remaining+1]=item end
        end
        pending=remaining
        if not progressed then break end
    end
    -- Full bags can exchange residents. Each closed cycle releases exactly one
    -- slot per destination; the physical scheduler borrows Inventory to execute it.
    local function find_cycle(items)
        local edges,visited,path,positions={},{},{},{}
        for _,item in ipairs(items) do
            if not item.reserved_quantity then
                local source=item.container_id
                edges[source]=edges[source] or {}
                for _,target in ipairs(storage_layout.default_route(item)) do
                    if target~=source and (capacities[target] or 0)>0 then
                        table.insert(edges[source],{item=item,target=target})
                    end
                end
            end
        end
        local function visit(bag)
            visited[bag],positions[bag]=true,#path+1
            for _,edge in ipairs(edges[bag] or {}) do
                path[#path+1]=edge
                if positions[edge.target] then
                    local cycle={}
                    for i=positions[edge.target],#path do cycle[#cycle+1]=path[i] end
                    return cycle
                elseif not visited[edge.target] then
                    local cycle=visit(edge.target)
                    if cycle then return cycle end
                end
                path[#path]=nil
            end
            positions[bag]=nil
        end
        for _,bag in ipairs(SCANNED_CONTAINERS) do
            if not visited[bag] then local cycle=visit(bag); if cycle then return cycle end end
        end
    end
    while #pending>0 do
        local cycle=find_cycle(pending)
        if not cycle then break end
        local assigned={}
        for _,edge in ipairs(cycle) do
            local item=edge.item
            plan.target_counts[item.container_id]=plan.target_counts[item.container_id]-1
            add_assignment(plan,item,edge.target,{label=CONTAINERS[edge.target],description='full-bag exchange'},
                storage_layout.classify(item),'default homes: exchange through Inventory')
            assigned[item]=true
        end
        local remaining={}
        for _,item in ipairs(pending) do if not assigned[item] then remaining[#remaining+1]=item end end
        pending=remaining
    end
    for _,item in ipairs(pending) do
        local fallback
        -- Residents already in usable spare storage need no extra transfer.
        local route=storage_layout.default_route(item,true)
        if contains(route,item.container_id) then fallback=item.container_id end
        if not fallback then
            for _,bag in ipairs(route) do
                if (plan.target_counts[bag] or 0)<(capacities[bag] or 0) then fallback=bag; break end
            end
        end
        if not item.reserved_quantity then plan.target_counts[item.container_id]=plan.target_counts[item.container_id]-1 end
        if fallback then
            add_assignment(plan,item,fallback,{label=CONTAINERS[fallback],description='spare storage'},
                storage_layout.classify(item),'default homes full: use spare storage')
        else
            if #route>0 then plan.default_blocked=(plan.default_blocked or 0)+1 end
            reserve_pinned(plan,item,'No accessible storage room; leave in place')
        end
    end
    return true
end

-- Consolidation is a separate first pass. Placement is recomputed from the
-- confirmed packed inventory, rather than charging one slot for every fragment.
local function build_stack_plan(snapshot,options,reserved,refill,carried_reserves)
    if options.scope~='all' and options.scope~='storage' then return nil end
    local layout_routes=storage_layout.active_routes(preferences.storage_layout)
    local groups={}
    local plan={assignments={},target_counts=clone_counts(snapshot.counts),logical_moves={},
        pinned_social=0,pinned_equipped=0,kept_quantity=0,pending_refill_quantity=0,stacking=true}
    for _,item in ipairs(snapshot.items) do
        local key=item_key(item.container_id,item.index)
        local protected=(reserved[key] or 0)+(refill[key] or 0)
        plan.kept_quantity=plan.kept_quantity+(reserved[key] or 0)
        plan.pending_refill_quantity=plan.pending_refill_quantity+(refill[key] or 0)
        local outcome=item_outcome(item)
        if (item.stack_size or 1)>1 and not item.equippable and not is_social_item(item)
            and (tonumber(item.flags) or 0)==0 and storage_layout.classify(item)
            and outcome and outcome.mode~='stay'
            and not ((layout_routes or outcome.destination~=nil) and not outcome.allowed) then
            local entry={item=item,quantity=item.quantity,available=math.max(0,item.quantity-protected)}
            groups[item.item_id]=groups[item.item_id] or {}
            table.insert(groups[item.item_id],entry)
        end
    end
    local ids={}
    for id in pairs(groups) do ids[#ids+1]=id end
    table.sort(ids)
    local inventory_free=(snapshot.capacities[0] or 0)-(snapshot.counts[0] or 0)
    for _,id in ipairs(ids) do
        local group=groups[id]
        table.sort(group,function(a,b)
            if (a.item.container_id==0)~=(b.item.container_id==0) then return b.item.container_id==0 end
            local a_split=a.available>0 and a.available<a.quantity
            local b_split=b.available>0 and b.available<b.quantity
            if a_split~=b_split then return b_split end
            if a.quantity~=b.quantity then return a.quantity>b.quantity end
            if a.item.container_id~=b.item.container_id then return a.item.container_id<b.item.container_id end
            return a.item.index<b.item.index
        end)
        for index,anchor in ipairs(group) do
            if anchor.item.container_id~=0 and anchor.quantity>0 then
                local room=anchor.item.stack_size-anchor.quantity
                for donor_index=index+1,#group do
                    local donor=group[donor_index]
                    local quantity=math.min(room,donor.available)
                    local target=anchor.item.container_id
                    local empty=(snapshot.capacities[target] or 0)-(snapshot.counts[target] or 0)
                    local can_stage=donor.item.container_id==0 or inventory_free>0
                    local can_merge=donor.item.container_id~=0 or quantity==donor.quantity or empty>0
                    if quantity>0 and can_stage and can_merge and donor.item.item_name==anchor.item.item_name then
                        plan.logical_moves[#plan.logical_moves+1]={
                            move_id=options.character_slug..'-stack-'..tostring(#plan.logical_moves+1),
                            character_slug=options.character_slug,item_id=id,item_name=donor.item.item_name,
                            quantity=quantity,stack_size=donor.item.stack_size,
                            source_container_id=donor.item.container_id,source_index=donor.item.index,
                            target_container_id=target,carried_reserve=carried_reserves[id] or 0,
                            stack_consolidation=true,bucket=CONTAINERS[target],reason='fill existing partial stack',scope='storage'}
                        donor.quantity=donor.quantity-quantity
                        donor.available=donor.available-quantity
                        anchor.quantity=anchor.quantity+quantity
                        room=room-quantity
                    end
                    if room==0 then break end
                end
            end
        end
    end
    return #plan.logical_moves>0 and plan or nil
end

local function build_organize_plan(snapshot, options)
    local layout_routes, layout_err = storage_layout.active_routes(preferences.storage_layout)
    if layout_err then return nil, layout_err end
    local reserved, keep_err, refill_reserved = get_keep_reservations(snapshot)
    if not reserved then return nil, keep_err end
    local carried_reserves = {}
    for _, item in ipairs(snapshot.items) do
        if item.container_id == INVENTORY_CONTAINER_ID then
            carried_reserves[item.item_id] = (carried_reserves[item.item_id] or 0)
                + (reserved[item_key(item.container_id, item.index)] or 0)
        end
    end
    for id in pairs((preferences.item_rules and preferences.item_rules.items) or {}) do
        local rule, rule_err = item_rules.for_item(preferences.item_rules, id)
        if rule_err then return nil, rule_err end
        local item_id = tonumber(id)
        carried_reserves[item_id] = math.max(carried_reserves[item_id] or 0, item_rules.carry_target(rule))
    end
    local stack_plan=build_stack_plan(snapshot,options,reserved,refill_reserved,carried_reserves)
    if stack_plan then return stack_plan end
    local equipped_keys = options.allow_equipped and {} or collect_equipped_keys()
    local plan = {
        assignments = {},
        target_counts = {},
        logical_moves = {},
        pinned_social = 0,
        pinned_equipped = 0,
        kept_quantity = 0,
        pending_refill_quantity = 0,
    }
    local equipment_items = {}
    local storage_items = {}

    local equipment_count, non_equipment_count, social_count = category_counts(snapshot.items)
    write_probe(
        "classify_summary",
        "OK",
        "items classified",
        ("equipment=%u non_equipment=%u social=%u"):format(equipment_count, non_equipment_count, social_count)
    )

    for _, item in ipairs(snapshot.items) do
        local outcome, outcome_err = item_outcome(item)
        if not outcome then return nil, outcome_err end
        local key = item_key(item.container_id, item.index)
        local kept = math.min(item.quantity, reserved[key] or 0)
        local refill = math.min(math.max(0, item.quantity - kept), refill_reserved[key] or 0)
        local protected = kept + refill
        plan.kept_quantity = plan.kept_quantity + kept
        plan.pending_refill_quantity = plan.pending_refill_quantity + refill
        local move_scope = item.equippable and "wardrobes" or "storage"
        if protected >= item.quantity then
            reserve_pinned(plan, item, "your item protection")
        elseif options.scope ~= "all" and options.scope ~= move_scope then
            reserve_pinned(plan, item, "outside requested scope")
        elseif bit.band(tonumber(item.flags) or 0, 1) ~= 0 then
            reserve_pinned(plan, item, "item currently locked or in use")
        elseif equipped_keys[key] then
            plan.pinned_equipped = plan.pinned_equipped + 1
            reserve_pinned(plan, item, "equipped item pinned")
            write_probe("pin_equipped", "OK", item.item_name, key)
        elseif is_social_item(item) and not options.include_social then
            plan.pinned_social = plan.pinned_social + 1
            reserve_pinned(plan, item, "social shell item pinned")
            write_probe("pin_social", "OK", item.item_name, key)
        elseif outcome.mode == "stay" then
            reserve_pinned(plan, item, "your per-item rule keeps extras where they are")
        elseif (layout_routes or outcome.destination ~= nil) and not outcome.allowed then
            reserve_pinned(plan, item, "not assigned or individually excluded from this quickset")
        elseif outcome.mode == "specific" or outcome.destination ~= nil then
            local candidate = item
            if protected > 0 then
                candidate = {}
                for field, value in pairs(item) do candidate[field] = value end
                candidate.quantity = item.quantity - protected
                candidate.reserved_quantity = protected
                plan.target_counts[item.container_id] = (plan.target_counts[item.container_id] or 0) + 1
            end
            local target = outcome.destination
            if (snapshot.capacities[target] or 0) <= 0 then
                return nil, 'Your chosen destination is unavailable: '..tostring(CONTAINERS[target])
            end
            add_assignment(plan, candidate, target,
                {label=CONTAINERS[target],description="your per-item rule"},
                storage_layout.classify(item), "your per-item destination")
        else
            local candidate = item
            if protected > 0 then
                candidate = {}
                for field, value in pairs(item) do candidate[field] = value end
                candidate.quantity = item.quantity - protected
                candidate.reserved_quantity = protected
                plan.target_counts[item.container_id] = (plan.target_counts[item.container_id] or 0) + 1
            end
            if layout_routes then
                local target = outcome.destination
                add_assignment(plan, candidate, target, {label=CONTAINERS[target],description="active storage quickset"},
                    storage_layout.classify(item), "your storage quickset")
            else
                table.insert(item.equippable and equipment_items or storage_items, candidate)
            end
        end
    end

    local ok, err = true, nil
    if not layout_routes then ok, err = build_wardrobe_plan(plan, equipment_items, snapshot.capacities) end
    if not ok then
        write_probe("capacity_preflight", "REJECT", err, "wardrobes")
        return nil, err
    end

    if not layout_routes then ok, err = build_storage_plan(plan, storage_items, snapshot.capacities) end
    if not ok then
        write_probe("capacity_preflight", "REJECT", err, "storage")
        return nil, err
    end


    for _, item in ipairs(snapshot.items) do
        local assignment = plan.assignments[item_key(item.container_id, item.index)]
        if assignment ~= nil and assignment.target_container_id ~= item.container_id then
            local move_scope = item.equippable and "wardrobes" or "storage"
            if options.scope == "all" or options.scope == move_scope then
                table.insert(plan.logical_moves, {
                    move_id = ("%s-%04d"):format(options.character_slug, #plan.logical_moves + 1),
                    character_slug = options.character_slug,
                    item_id = item.item_id,
                    quantity = assignment.item.quantity,
                    carried_reserve = carried_reserves[item.item_id] or 0,
                    source_container_id = item.container_id,
                    source_index = item.index,
                    target_container_id = assignment.target_container_id,
                    item_name = item.item_name,
                    stack_size = item.stack_size,
                    bucket = (assignment.bucket.label or "") .. ": " .. (assignment.bucket.description or ""),
                    reason = assignment.reason,
                    scope = move_scope,
                })
            end
        end
    end

    write_probe("target_counts", "OK", "planned target counts", counts_to_details(plan.target_counts, snapshot.capacities))
    for container_id, count in pairs(plan.target_counts) do
        local capacity = snapshot.capacities[container_id] or 0
        if (capacity > 0 or layout_routes) and count > capacity then
            if layout_routes and capacity == 0 then
                return nil, (CONTAINERS[container_id] or tostring(container_id)) .. " is locked or unavailable. Your quickset will wait for that bag."
            end
            local message = ("%s would overfill %u/%u"):format(CONTAINERS[container_id] or tostring(container_id), count, capacity)
            write_probe("capacity_preflight", "REJECT", message, "")
            return nil, message
        end
    end
    write_probe("capacity_preflight", "OK", "target counts fit capacities", counts_to_details(plan.target_counts, snapshot.capacities))
    return plan, nil
end

local function snapshot_maps(snapshot)
    local items_by_slot = {}
    local inventory_slots = {}
    for _, item in ipairs(snapshot.items) do
        items_by_slot[item_key(item.container_id, item.index)] = {
            container_id = item.container_id,
            index = item.index,
            item_id = item.item_id,
            quantity = item.quantity,
            item_name = item.item_name,
            stack_size = item.stack_size,
            equippable = item.equippable,
            locked = (tonumber(item.flags) or 0) ~= 0,
        }
        if item.container_id == INVENTORY_CONTAINER_ID then
            inventory_slots[item.index] = true
        end
    end
    return items_by_slot, inventory_slots
end

local function pending_source_keys(pending)
    local keys = {}
    for _, move in ipairs(pending) do
        keys[item_key(move.source_container_id, move.source_index)] = true
    end
    return keys
end

local function first_open_inventory_slot(inventory_slots, capacity)
    for index = 1, capacity, 1 do
        if not inventory_slots[index] then
            return index
        end
    end
    return nil
end

local function find_stack_target(move, items_by_slot, blocked_source_keys)
    if (tonumber(move.stack_size) or 1) <= 1 then
        return nil
    end
    local source_key = item_key(move.source_container_id, move.source_index)
    for key, item in pairs(items_by_slot) do
        if key ~= source_key
            and not blocked_source_keys[key]
            and not item.locked
            and item.container_id == move.target_container_id
            and item.item_id == move.item_id
            and string.lower(item.item_name or "") == string.lower(move.item_name or "")
            and (item.quantity + move.quantity) <= math.min(item.stack_size or move.stack_size or 1, move.stack_size or 1) then
            return key
        end
    end
    return nil
end

local function target_accepts(move, counts, capacities, items_by_slot, blocked_source_keys)
    local capacity=capacities[move.target_container_id] or 0
    if capacity<=0 then return false,nil end
    local source=items_by_slot[item_key(move.source_container_id,move.source_index)]
    -- A stored split is staged as its own Inventory stack before the put.
    if source and (move.source_container_id~=0 or source.quantity==move.quantity) then
        local stack_key=find_stack_target(move,items_by_slot,blocked_source_keys)
        if stack_key then return true,stack_key end
    end
    return (counts[move.target_container_id] or 0)<capacity,nil
end

local function remove_state_item(item, counts, inventory_slots, items_by_slot)
    items_by_slot[item_key(item.container_id, item.index)] = nil
    counts[item.container_id] = math.max(0, (counts[item.container_id] or 0) - 1)
    if item.container_id == INVENTORY_CONTAINER_ID then
        inventory_slots[item.index] = nil
    end
end

local function take_state_item(item, quantity, counts, inventory_slots, items_by_slot)
    local taken = {}
    for field, value in pairs(item) do taken[field] = value end
    taken.quantity = quantity
    if quantity < item.quantity then
        item.quantity = item.quantity - quantity
    else
        remove_state_item(item, counts, inventory_slots, items_by_slot)
    end
    return taken
end

local function place_state_item(item, target_container_id, index, counts, inventory_slots, items_by_slot, stack_key)
    if stack_key ~= nil then
        local target = items_by_slot[stack_key]
        if target ~= nil then
            target.quantity = target.quantity + item.quantity
        end
        return
    end

    local placed = {
        container_id = target_container_id,
        index = index,
        item_id = item.item_id,
        quantity = item.quantity,
        item_name = item.item_name,
        stack_size = item.stack_size,
        equippable = item.equippable,
    }
    items_by_slot[item_key(target_container_id, index)] = placed
    counts[target_container_id] = (counts[target_container_id] or 0) + 1
    if target_container_id == INVENTORY_CONTAINER_ID then
        inventory_slots[index] = true
    end
end

local function append_physical(physical, logical, suffix, source_container_id, source_index, target_container_id)
    if suffix == "put" and source_container_id == INVENTORY_CONTAINER_ID then
        source_container_id = INVENTORY_CONTAINER_ID
        source_index = 0
    end
    table.insert(physical, {
        move_id = logical.move_id .. "-" .. suffix,
        character_slug = logical.character_slug,
        item_id = logical.item_id,
        quantity = logical.quantity,
        carried_reserve = logical.carried_reserve,
        source_container_id = source_container_id,
        source_index = source_index,
        target_container_id = target_container_id,
        item_name = logical.item_name,
        stack_size = logical.stack_size,
        bucket = logical.bucket,
        reason = logical.reason,
        suffix = suffix,
    })
end

local function sort_pending(pending, counts, capacities)
    table.sort(pending, function(left, right)
        local left_source_count = counts[left.source_container_id] or 0
        local right_source_count = counts[right.source_container_id] or 0
        local left_source_capacity = capacities[left.source_container_id] or math.max(left_source_count, 80)
        local right_source_capacity = capacities[right.source_container_id] or math.max(right_source_count, 80)
        local left_source_free = left_source_capacity - left_source_count
        local right_source_free = right_source_capacity - right_source_count
        if left_source_free ~= right_source_free then
            return left_source_free < right_source_free
        end
        if left.target_container_id ~= right.target_container_id then
            return left.target_container_id < right.target_container_id
        end
        return left.move_id < right.move_id
    end)
end

local function remove_pending(pending, move)
    for index, candidate in ipairs(pending) do
        if candidate == move then
            table.remove(pending, index)
            return
        end
    end
end

local function copy_move(move)
    local copy = {}
    for key, value in pairs(move) do
        copy[key] = value
    end
    return copy
end

local function target_containers_for_pending(pending)
    local targets = {}
    for _, move in ipairs(pending) do
        targets[move.target_container_id] = true
    end
    return targets
end

local function build_physical_queue(logical_moves, snapshot)
    local counts = clone_counts(snapshot.counts)
    local items_by_slot, inventory_slots = snapshot_maps(snapshot)
    local pending = {}
    local physical = {}

    for _, move in ipairs(logical_moves) do
        if move.source_container_id ~= move.target_container_id or move.stack_consolidation then
            table.insert(pending, copy_move(move))
        end
    end

    while #pending > 0 do
        local progressed = false
        sort_pending(pending, counts, snapshot.capacities)

        for _, move in ipairs(pending) do
            if move.source_container_id == INVENTORY_CONTAINER_ID then
                local blocked = pending_source_keys(pending)
                blocked[item_key(move.source_container_id, move.source_index)] = nil
                local accepts, stack_key = target_accepts(move, counts, snapshot.capacities, items_by_slot, blocked)
                local source_item = items_by_slot[item_key(move.source_container_id, move.source_index)]
                if accepts and source_item ~= nil then
                    source_item = take_state_item(source_item, move.quantity, counts, inventory_slots, items_by_slot)
                    append_physical(physical, move, "put", INVENTORY_CONTAINER_ID, move.source_index, move.target_container_id)
                    if stack_key == nil then
                        place_state_item(source_item, move.target_container_id, -#physical, counts, inventory_slots, items_by_slot, nil)
                    else
                        place_state_item(source_item, move.target_container_id, nil, counts, inventory_slots, items_by_slot, stack_key)
                    end
                    remove_pending(pending, move)
                    progressed = true
                    break
                end
            end
        end

        if progressed then
            -- Continue so Inventory gets emptied before new pulls.
        else
            for _, move in ipairs(pending) do
                if move.source_container_id ~= INVENTORY_CONTAINER_ID then
                    local source_key = item_key(move.source_container_id, move.source_index)
                    local source_item = items_by_slot[source_key]
                    if source_item ~= nil then
                        local blocked = pending_source_keys(pending)
                        blocked[source_key] = nil
                        local inventory_capacity = snapshot.capacities[INVENTORY_CONTAINER_ID] or 0
                        local inventory_index = first_open_inventory_slot(inventory_slots, inventory_capacity)

                        if move.target_container_id == INVENTORY_CONTAINER_ID then
                            if inventory_index ~= nil then
                                source_item = take_state_item(source_item, move.quantity, counts, inventory_slots, items_by_slot)
                                append_physical(physical, move, "pull", move.source_container_id, move.source_index, INVENTORY_CONTAINER_ID)
                                place_state_item(source_item, INVENTORY_CONTAINER_ID, inventory_index, counts, inventory_slots, items_by_slot, nil)
                                remove_pending(pending, move)
                                progressed = true
                                break
                            end
                        else
                            local accepts, stack_key = target_accepts(move, counts, snapshot.capacities, items_by_slot, blocked)
                            if accepts and inventory_index ~= nil then
                                source_item = take_state_item(source_item, move.quantity, counts, inventory_slots, items_by_slot)
                                append_physical(physical, move, "pull", move.source_container_id, move.source_index, INVENTORY_CONTAINER_ID)
                                place_state_item(source_item, INVENTORY_CONTAINER_ID, inventory_index, counts, inventory_slots, items_by_slot, nil)

                                local staged_item = items_by_slot[item_key(INVENTORY_CONTAINER_ID, inventory_index)]
                                remove_state_item(staged_item, counts, inventory_slots, items_by_slot)
                                append_physical(physical, move, "put", INVENTORY_CONTAINER_ID, inventory_index, move.target_container_id)
                                if stack_key == nil then
                                    place_state_item(staged_item, move.target_container_id, -#physical, counts, inventory_slots, items_by_slot, nil)
                                else
                                    place_state_item(staged_item, move.target_container_id, nil, counts, inventory_slots, items_by_slot, stack_key)
                                end
                                remove_pending(pending, move)
                                progressed = true
                                break
                            end
                        end
                    end
                end
            end
        end

        if not progressed then
            local target_containers = target_containers_for_pending(pending)
            local inventory_capacity = snapshot.capacities[INVENTORY_CONTAINER_ID] or 0
            local inventory_index = first_open_inventory_slot(inventory_slots, inventory_capacity)

            if inventory_index ~= nil then
                for _, move in ipairs(pending) do
                    if move.source_container_id ~= INVENTORY_CONTAINER_ID and target_containers[move.source_container_id] then
                        local source_key = item_key(move.source_container_id, move.source_index)
                        local source_item = items_by_slot[source_key]
                        if source_item ~= nil then
                            local original_source_container_id = move.source_container_id
                            local original_source_index = move.source_index
                            source_item = take_state_item(source_item, move.quantity, counts, inventory_slots, items_by_slot)
                            append_physical(physical, move, "pull", original_source_container_id, original_source_index, INVENTORY_CONTAINER_ID)
                            place_state_item(source_item, INVENTORY_CONTAINER_ID, inventory_index, counts, inventory_slots, items_by_slot, nil)
                            move.source_container_id = INVENTORY_CONTAINER_ID
                            move.source_index = inventory_index
                            write_probe(
                                "queue_stage",
                                "OK",
                                "staged item to break blocked full-container flow",
                                ("%s[%u] -> Inventory[%u] target=%s"):format(
                                    CONTAINERS[original_source_container_id] or tostring(original_source_container_id),
                                    original_source_index,
                                    inventory_index,
                                    CONTAINERS[move.target_container_id] or tostring(move.target_container_id)
                                )
                            )
                            progressed = true
                            break
                        end
                    end
                end
            end
        end

        if not progressed then
            local blocked_targets = {}
            for _, move in ipairs(pending) do
                blocked_targets[move.target_container_id] = true
            end
            local targets = {}
            for target in pairs(blocked_targets) do
                table.insert(targets, CONTAINERS[target] or tostring(target))
            end
            table.sort(targets)
            return nil, "no menu-flow move is schedulable; blocked_targets=" .. table.concat(targets, ",")
        end
    end

    return physical, nil
end

local function write_plan(plan, queue)
    local file = io.open(plan_path(), "wb")
    if file == nil then
        return
    end
    file:write("kind\tsequence\tmove_id\tname\tquantity\tsource\tsource_index\ttarget\tbucket\treason\n")
    for index, move in ipairs(plan.logical_moves or {}) do
        file:write(table.concat({
            "logical",
            tostring(index),
            clean_field(move.move_id),
            clean_field(move.item_name),
            tostring(move.quantity),
            clean_field(CONTAINERS[move.source_container_id] or move.source_container_id),
            tostring(move.source_index),
            clean_field(CONTAINERS[move.target_container_id] or move.target_container_id),
            clean_field(move.bucket),
            clean_field(move.reason),
        }, "\t") .. "\n")
    end
    for index, move in ipairs(queue or {}) do
        file:write(table.concat({
            "physical",
            tostring(index),
            clean_field(move.move_id),
            clean_field(move.item_name),
            tostring(move.quantity),
            clean_field(CONTAINERS[move.source_container_id] or move.source_container_id),
            tostring(move.source_index),
            clean_field(CONTAINERS[move.target_container_id] or move.target_container_id),
            clean_field(move.bucket),
            clean_field(move.reason),
        }, "\t") .. "\n")
    end
    file:close()
end

local function parse_organize_options(args)
    local options = {
        action = string.lower(args[3] or "status"),
        scope = "all",
        allow_equipped = false,
        include_social = false,
        character_slug = get_player_slug(),
    }

    for index = 4, #args, 1 do
        local value = string.lower(args[index] or "")
        if value == "all" or value == "wardrobes" or value == "storage" then
            options.scope = value
        elseif value == "equipped" or value == "include-equipped" then
            options.allow_equipped = true
        elseif value == "social" or value == "include-social" then
            options.include_social = true
        elseif value == "noprobes" then
            set_probes_enabled(false)
        elseif value == "probes" then
            set_probes_enabled(true)
        elseif value:match("^delay=") ~= nil then
            local parsed = tonumber(value:match("^delay=(.+)$"))
            if parsed ~= nil and parsed > 0 then
                organizer.delay = parsed
            end
        end
    end

    return options
end

-- Stop only when every temporary Inventory pull in this prefix has its put.
-- Full-bag exchanges can interleave several pairs, so adjacent pairs alone
-- are not a sufficient boundary.
local function limit_organization_batch(plan, queue, budget)
    budget = math.max(0, math.min(50, budget or 50))
    if #queue <= budget then return queue end
    local puts, staged, safe, open = {}, {}, 0, 0
    for _, move in ipairs(queue) do
        if move.suffix == 'put' then puts[move.move_id:gsub('%-put$','')] = true end
    end
    for index=1,math.min(budget,#queue) do
        local move=queue[index]
        local id=move.move_id:gsub('%-pull$',''):gsub('%-put$','')
        if move.suffix=='pull' and puts[id] then
            staged[id]=true; open=open+1
        elseif move.suffix=='put' and staged[id] then
            staged[id]=nil; open=open-1
        end
        if open==0 then safe=index end
    end
    if safe==0 then return nil,'No complete transfer group fits the remaining 50-move budget.' end
    local batch, included={},{}
    for index=1,safe do
        local move=queue[index]
        batch[index]=move
        included[move.move_id:gsub('%-pull$',''):gsub('%-put$','')]=true
    end
    local logical={}
    for _,move in ipairs(plan.logical_moves) do
        if included[move.move_id] then logical[#logical+1]=move end
    end
    plan.logical_moves,plan.batch_limited=logical,true
    return batch
end

local function build_preview_or_queue(options, budget)
    local snapshot, _, err = collect_live_items()
    if snapshot == nil then
        return nil, nil, err
    end

    local plan, plan_err = build_organize_plan(snapshot, options)
    if plan == nil then
        return nil, nil, plan_err
    end
    plan.snapshot, plan.scope = snapshot, options.scope

    local queue, queue_err = build_physical_queue(plan.logical_moves, snapshot)
    if queue == nil then
        write_probe("plan_done", "REJECT", queue_err, "logical_moves=" .. tostring(#plan.logical_moves))
        return nil, nil, queue_err
    end

    queue, queue_err = limit_organization_batch(plan,queue,budget)
    if not queue then return nil,nil,queue_err end
    write_plan(plan, queue)
    write_probe(
        "plan_done",
        "OK",
        "organization plan built",
        ("scope=%s logical=%u physical=%u pinned_equipped=%u pinned_social=%u"):format(
            options.scope,
            #plan.logical_moves,
            #queue,
            plan.pinned_equipped,
            plan.pinned_social
        )
    )
    return plan, queue, nil
end

-- Ignore slot renumbering from Auto Sort, but retain bag, item, quantity and
-- flags so a repeated distribution cannot keep a run cycling indefinitely.
local function organization_state_signature(snapshot)
    local rows = {}
    for _, item in ipairs(snapshot.items) do
        rows[#rows+1] = table.concat({item.container_id,item.item_id,item.quantity,item.flags or 0},":")
    end
    table.sort(rows)
    return table.concat(rows,"|")
end

local function start_organize_queue(options, plan, queue)
    ui.preview_plan = plan
    organizer.running = true
    organizer.queue = queue
    organizer.stack_bags = nil
    organizer.cursor = 1
    organizer.scope = options.scope
    organizer.started_at = os.clock()
    organizer.next_send_at = 0
    organizer.error = nil
    organizer.awaiting_inventory = nil
    organizer.awaiting_move = nil
    organizer.summary = { logical=#plan.logical_moves, physical=#queue }
    ui.bulk_result = nil
    organizer.options = storage_layout.clone(options)
    organizer.pass = 1
    organizer.completed_transfers = 0
    organizer.batch_limited = plan.batch_limited
    organizer.seen_states = {[organization_state_signature(plan.snapshot)] = true}
    ui.visible = true
    ui.page, ui.settings_tab = "settings", "bulk"
    write_probe("queue_start", "OK", "organization queue started", ("scope=%s physical=%u"):format(options.scope, #queue))
    say(("organizer started: logical=%u physical=%u delay=%.2fs"):format(#plan.logical_moves, #queue, organizer.delay))
end

local function handle_organize(args)
    if args[3] == "preview" or args[3] == "run" or args[3] == "stop" or args[3] == "status" then
        -- Explicit command verbs are kept visible for static safety tests and operator trust.
    end
    local options = parse_organize_options(args)
    if options.action == "preview" or options.action == "run" then
        ui.visible, ui.page, ui.settings_tab = true, "settings", "bulk"
    end

    if options.action == "stop" then
        automatic.paused = true
        automatic.status = "Background clearing paused. Resume background when ready."
        settle_pending_actions()
        organizer.running = false
        organizer.error = nil
        organizer.awaiting_inventory = nil
        organizer.awaiting_move = nil
        write_probe("queue_stop", "OK", "stopped by command", "cursor=" .. tostring(organizer.cursor))
        ui.bulk_result = "Organization stopped. Automatic care is paused; resume it when ready."
        say("organizer stopped.")
        return
    end

    if options.action == "status" then
        local remaining = math.max(0, #organizer.queue - organizer.cursor + 1)
        say(("organizer running=%s queue=%u cursor=%u remaining=%u probes=%s"):format(
            tostring(organizer.running),
            #organizer.queue,
            organizer.cursor,
            remaining,
            tostring(PROBES_ENABLED)
        ))
        write_probe("queue_status", "OK", "status requested", "remaining=" .. tostring(remaining))
        return
    end

    if options.action ~= "preview" and options.action ~= "run" then
        say("usage: /oddorg organize preview|run|stop|status [all|wardrobes|storage] [equipped] [social] [probes|noprobes] [delay=0.8]")
        return
    end

    if ephemeral.running then
        say("ephemeral dump is running; stop it before organizing storage.")
        return
    end

    if organizer.running then
        say("organization is already running; stop it before building another plan.")
        return
    end
    local ready, ready_err = new_run_ready()
    if not ready then say(ready_err); return end

    ui.preview_plan = nil
    local plan, queue, err = build_preview_or_queue(options)
    if plan == nil then
        organizer.error = err or "Organization plan failed."
        write_probe("plan_done", "REJECT", err, options.scope)
        print(chat.header("OddOrg") .. chat.error(err or "plan failed"))
        return
    end

    if options.action == "preview" then
        organizer.error = nil
        ui.visible = true
        ui.page, ui.settings_tab = "settings", "bulk"
        ui.preview_plan = plan
        ui.preview_visible = true
        say(("Preview: %u item moves, %u transfers; %u items kept in place. Open /oddorg to review.")
            :format(#plan.logical_moves, #queue, plan.kept_quantity))
        return
    end

    start_organize_queue(options, plan, queue)
end

local function handle_probes(args)
    local action = string.lower(args[3] or "status")
    if args[3] == "on" then
        set_probes_enabled(true)
        say("probes enabled.")
        return
    end
    if args[3] == "off" then
        set_probes_enabled(false)
        say("probes disabled.")
        return
    end
    if args[3] == "clear" then
        clear_probes()
        write_probe("probe_state", "OK", "cleared", probe_path())
        say("probes cleared.")
        return
    end
    if args[3] == "status" or action == "status" then
        say(("probes=%s path=%s"):format(tostring(PROBES_ENABLED), probe_path()))
        write_probe("probe_state", "OK", "status", tostring(PROBES_ENABLED))
        return
    end
    say("usage: /oddorg probes on|off|clear|status")
end

local function set_keep_rule(item_id, value, automatic_allowed, item_rule_update)
    local keep, err = current_keep_rules()
    if not keep then ui.notice = err; return false end
    local resource = AshitaCore:GetResourceManager():GetItemById(item_id)
    if not resource or first_resource_name(resource) == "" then
        ui.notice = "Choose a valid item first."
        return false
    end
    local desired = {}
    for id, quantity in pairs(keep) do desired[id] = quantity end
    desired[tostring(item_id)] = value
    local valid, validation_err = keep_rules.validate(desired)
    if not valid then ui.notice = validation_err; return false end

    local existing_item_rules = preferences.item_rules
    local update_item_rules = item_rule_update ~= nil
    local rules_valid, rules_err = item_rules.validate(existing_item_rules)
    if not rules_valid then ui.notice = rules_err; return false end
    local desired_item_rules = { version=1, items={} }
    for id, rule in pairs((existing_item_rules and existing_item_rules.items) or {}) do
        desired_item_rules.items[id] = { carry_target=rule.carry_target,
            destination=rule.destination, deposit=rule.deposit }
    end
    if item_rule_update ~= nil then
        local id = tostring(item_id)
        if item_rule_update == false then
            desired_item_rules.items[id] = nil
        elseif type(item_rule_update) == "table" then
            local one_item = { version=1, items={ [id]=item_rule_update } }
            local item_valid, item_err = item_rules.validate(one_item)
            local compatible, compatible_err = item_rules.validate_for_item(item_rule_update, {
                item_id=item_id, equippable=is_equipment(resource),
            })
            if not item_valid or not compatible then
                ui.notice = item_err or compatible_err or "Invalid per-item outcome."
                return false
            end
            desired_item_rules.items[id] = { carry_target=item_rule_update.carry_target,
                destination=item_rule_update.destination, deposit=item_rule_update.deposit }
        else
            ui.notice = "Invalid per-item outcome. Nothing was applied."
            return false
        end
    end
    local item_rules_valid, item_rules_err = item_rules.validate(desired_item_rules)
    if not item_rules_valid then ui.notice = item_rules_err; return false end

    local background
    if automatic_allowed ~= nil then
        if type(automatic_allowed) ~= "boolean" or not housekeeping.validate(preferences.background) then
            ui.notice = "Automatic item settings are invalid. Nothing was applied."
            return false
        end
        local current = preferences.background
        background = { enabled=current.enabled, free_slots=current.free_slots, items={} }
        for id, allowed in pairs(current.items) do background.items[id] = allowed end
        background.items[tostring(item_id)] = automatic_allowed
    end

    cancel_queues("Item rules updated; active work stopped. View Plan or start a new deposit to continue. No addon reload needed.")
    local requested_background = background or preferences.background
    preferences.keep = desired
    if update_item_rules then preferences.item_rules = desired_item_rules end
    if background then preferences.background = background end
    local saved_ok, saved = pcall(settings.save)
    local loaded_ok, loaded = false, false
    if saved_ok and saved == true then loaded_ok, loaded = pcall(settings.reload) end
    local actual = current_keep_rules()
    local matched = loaded_ok and loaded == true and actual ~= nil
    if matched then
        for id, quantity in pairs(desired) do
            if actual[id] ~= quantity then matched = false end
        end
        for id, quantity in pairs(actual) do
            if desired[id] ~= quantity then matched = false end
        end
        if background then
            local stored = preferences.background
            if not housekeeping.validate(stored) or stored.enabled ~= background.enabled
                or stored.free_slots ~= background.free_slots then
                matched = false
            else
                for id, allowed in pairs(background.items) do if stored.items[id] ~= allowed then matched = false end end
                for id, allowed in pairs(stored.items) do if background.items[id] ~= allowed then matched = false end end
            end
        end
        if update_item_rules then
            matched = matched and item_rules.signature(preferences.item_rules) == item_rules.signature(desired_item_rules)
        end
    end
    if not matched then
        -- Retain the requested protection for this session; do not claim it persisted.
        if type(preferences) == "table" then
            preferences.keep = desired
            if update_item_rules then preferences.item_rules = desired_item_rules end
            if background then preferences.background = requested_background end
        end
        ui.notice = "Rule applies this session, but could not be saved. Check Ashita's config folder."
        say(ui.notice)
        return false
    end
    ui.notice = "Saved for this character. Queued work stopped; protections apply to sorting and deposits."
    ui.selected_item_id = item_id
    return true
end

local function handle_keep(args)
    if args[3] == nil or string.lower(args[3]) == "list" then
        local keep, err = current_keep_rules()
        if not keep then say(err); return end
        local count = 0
        for id, quantity in pairs(keep) do
            local name = first_resource_name(AshitaCore:GetResourceManager():GetItemById(tonumber(id)))
            say(("%s [%s]: keep %s"):format(name, id, tostring(quantity)))
            count = count + 1
        end
        if count == 0 then say("No item protections set. Open /oddorg and choose Item rules.") end
        return
    end
    local id = tonumber(args[3])
    local text = string.lower(args[4] or "")
    local value = text == "all" and "all" or tonumber(text)
    if not id or id ~= math.floor(id) or id < 1 or id > 65535
        or (value == nil and text ~= "clear") or #args ~= 4 then
        say("usage: /oddorg keep <item ID> all|<quantity>|clear, or /oddorg keep list")
        return
    end
    set_keep_rule(id, value)
    say(ui.notice or "Item protection updated.")
end

local function ephemeral_units_for_item(item_id, quantity)
    local info = EPHEMERAL_ITEMS[tonumber(item_id) or 0]
    if info == nil then
        return 0
    end
    return (tonumber(quantity) or 0) * info.unit_value
end

local function get_target_by_index(index)
    local memory_manager = AshitaCore:GetMemoryManager()
    local entity_manager = memory_manager and memory_manager:GetEntity() or nil
    if entity_manager == nil then
        return nil, "target resources unavailable"
    end
    if index <= 0 then
        return nil, "target an Ephemeral Moogle first"
    end

    local name = safe_call("", function() return entity_manager:GetName(index) end) or ""
    local server_id = tonumber(safe_call(0, function() return entity_manager:GetServerId(index) end)) or 0
    local party = memory_manager:GetParty()
    local player_index = tonumber(safe_call(nil, function() return party:GetMemberTargetIndex(0) end))
    local zone = tonumber(safe_call(nil, function() return party:GetMemberZone(0) end))
    local distance = safe_call(nil, function()
        if not player_index or player_index <= 0 then return nil end
        local dx = entity_manager:GetLocalPositionX(index) - entity_manager:GetLocalPositionX(player_index)
        local dy = entity_manager:GetLocalPositionY(index) - entity_manager:GetLocalPositionY(player_index)
        local dz = entity_manager:GetLocalPositionZ(index) - entity_manager:GetLocalPositionZ(player_index)
        return math.sqrt(dx * dx + dy * dy + dz * dz)
    end)

    return {
        index = index,
        name = name,
        server_id = server_id,
        distance = distance,
        zone = zone,
    }, nil
end

local function nearby_moogle()
    local entity = AshitaCore:GetMemoryManager():GetEntity()
    local size = tonumber(safe_call(nil, function() return entity:GetEntityMapSize() end))
    if not size or size < 1 or size > 65536 then return nil end
    local closest
    for index=1, size-1 do
        if string.lower(safe_call("", function() return entity:GetName(index) end) or "") == "ephemeral moogle" then
            local candidate = get_target_by_index(index)
            if candidate and candidate.server_id > 0 and candidate.zone and candidate.zone > 0
                and candidate.distance and candidate.distance <= 6
                and (not closest or candidate.distance < closest.distance) then closest = candidate end
        end
    end
    return closest
end

local function get_current_target()
    local memory_manager = AshitaCore:GetMemoryManager()
    local target_manager = memory_manager and memory_manager:GetTarget() or nil
    if target_manager == nil then
        return nil, "target resources unavailable"
    end

    local index = safe_call(0, function()
        if target_manager:GetIsSubTargetActive() > 0 then
            return target_manager:GetTargetIndex(1)
        end
        return target_manager:GetTargetIndex(0)
    end) or 0
    return get_target_by_index(index)
end

local function validate_ephemeral_target()
    local expected = ephemeral.running and ephemeral.target or nil
    local target, err
    if expected ~= nil then
        target, err = get_target_by_index(tonumber(expected.index) or 0)
    else
        target, err = get_current_target()
        if not target or string.lower(target.name or "") ~= "ephemeral moogle"
            or not target.distance or target.distance > 6 then
            target = nearby_moogle()
            err = "Move within 6 yalms of an Ephemeral Moogle to deposit."
        end
    end
    if target == nil then
        return nil, err
    end

    local target_name = string.lower(tostring(target.name or ""))
    if target_name ~= "ephemeral moogle" then
        return nil, "target is not an Ephemeral Moogle"
    end
    if target.server_id <= 0 then
        return nil, "Ephemeral Moogle identity is unavailable"
    end
    if not target.zone or target.zone <= 0 then
        return nil, "Ephemeral Moogle zone is unavailable or changed"
    end
    if expected ~= nil
        and (target.server_id ~= expected.server_id or target.zone ~= expected.zone
            or tostring(target.name) ~= tostring(expected.name)) then
        return nil, "saved Ephemeral Moogle identity changed"
    end
    if target.distance == nil or target.distance ~= target.distance then
        return nil, "Ephemeral Moogle distance is unavailable"
    end
    if target.distance > 6.0 then
        return nil, ("Ephemeral Moogle is too far away %.2f/6.00"):format(target.distance)
    end

    return target, nil
end

local function ephemeral_scope_allows(scope, container_id)
    if scope == "all" then
        return true
    end
    if scope == "inventory" then
        return container_id == INVENTORY_CONTAINER_ID
    end
    return container_id ~= INVENTORY_CONTAINER_ID
end

local function item_deposit_allowed(item, automatic_run)
    local rule, rule_err = item_rules.for_item(preferences.item_rules, item.item_id)
    if rule_err then return false end
    if rule then
        return rule.deposit == true and item.container_id ~= 2
            and (item.container_id == INVENTORY_CONTAINER_ID or item.container_id == rule.destination)
    end
    if not automatic_run then return true end
    return item.container_id ~= 2
        and housekeeping.allowed(preferences.background, item.item_id)
        and storage_layout.effective_allowed(preferences.storage_layout, preferences.background, item)
end

local function ephemeral_sort_candidates(candidates)
    table.sort(candidates, function(left, right)
        local left_info = EPHEMERAL_ITEMS[left.item_id]
        local right_info = EPHEMERAL_ITEMS[right.item_id]
        local left_unit = tonumber(left_info and left_info.unit_value) or 0
        local right_unit = tonumber(right_info and right_info.unit_value) or 0
        if left_unit ~= right_unit then
            return left_unit > right_unit
        end
        local left_name = string.lower(left.item_name or "")
        local right_name = string.lower(right.item_name or "")
        if left_name ~= right_name then
            return left_name < right_name
        end
        if left.container_id ~= right.container_id then
            if left.container_id == INVENTORY_CONTAINER_ID then
                return true
            end
            if right.container_id == INVENTORY_CONTAINER_ID then
                return false
            end
            return left.container_id < right.container_id
        end
        return left.index < right.index
    end)
end

local function ephemeral_action_id(prefix, item, suffix)
    return ("%s-%s-%02u-%03u-%s"):format(prefix, item.item_id, item.container_id, item.index, suffix)
end

local function build_ephemeral_dump_queue(options)
    local snapshot, _, err = collect_live_items()
    if snapshot == nil then
        return nil, nil, err
    end

    local reservations, reservation_err, refill_reserved = get_keep_reservations(snapshot)
    if reservations == nil then
        return nil, nil, reservation_err or "keep reservations unavailable"
    end

    local candidates = {}
    local carried_reserves = {}
    for _, item in ipairs(snapshot.items) do
        if item.container_id == INVENTORY_CONTAINER_ID then
            carried_reserves[item.item_id] = (carried_reserves[item.item_id] or 0)
                + (reservations[item_key(item.container_id, item.index)] or 0)
        end
    end
    local summary = {
        items = 0,
        stage_moves = 0,
        trades = 0,
        units = 0,
        kept_quantity = 0,
        skipped_locked = 0,
        by_element = {},
    }

    for _, item in ipairs(snapshot.items) do
        local info = EPHEMERAL_ITEMS[item.item_id]
        if info ~= nil and item.quantity > 0 and ephemeral_scope_allows(options.scope, item.container_id)
            and item_deposit_allowed(item, options.automatic) then
            local key = item_key(item.container_id, item.index)
            local protected = (tonumber(reservations[key]) or 0) + (tonumber(refill_reserved[key]) or 0)
            local reserved = math.max(0, math.min(item.quantity, protected))
            summary.kept_quantity = summary.kept_quantity + reserved
            if item.container_id == INVENTORY_CONTAINER_ID and bit.band(tonumber(item.flags) or 0, 1) ~= 0 then
                summary.skipped_locked = summary.skipped_locked + 1
                write_probe("ephemeral_skip_locked", "REJECT", item.item_name, ("Inventory[%u]"):format(item.index))
            elseif reserved < item.quantity then
                local candidate = {}
                for key, value in pairs(item) do
                    candidate[key] = value
                end
                candidate.quantity = item.quantity - reserved
                table.insert(candidates, candidate)
            end
        end
    end

    ephemeral_sort_candidates(candidates)

    local queue = {}
    local character_slug = options.character_slug

    local function make_trade_action(item)
        local info = EPHEMERAL_ITEMS[item.item_id]
        local units = ephemeral_units_for_item(item.item_id, item.quantity)
        local base_id = ephemeral_action_id("ephemeral", item, info.kind)
        return {
            kind = "trade",
            move_id = base_id .. "-trade",
            character_slug = character_slug,
            item_id = item.item_id,
            quantity = item.quantity,
            source_container_id = INVENTORY_CONTAINER_ID,
            source_index = item.container_id == INVENTORY_CONTAINER_ID and item.index or 0,
            carried_reserve = carried_reserves[item.item_id] or 0,
            item_name = item.item_name,
            stack_size = item.stack_size,
            element = info.element,
            item_kind = info.kind,
            units = units,
        }
    end

    local function count_item(item)
        local info = EPHEMERAL_ITEMS[item.item_id]
        local units = ephemeral_units_for_item(item.item_id, item.quantity)
        summary.items = summary.items + 1
        summary.trades = summary.trades + 1
        summary.units = summary.units + units
        summary.by_element[info.element] = (summary.by_element[info.element] or 0) + units
    end

    local inventory_candidates = {}
    local storage_candidates = {}
    for _, item in ipairs(candidates) do
        if item.container_id == INVENTORY_CONTAINER_ID then
            table.insert(inventory_candidates, item)
        else
            table.insert(storage_candidates, item)
        end
    end

    for _, item in ipairs(inventory_candidates) do
        table.insert(queue, make_trade_action(item))
        count_item(item)
    end

    for _, item in ipairs(storage_candidates) do
        local info = EPHEMERAL_ITEMS[item.item_id]
        local units = ephemeral_units_for_item(item.item_id, item.quantity)
        local base_id = ephemeral_action_id("ephemeral", item, info.kind)
        local trade_action = make_trade_action(item)
        trade_action.source_index = 0
        local stage_move = {
            move_id = base_id .. "-stage",
            character_slug = character_slug,
            item_id = item.item_id,
            quantity = item.quantity,
            source_container_id = item.container_id,
            source_index = item.index,
            target_container_id = INVENTORY_CONTAINER_ID,
            item_name = item.item_name,
            stack_size = item.stack_size,
        }
        table.insert(queue, {
            kind = "stage",
            move_id = stage_move.move_id,
            stage_move = stage_move,
            trade_move_id = trade_action.move_id,
            item_name = item.item_name,
            quantity = item.quantity,
            units = units,
        })
        table.insert(queue, trade_action)
        summary.stage_moves = summary.stage_moves + 1
        count_item(item)
    end

    write_probe(
        "ephemeral_plan_done",
        "OK",
        "ephemeral dump queue built",
        ("scope=%s items=%u stage=%u trades=%u units=%u kept=%u cap_per_element=%u skipped_locked=%u"):format(
            options.scope,
            summary.items,
            summary.stage_moves,
            summary.trades,
            summary.units,
            summary.kept_quantity,
            EPHEMERAL_UNIT_CAP,
            summary.skipped_locked
        )
    )

    return queue, summary, nil
end

local function wait_for_ephemeral_inventory_stage(now)
    if ephemeral.awaiting_inventory == nil then
        return true
    end

    local waiting = ephemeral.awaiting_inventory
    local status, observation_message = check_move_observation(waiting.observation)
    if status == "confirmed" then
        ephemeral.confirmed_transfers = (ephemeral.confirmed_transfers or 0) + 1
        -- A retrieved quantity may merge into several carried stacks. Resolve
        -- the actual trade slots together once the batch has finished staging.
        write_probe(
            "ephemeral_inventory_stage_visible",
            "OK",
            "staged item is visible in Inventory",
            ("%s quantity=%u"):format(waiting.trade_move_id, waiting.quantity)
        )
        ephemeral.awaiting_inventory = nil
        ephemeral.cursor = waiting.next_cursor
        return true
    end
    if status == "failed" then
        ephemeral.running = false
        ephemeral.error = "staged transfer unconfirmed: " .. tostring(observation_message or "inventory did not change")
        local details = ("%s x%u stage=%s"):format(waiting.item_name, waiting.quantity, waiting.stage_move_id)
        write_audit(waiting.trade_move_id, "REJECT", ephemeral.error, details)
        write_probe("ephemeral_inventory_stage_timeout", "REJECT", ephemeral.error, details)
        say("ephemeral dump stopped with an unconfirmed staged transfer; it will not resend: " .. waiting.item_name)
        return false
    end

    if waiting.last_probe == 0 or (now - waiting.last_probe) >= 1.0 then
        waiting.last_probe = now
        write_probe(
            "ephemeral_wait_inventory",
            "WAIT",
            "staged item not visible yet",
            ("%s x%u"):format(waiting.item_name, waiting.quantity)
        )
    end
    return false
end

local function validate_ephemeral_trade_action(action)
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    local resources = AshitaCore:GetResourceManager()
    if inv == nil or resources == nil then
        return false, "inventory resources unavailable", ""
    end

    if EPHEMERAL_ITEMS[action.item_id] == nil then
        return false, "item is not an Ephemeral Moogle crystal or cluster", tostring(action.item_id)
    end

    if action.quantity <= 0 then
        return false, "quantity must be positive", tostring(action.quantity)
    end

    if not action.source_index or action.source_index < 1 then
        return false, "inventory trade slot was not allocated", action.item_name
    end

    local item = get_container_item(inv, INVENTORY_CONTAINER_ID, action.source_index)
    if not is_real_item(item) then
        return false, "source inventory slot is empty", tostring(action.source_index)
    end
    if tonumber(item.Id) ~= action.item_id then
        return false, "source item id mismatch", ("expected=%u actual=%u"):format(action.item_id, tonumber(item.Id) or 0)
    end
    if tonumber(item.Count) < action.quantity then
        return false, "source quantity too small", ("expected=%u actual=%u"):format(action.quantity, tonumber(item.Count) or 0)
    end
    if bit.band(tonumber(item.Flags) or 0, 1) ~= 0 then
        return false, "source inventory item is locked", tostring(action.source_index)
    end

    local resource = resources:GetItemById(item.Id)
    if not resource_name_matches(resource, action.item_name) then
        return false, "source item name mismatch", action.item_name
    end

    return true, "validated ephemeral trade", ("Inventory[%u] %s x%u units=%u"):format(
        action.source_index,
        action.item_name,
        action.quantity,
        action.units
    )
end

local function send_ephemeral_trade_packet(target, entries)
    local quantities = {}
    local indices = {}
    for index = 1, 10, 1 do
        quantities[index] = 0
        indices[index] = 0
    end

    for index, entry in ipairs(entries) do
        quantities[index] = entry.quantity
        indices[index] = entry.source_index
    end

    local packet = struct.pack('IIIIIIIIIIIIBBBBBBBBBBHBBBB',
        0,
        target.server_id,
        quantities[1],
        quantities[2],
        quantities[3],
        quantities[4],
        quantities[5],
        quantities[6],
        quantities[7],
        quantities[8],
        quantities[9],
        quantities[10],
        indices[1],
        indices[2],
        indices[3],
        indices[4],
        indices[5],
        indices[6],
        indices[7],
        indices[8],
        indices[9],
        indices[10],
        target.index,
        #entries,
        0,
        0,
        0):totable()
    AshitaCore:GetPacketManager():AddOutgoingPacket(EPHEMERAL_TRADE_PACKET_ID, packet)
end

-- Queue entries are quantity requests, not physical trades: batching can combine
-- several requests or split one across Inventory slots. Report units separately.
function ephemeral.progress()
    local crystals, clusters, transfers = 0, 0, 0
    local confirmed = {}
    local waiting = ephemeral.awaiting_trade
    if waiting and waiting.confirmed_at then
        for _, consumed in ipairs(waiting.consumed or {}) do
            confirmed[consumed.action] = (confirmed[consumed.action] or 0) + consumed.quantity
        end
    end
    for index=ephemeral.cursor, #ephemeral.queue do
        local action = ephemeral.queue[index]
        if action.kind == "stage" then
            transfers = transfers + 1
        elseif action.kind == "trade" then
            local quantity = math.max(0,action.quantity-(confirmed[action] or 0))
            local info = EPHEMERAL_ITEMS[action.item_id]
            if info and info.kind == "cluster" then clusters = clusters + quantity
            else crystals = crystals + quantity end
        end
    end
    local text = ("To deposit: %u crystals, %u clusters\nBag transfers remaining: %u")
        :format(crystals,clusters,transfers)
    if waiting then
        text = text .. (waiting.confirmed_at and "\nDeposit confirmed; finishing animation."
            or "\nWaiting for deposit confirmation.")
    elseif ephemeral.awaiting_inventory then text = text .. "\nRetrieving from storage." end
    return text, crystals + clusters * 12
end

local function build_ephemeral_trade_batch(start_cursor)
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    if not inv then return nil, start_cursor, "inventory unavailable", "" end
    local capacity = get_container_capacity(inv, INVENTORY_CONTAINER_ID)
    local available_by_item, planned_by_item, seen_ids = {}, {}, {}
    local end_cursor = start_cursor

    -- Ready actions are quantity budgets, not fixed Inventory slots: staging
    -- can merge or split stacks. Keep each original request distinct while
    -- resolving its budget against current, unlocked surplus.
    while end_cursor <= #ephemeral.queue do
        local action = ephemeral.queue[end_cursor]
        if action.kind ~= "trade" then break end
        if seen_ids[action.move_id] or EPHEMERAL_ITEMS[action.item_id] == nil or action.quantity <= 0 then
            return nil, end_cursor, "invalid or duplicate crystal trade request", tostring(action.move_id)
        end
        seen_ids[action.move_id] = true
        local item_id = action.item_id
        if not available_by_item[item_id] then
            local surplus, err = get_carried_surplus(item_id, action.carried_reserve)
            local total = container_item_count(INVENTORY_CONTAINER_ID, item_id)
            if surplus == nil or total == nil then
                return nil, end_cursor, err or "protected carried surplus unavailable", tostring(item_id)
            end
            local reserved = math.max(0, total - surplus)
            local stock = { slots={}, quantity=0 }
            for index = 1, capacity do
                local item = get_container_item(inv, INVENTORY_CONTAINER_ID, index)
                if is_real_item(item) and tonumber(item.Id) == item_id then
                    local count = tonumber(item.Count) or 0
                    local kept = math.min(reserved, count)
                    reserved = reserved - kept
                    if count > kept and bit.band(tonumber(item.Flags) or 0, 1) == 0 then
                        stock.slots[#stock.slots + 1] = { index=index, quantity=count-kept }
                        stock.quantity = stock.quantity + count-kept
                    end
                end
            end
            available_by_item[item_id] = stock
        end
        planned_by_item[item_id] = (planned_by_item[item_id] or 0) + action.quantity
        if planned_by_item[item_id] > available_by_item[item_id].quantity then
            return nil, end_cursor, "trade batch exceeds unlocked protected carried surplus", tostring(item_id)
        end
        end_cursor = end_cursor + 1
    end

    local entries = {}
    local ids = {}
    local units = 0
    local cursor = start_cursor
    local by_slot, consumed = {}, {}

    while cursor < end_cursor do
        local action = ephemeral.queue[cursor]
        local remaining = action.quantity
        for _, slot in ipairs(available_by_item[action.item_id].slots) do
            if remaining == 0 then break end
            local entry = by_slot[slot.index]
            if slot.quantity > 0 and (entry or #entries < EPHEMERAL_TRADE_BATCH_SIZE) then
                local quantity = math.min(remaining, slot.quantity)
                if not entry then
                    entry = {}
                    for key, value in pairs(action) do entry[key] = value end
                    entry.source_index, entry.quantity, entry.units = slot.index, 0, 0
                    entries[#entries + 1] = entry
                    by_slot[slot.index] = entry
                end
                entry.quantity = entry.quantity + quantity
                entry.units = ephemeral_units_for_item(action.item_id, entry.quantity)
                slot.quantity = slot.quantity - quantity
                remaining = remaining - quantity
            end
        end
        local quantity = action.quantity - remaining
        if quantity > 0 then
            consumed[#consumed + 1] = { action=action, quantity=quantity }
            ids[#ids + 1] = action.move_id
            units = units + ephemeral_units_for_item(action.item_id, quantity)
        end
        if remaining > 0 then break end
        cursor = cursor + 1
    end

    if #entries == 0 then
        return nil, start_cursor, "no trade entries available", tostring(start_cursor)
    end
    for _, entry in ipairs(entries) do
        local ok, message, details = validate_ephemeral_trade_action(entry)
        if not ok then return nil, start_cursor, message, details end
    end

    return {
        entries = entries,
        move_id = table.concat(ids, ","),
        next_cursor = cursor,
        consumed = consumed,
        stage_cursor = end_cursor,
        units = units,
    }, cursor, nil, nil
end

local function wait_for_ephemeral_trade_confirmation()
    local waiting = ephemeral.awaiting_trade
    if waiting == nil then
        return true
    end

    local all_confirmed = true
    local any_changed = false
    for item_id, expected in pairs(waiting.expected_by_item) do
        local current = container_item_count(INVENTORY_CONTAINER_ID, item_id)
        if current == nil then
            all_confirmed = false
        else
            if current < waiting.before_by_item[item_id] then
                any_changed = true
            end
            if current > waiting.before_by_item[item_id] - expected then
                all_confirmed = false
            end
        end
    end
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    if not inv then all_confirmed = false end
    for _, source in ipairs(waiting.sources) do
        local slot = inv and get_container_item(inv, INVENTORY_CONTAINER_ID, source.index)
        local count = is_real_item(slot) and tonumber(slot.Id) == source.item_id and tonumber(slot.Count) or 0
        if count > source.before - source.quantity then all_confirmed = false end
    end

    if all_confirmed and waiting.confirmed_at == nil then
        waiting.confirmed_at = os.time()
        ephemeral.confirmed_batches = (ephemeral.confirmed_batches or 0) + 1
        write_probe("ephemeral_trade_confirmed", "OK", "Inventory decrement observed", waiting.move_id)
    end

    if waiting.confirmed_at == nil and os.time() >= waiting.animation_wait_until + 5 then
        ephemeral.running = false
        ephemeral.error = any_changed
            and "ephemeral trade partially observed; result unconfirmed"
            or "ephemeral trade unconfirmed; Inventory did not decrease"
        write_audit(waiting.move_id, "REJECT", ephemeral.error, "no resend")
        write_probe("ephemeral_trade_timeout", "REJECT", ephemeral.error, "no resend")
        say("ephemeral dump stopped with a partial or unconfirmed deposit; it will not resend.")
        return false
    end

    local animation_remaining = waiting.animation_wait_until - os.time()
    if waiting.confirmed_at == nil or animation_remaining > 0 then
        if waiting.last_probe == 0 or os.time() - waiting.last_probe >= 1 then
            waiting.last_probe = os.time()
            write_probe(
                "ephemeral_trade_wait",
                "WAIT",
                waiting.confirmed_at and "deposit confirmed; waiting for animation" or "waiting for observed Inventory decrement",
                ("%s animation_remaining=%u"):format(waiting.move_id, math.max(0, animation_remaining))
            )
        end
        return false
    end

    -- Commit the quantity budget only after the observed deposit and animation.
    -- A request split at the eight-slot boundary retains its unsent remainder.
    for _, consumed in ipairs(waiting.consumed or {}) do
        local action = consumed.action
        action.quantity = action.quantity - consumed.quantity
        action.units = ephemeral_units_for_item(action.item_id, action.quantity)
    end
    ephemeral.cursor = waiting.next_cursor
    ephemeral.awaiting_trade = nil
    ephemeral.animation_wait_until = nil
    ephemeral.animation_wait_last_probe = 0
    return true
end

local function stop_ephemeral(message)
    settle_pending_actions()
    ephemeral.running = false
    ephemeral.error = message
    ephemeral.awaiting_inventory = nil
    ephemeral.awaiting_trade = nil
    ephemeral.animation_wait_until = nil
    ephemeral.animation_wait_last_probe = 0
end

local function handle_ephemeral(args, automatic_target)
    if args[3] == "dump" or args[3] == "status" or args[3] == "stop" then
        -- Explicit verbs remain visible for static safety tests and operator trust.
    end

    local action = string.lower(args[3] or "status")
    if not automatic_target and action == "dump" then
        ui.visible, ui.page, ui.settings_tab, ui.scope = true, "settings", "bulk", "crystals"
    end

    if action == "stop" then
        automatic.paused = true
        automatic.status = "Background clearing paused. Resume background when ready."
        stop_ephemeral(nil)
        write_probe("ephemeral_queue_stop", "OK", "stopped by command", "cursor=" .. tostring(ephemeral.cursor))
        say("ephemeral dump stopped.")
        return
    end

    if action == "status" then
        local progress = ephemeral.progress():gsub("\n", " | ")
        say("ephemeral running=" .. tostring(ephemeral.running) .. "; " .. progress)
        write_probe("ephemeral_queue_status", "OK", "status requested", progress)
        return
    end

    if action ~= "dump" then
        say("usage: /oddorg ephemeral dump|stop|status [all|inventory|storage] [probes|noprobes] [delay=0.8]")
        return
    end

    if organizer.running then
        local message = "organizer running; stop it before ephemeral dump"
        write_probe("ephemeral_queue_start", "REJECT", message, "")
        print(chat.header("OddOrg") .. chat.error(message))
        return
    end

    if ephemeral.running then
        say("ephemeral dump is already running.")
        return
    end
    local ready, ready_err = new_run_ready()
    if not ready then say(ready_err); return end

    local options = {
        scope = "all",
        character_slug = get_player_slug(),
        automatic = automatic_target ~= nil,
    }

    for index = 4, #args, 1 do
        local value = string.lower(args[index] or "")
        if value == "all" or value == "inventory" then
            options.scope = value
        elseif value == "storage" or value == "mog" or value == "bags" then
            options.scope = "storage"
        elseif value == "noprobes" then
            set_probes_enabled(false)
        elseif value == "probes" then
            set_probes_enabled(true)
        elseif value:match("^delay=") ~= nil then
            local parsed = tonumber(value:match("^delay=(.+)$"))
            if parsed ~= nil and parsed > 0 then
                ephemeral.delay = parsed
            end
        end
    end

    local target, target_err
    if automatic_target then target = automatic_target else target, target_err = validate_ephemeral_target() end
    if target == nil then
        write_probe("ephemeral_target", "REJECT", target_err, "")
        print(chat.header("OddOrg") .. chat.error(target_err or "invalid Ephemeral Moogle target"))
        return
    end

    local queue, summary, queue_err = build_ephemeral_dump_queue(options)
    if queue == nil then
        write_probe("ephemeral_plan_done", "REJECT", queue_err, options.scope)
        print(chat.header("OddOrg") .. chat.error(queue_err or "ephemeral dump plan failed"))
        return
    end

    if #queue == 0 then
        write_probe("ephemeral_queue_start", "OK", "no crystals or clusters found", options.scope)
        if not automatic_target then say("no crystals or clusters found for ephemeral dump.") end
        return false, "empty"
    end

    ephemeral.running = true
    ephemeral.automatic = automatic_target ~= nil
    ephemeral.queue = queue
    ephemeral.cursor = 1
    ephemeral.last_send = 0
    ephemeral.scope = options.scope
    ephemeral.character_slug = options.character_slug
    ephemeral.started_at = os.clock()
    ephemeral.error = nil
    ephemeral.target = target
    ephemeral.summary = summary
    ephemeral.confirmed_transfers, ephemeral.confirmed_batches = 0, 0
    ephemeral.awaiting_inventory = nil
    ephemeral.awaiting_trade = nil
    ephemeral.awaiting_trade = nil
    ephemeral.animation_wait_until = nil
    ephemeral.animation_wait_last_probe = 0
    write_probe(
        "ephemeral_queue_start",
        "OK",
        "ephemeral dump queue started",
        ("scope=%s queue=%u trades=%u stage=%u units=%u cap_per_element=%u target=%u batch_size=%u animation_wait=%u"):format(
            options.scope,
            #queue,
            summary.trades,
            summary.stage_moves,
            summary.units,
            EPHEMERAL_UNIT_CAP,
            target.server_id,
            EPHEMERAL_TRADE_BATCH_SIZE,
            EPHEMERAL_TRADE_ANIMATION_DELAY
        )
    )
    if not automatic_target then say(("ephemeral dump started: stacks=%u stage=%u units=%u max_batch=%u animation_wait=%us delay=%.2fs"):format(
        summary.trades,
        summary.stage_moves,
        summary.units,
        EPHEMERAL_TRADE_BATCH_SIZE,
        EPHEMERAL_TRADE_ANIMATION_DELAY,
        ephemeral.delay
    )) end
    return true, "started"
end

local function run_ephemeral_tick()
    if not ephemeral.running then
        return
    end

    if get_player_slug() ~= ephemeral.character_slug then
        stop_ephemeral("character changed while crystal result was pending")
        write_probe("ephemeral_character", "REJECT", ephemeral.error, "no resend")
        say("ephemeral dump stopped because the character changed; pending work will not be resent.")
        return
    end

    local now = os.clock()

    if not wait_for_ephemeral_inventory_stage(now) then
        return
    end
    if not wait_for_ephemeral_trade_confirmation() then
        return
    end

    if ephemeral.cursor > #ephemeral.queue then
        ephemeral.running = false
        ephemeral.awaiting_inventory = nil
        ephemeral.awaiting_trade = nil
        write_probe("ephemeral_queue_done", "OK", "ephemeral dump queue confirmed complete",
            ("bag_transfers=%u trade_batches=%u"):format(ephemeral.confirmed_transfers or 0,ephemeral.confirmed_batches or 0))
        if not ephemeral.automatic then say("ephemeral dump queue confirmed complete.") end
        return
    end

    if ephemeral.automatic then
        local target, err = validate_ephemeral_target()
        if not target or not automatic.ready() or automatic.paused then
            stop_ephemeral(err or "player activity changed; automatic deposit stopped")
            return
        end
    end

    if ephemeral.last_send ~= 0 and (now - ephemeral.last_send) < ephemeral.delay then
        return
    end

    local action = ephemeral.queue[ephemeral.cursor]
    if action == nil then
        stop_ephemeral("ephemeral queue cursor missing")
        write_probe("ephemeral_queue_step", "REJECT", "queue cursor missing", tostring(ephemeral.cursor))
        return
    end

    local batch, batch_cursor, batch_err, batch_details
    if action.kind == "trade" then
        batch, batch_cursor, batch_err, batch_details = build_ephemeral_trade_batch(ephemeral.cursor)
        local next_stage = batch and ephemeral.queue[batch.stage_cursor]
        if batch and #batch.entries < EPHEMERAL_TRADE_BATCH_SIZE and next_stage and next_stage.kind == "stage" then
            local ok, message = validate_move(next_stage.stage_move)
            if ok then
                -- Pull one retrieval ahead of all ready trades, then observe it
                -- before deciding whether the next stack will fit as well.
                table.remove(ephemeral.queue, batch.stage_cursor)
                table.insert(ephemeral.queue, ephemeral.cursor, next_stage)
                action = next_stage
            elseif message ~= "target container is full" then
                stop_ephemeral(message)
                fail_move(next_stage.move_id, message, "preparing crystal batch")
                return
            end
            -- With no room, deposit what is already carried to free slots.
        end
    end

    if action.kind == "stage" then
        local stage_move = action.stage_move
        local ok, message, details = validate_move(stage_move)
        if not ok then
            stop_ephemeral(message)
            fail_move(stage_move.move_id, message, details)
            say("ephemeral dump stopped on staging reject at " .. tostring(ephemeral.cursor) .. ".")
            return
        end

        local observation, observation_err = capture_move_observation(stage_move)
        if observation == nil then
            stop_ephemeral(observation_err or "cannot observe staged transfer")
            write_probe("ephemeral_queue_step", "REJECT", ephemeral.error, stage_move.move_id)
            say("ephemeral dump stopped before staging because transfer confirmation is unavailable.")
            return
        end
        ephemeral.awaiting_inventory = {
            stage_move_id = stage_move.move_id,
            trade_move_id = action.trade_move_id,
            item_id = stage_move.item_id,
            quantity = stage_move.quantity,
            item_name = stage_move.item_name,
            stack_size = stage_move.stack_size,
            observation = observation,
            next_cursor = ephemeral.cursor + 1,
            last_probe = 0,
        }
        send_move_packet(stage_move)
        write_audit(stage_move.move_id, "SENT", message, details)
        write_probe("ephemeral_queue_step", "SENT", stage_move.move_id,
            ("%u/%u stage %s"):format(ephemeral.cursor, #ephemeral.queue, move_to_command_label(stage_move)))
        write_probe(
            "ephemeral_wait_inventory",
            "OK",
            "waiting for staged crystal or cluster in Inventory",
            ("%s -> %s %s x%u"):format(stage_move.move_id, action.trade_move_id, stage_move.item_name, stage_move.quantity)
        )
        ephemeral.last_send = now
        return
    end

    if action.kind ~= "trade" then
        stop_ephemeral("unknown ephemeral queue action")
        write_probe("ephemeral_queue_step", "REJECT", "unknown action", tostring(action.kind))
        return
    end

    local target, target_err = validate_ephemeral_target()
    if target == nil then
        stop_ephemeral(target_err)
        write_audit(action.move_id, "REJECT", target_err, "target")
        write_probe("ephemeral_target", "REJECT", target_err, "")
        say("ephemeral dump stopped: " .. tostring(target_err))
        return
    end

    if batch == nil then
        stop_ephemeral(batch_err)
        write_audit(action.move_id, "REJECT", batch_err, batch_details)
        write_probe("ephemeral_queue_step", "REJECT", batch_err, batch_details)
        say("ephemeral dump stopped on trade reject at " .. tostring(ephemeral.cursor) .. ".")
        return
    end

    local before_by_item = {}
    local expected_by_item = {}
    local sources = {}
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    for _, entry in ipairs(batch.entries) do
        local item_id = tonumber(entry.item_id) or 0
        expected_by_item[item_id] = (expected_by_item[item_id] or 0) + entry.quantity
        local slot = inv and get_container_item(inv, INVENTORY_CONTAINER_ID, entry.source_index)
        if not is_real_item(slot) or tonumber(slot.Id) ~= item_id or tonumber(slot.Count) < entry.quantity then
            stop_ephemeral("source slot changed before deposit")
            say(ephemeral.error)
            return
        end
        sources[#sources + 1] = { index=entry.source_index, item_id=item_id,
            before=tonumber(slot.Count), quantity=entry.quantity }
    end
    for item_id in pairs(expected_by_item) do
        local count = container_item_count(INVENTORY_CONTAINER_ID, item_id)
        if count == nil then
            stop_ephemeral("cannot observe Inventory before crystal deposit")
            write_probe("ephemeral_queue_step", "REJECT", ephemeral.error, tostring(item_id))
            say("ephemeral dump stopped before deposit because confirmation is unavailable.")
            return
        end
        before_by_item[item_id] = count
    end

    ephemeral.awaiting_trade = {
        move_id = batch.move_id,
        before_by_item = before_by_item,
        expected_by_item = expected_by_item,
        sources = sources,
        next_cursor = batch.next_cursor,
        consumed = batch.consumed,
        started_at = os.time(),
        animation_wait_until = os.time() + EPHEMERAL_TRADE_ANIMATION_DELAY,
        confirmed_at = nil,
        last_probe = 0,
    }
    send_ephemeral_trade_packet(target, batch.entries)
    for _, entry in ipairs(batch.entries) do
        write_audit(
            entry.move_id,
            "SENT",
            "sent ephemeral trade batch",
            ("Inventory[%u] %s x%u units=%u batch_size=%u"):format(
                entry.source_index,
                entry.item_name,
                entry.quantity,
                entry.units,
                #batch.entries
            )
        )
    end
    write_probe(
        "ephemeral_queue_step",
        "SENT",
        batch.move_id,
        ("%u/%u trade_batch stacks=%u units=%u wait=%us"):format(
            ephemeral.cursor,
            #ephemeral.queue,
            #batch.entries,
            batch.units,
            EPHEMERAL_TRADE_ANIMATION_DELAY
        )
    )
    ephemeral.animation_wait_until = ephemeral.awaiting_trade.animation_wait_until
    ephemeral.animation_wait_last_probe = 0
    ephemeral.last_send = now
end

local function run_organizer_tick()
    if not organizer.running then
        return
    end

    if organizer.awaiting_move then
        local observation = organizer.awaiting_move
        local state, message, details = check_move_observation(observation)
        if state == "pending" then return end
        organizer.awaiting_move = nil
        if state == "failed" then
            organizer.running = false
            organizer.error = ("Stopped at %u/%u: %s. %s")
                :format(organizer.cursor, #organizer.queue, move_to_command_label(observation.move), message)
            write_probe("queue_step", "REJECT", organizer.error, observation.move.move_id .. "; " .. (details or ""))
            say("Organization " .. organizer.error)
            return
        end
        organizer.cursor = organizer.cursor + 1
        -- Start the quiet interval when the move is observed, so delayed
        -- replies cannot cause the next transfer in this same frame.
        organizer.next_send_at = os.clock() + organizer.delay
    end

    if organizer.cursor > #organizer.queue then
        -- Wait through the post-confirmation quiet interval before reading bags.
        if os.clock() < organizer.next_send_at then return end
        if not organizer.options then
            organizer.running = false
            organizer.awaiting_inventory = nil
            write_probe("queue_done", "OK", "single requested move complete", "sent="..#organizer.queue)
            say("requested move complete.")
            return
        end
        local completed = organizer.completed_transfers + #organizer.queue
        if organizer.batch_limited or completed >= 50 then
            organizer.running = false
            organizer.completed_transfers = completed
            ui.bulk_preview_ready, ui.bulk_preview_displayed = nil, nil
            ui.bulk_result = ("Batch finished: %u transfers. View Plan to check remaining work."):format(completed)
            say(ui.bulk_result)
            return
        end
        local plan, queue, err = build_preview_or_queue(organizer.options, 50-completed)
        if not plan then
            organizer.running = false
            organizer.error = "Final organization check failed: " .. tostring(err)
            write_probe("queue_recheck", "REJECT", organizer.error, "pass="..organizer.pass)
            say(organizer.error)
            return
        end
        organizer.completed_transfers = organizer.completed_transfers + #organizer.queue
        ui.preview_plan = plan
        if #queue == 0 then
            organizer.running = false
            organizer.awaiting_inventory = nil
            if (plan.default_blocked or 0) > 0 then
                ui.bulk_result=("Organization stopped: %u stacks have full or unavailable default homes; left in place."):format(plan.default_blocked)
                write_probe("queue_done","BLOCKED",ui.bulk_result,"default storage capacity")
                say(ui.bulk_result)
                return
            end
            write_probe("queue_done", "OK", "fresh plan confirms no remaining moves",
                ("sent=%u passes=%u"):format(organizer.completed_transfers,organizer.pass))
            ui.bulk_result = ("Organization complete: %u transfers; no remaining moves."):format(organizer.completed_transfers)
            say("organizer complete: no remaining moves in the selected scope.")
            return
        end
        local signature = organization_state_signature(plan.snapshot)
        if organizer.seen_states[signature] or organizer.pass >= 16 then
            organizer.running = false
            organizer.error = organizer.seen_states[signature]
                and "Organization stopped: a bag state repeated; remaining moves were not run."
                or "Organization stopped at the 16-pass limit; remaining moves are shown in Preview."
            write_probe("queue_recheck", "REJECT", organizer.error, "remaining="..#queue)
            say(organizer.error)
            return
        end
        organizer.seen_states[signature] = true
        organizer.pass = organizer.pass + 1
        organizer.queue, organizer.cursor = queue, 1
        organizer.batch_limited = plan.batch_limited
        organizer.stack_bags, organizer.awaiting_inventory = nil, nil
        organizer.summary = {logical=#plan.logical_moves,physical=#queue}
        organizer.next_send_at = os.clock() + organizer.delay
        write_probe("queue_recheck", "OK", "continuing organization from confirmed bag state",
            ("pass=%u physical=%u completed=%u"):format(organizer.pass,#queue,organizer.completed_transfers))
        return
    end


    local now = os.clock()
    if now < organizer.next_send_at then
        return
    end

    local move = organizer.queue[organizer.cursor]
    local ok, message, details = validate_move(move, organizer.options and organizer.options.allow_equipped)
    if not ok then
        organizer.running = false
        organizer.error = message
        organizer.awaiting_inventory = nil
        fail_move(move.move_id, message, details)
        say("organizer stopped on validation reject at " .. tostring(organizer.cursor) .. ".")
        return
    end

    local observation, observation_err = capture_move_observation(move)
    if not observation then
        organizer.running = false
        organizer.error = observation_err
        say("Organization stopped: " .. observation_err)
        return
    end
    organizer.awaiting_move = observation
    send_move_packet(move)
    write_audit(move.move_id, "SENT", message, details)
    write_probe(
        "queue_step",
        "SENT",
        move.move_id,
        ("%u/%u %s"):format(organizer.cursor, #organizer.queue, move_to_command_label(move))
    )
    organizer.next_send_at = now + organizer.delay
end

-- Ashita v4 public memory interfaces; no raw offsets for background readiness.
-- Status 0 is idle: github.com/Windower/Resources resources_data/statuses.lua.
-- Unknown activity/data pauses work instead of guessing.
function automatic.ready()
    local memory = AshitaCore:GetMemoryManager()
    local party, player, entity = memory:GetParty(), memory:GetPlayer(), memory:GetEntity()
    local ok = safe_call(false, function()
        local index, id = party:GetMemberTargetIndex(0), party:GetMemberServerId(0)
        return party:GetMemberIsActive(0) == 1 and id > 0 and index > 0
            and entity:GetServerId(index) == id and party:GetMemberHP(0) > 0
            and party:GetMemberHPPercent(0) > 0 and player:GetIsZoning() == 0
            and entity:GetStatus(index) == 0 and party:GetMemberZone(0) > 0
    end)
    return ok == true
end

function automatic.snapshot()
    local inv, resources = AshitaCore:GetMemoryManager():GetInventory(), AshitaCore:GetResourceManager()
    if not inv or not resources then return nil end
    local rules_valid, rules_err = item_rules.validate(preferences.item_rules)
    if not rules_valid then return nil, rules_err end
    local snapshot = { items={}, capacities={}, counts={}, stack_access={[2]=automatic.storage_stack_access()} }
    local counter, counter_err = read_inventory_counter(inv)
    if counter == nil then return nil, counter_err end
    local equipped = collect_equipped_keys(true)
    local account_flags, flags_err = read_account_storage_flags()
    local refill_configured, specific_destinations = false, {}
    local base_layout = preferences.storage_layout
    if base_layout and base_layout.active == '' then
        for _,bag in pairs(base_layout.overrides or {}) do
            if type(bag) == 'number' and bag ~= 2 then specific_destinations[bag]=true end
        end
    end
    for _, rule in pairs((preferences.item_rules and preferences.item_rules.items) or {}) do
        if type(rule.destination) == "number" and rule.destination ~= 2 then
            specific_destinations[rule.destination] = true
        end
    end
    if preferences.background and preferences.background.enabled then
        for _, rule in pairs((preferences.item_rules and preferences.item_rules.items) or {}) do
            if rule.carry_target > 0 then refill_configured = true; break end
        end
    end
    local scan_all = preferences.sort_enabled or storage_layout.active_routes(preferences.storage_layout)
        or refill_configured or (preferences.background and preferences.background.enabled)
    local scan_bags = scan_all and SCANNED_CONTAINERS or { 0, 5, 6, 7 }
    if not scan_all then
        local included = { [0]=true, [5]=true, [6]=true, [7]=true }
        for _, bag in ipairs(SCANNED_CONTAINERS) do
            if specific_destinations[bag] and not included[bag] then
                included[bag] = true
                scan_bags[#scan_bags + 1] = bag
            end
        end
    end
    for _, bag in ipairs(scan_bags) do
        local _, capacity = container_is_unlocked(inv, bag, nil, account_flags, flags_err)
        if capacity < 0 or capacity > 80 or (bag == 0 and capacity == 0) then return nil end
        if capacity > 0 then
            local loaded, loaded_err = container_is_loaded(inv, bag)
            if not loaded then return nil, loaded_err end
        end
        snapshot.capacities[bag], snapshot.counts[bag] = capacity, 0
        for index=1, capacity do
            local entry = get_container_item(inv, bag, index)
            if is_real_item(entry) then
                snapshot.counts[bag] = snapshot.counts[bag] + 1
                local resource = resources:GetItemById(entry.Id)
                local item = { container_id=bag, index=index, item_id=tonumber(entry.Id),
                    quantity=tonumber(entry.Count), item_name=first_resource_name(resource),
                    stack_size=stack_size_for(resource), flags=tonumber(entry.Flags) or 0,
                    locked=bit.band(tonumber(entry.Flags) or 0, 1) ~= 0,
                    equipped=equipped[item_key(bag, index)] == true }
                item.equippable = is_equipment(resource)
                item.resource_type = tonumber(resource and resource.Type) or 0
                item.resource_flags = tonumber(resource and resource.Flags) or 0
                item.slot_category = slot_name_from_mask(tonumber(resource and resource.Slots) or 0)
                item.social = is_social_item(item)
                -- Unknown resources cannot be nominated for a background move.
                if not resource or item.item_name == "" then item.locked = true end
                snapshot.items[#snapshot.items+1] = item
            end
        end
    end
    if counter ~= safe_call(nil, function() return inv:GetContainerUpdateCounter() end) then return nil end
    for bag, capacity in pairs(snapshot.capacities) do
        local _, current = container_is_unlocked(inv, bag, nil, account_flags, flags_err)
        if capacity ~= current or (capacity > 0 and not container_is_loaded(inv, bag)) then return nil end
    end
    if preferences.sort_enabled == true then report_inventory_ready() end
    return snapshot
end

function automatic.pause(reason)
    cancel_queues(reason)
    automatic.paused = true
    automatic.status = reason .. " Resume automatic work when ready."
    say(automatic.status)
end

function automatic.set_feature(key, enabled)
    if key ~= "sort_enabled" and key ~= "deposit_enabled" then return false end
    if not current_keep_rules() then ui.notice = "Wait for this character's settings."; return false end
    cancel_queues("automation setting changed")
    preferences[key] = enabled
    local ok, saved = pcall(settings.save)
    local loaded, result = false, false
    if ok and saved == true then loaded, result = pcall(settings.reload) end
    if not loaded or result ~= true or preferences[key] ~= enabled then
        preferences[key] = false
        ui.notice = "Automation is off for this session; the preference could not be saved."
        return false
    end
    automatic.next_check = os.time() + 2
    automatic.notice_key = nil
    if key == "deposit_enabled" then moogle.pass = nil end
    if enabled then automatic.paused = false end
    ui.notice = "Automation preference saved for this character."
    return true
end

function automatic.item_allowed(item_id)
    local resource = AshitaCore:GetResourceManager():GetItemById(item_id)
    local item = {
        item_id=item_id, resource_type=tonumber(resource and resource.Type) or 0,
        resource_flags=tonumber(resource and resource.Flags) or 0,
        equippable=is_equipment(resource), slot_category=slot_name_from_mask(tonumber(resource and resource.Slots) or 0),
    }
    local routes, err = storage_layout.active_routes(preferences.storage_layout)
    if err then return false, false end
    local outcome = item_outcome(item)
    if not outcome then return false, false end
    local assigned = outcome.mode == "specific"
        or (routes == nil and outcome.mode ~= "stay")
        or (routes ~= nil and outcome.mode == "default" and outcome.allowed)
    return outcome.allowed, assigned
end

function automatic.save_layout(desired)
    local valid, err = storage_layout.validate(desired)
    if not valid then ui.notice = err; return false end
    if not current_keep_rules() then ui.notice = "Wait for this character's settings."; return false end
    local character = get_player_slug()
    local previous = storage_layout.clone(preferences.storage_layout)
    local signature = storage_layout.signature(desired)
    cancel_queues("Storage layout updated; active work stopped. View Plan or start a new deposit to continue. No addon reload needed.")
    preferences.storage_layout = storage_layout.clone(desired)
    local ok, saved = pcall(settings.save)
    local loaded, reloaded = false, false
    if ok and saved == true then loaded, reloaded = pcall(settings.reload) end
    if character ~= get_player_slug() then return false end
    if not loaded or reloaded ~= true or storage_layout.signature(preferences.storage_layout) ~= signature then
        preferences.storage_layout = previous
        automatic.paused = true
        ui.notice = "Quickset could not be verified after saving. Previous layout retained; automatic work paused."
        return false
    end
    automatic.next_check = os.time() + 2
    ui.notice = "Storage layout saved for this character. Ignore rules still win."
    return true
end

function automatic.destinations(item)
    local routes = storage_layout.active_routes(preferences.storage_layout)
    local outcome = item_outcome(item)
    if not outcome or outcome.mode == "stay" then return {} end
    if outcome.mode == "specific" or outcome.destination ~= nil then
        return outcome.destination ~= 2 and { outcome.destination } or {}
    end
    if routes then
        local bag = outcome.destination
        return bag and bag ~= 2 and { bag } or {}
    end
    local result = {}
    if item.equippable then
        local seen = {}
        local function add(bag) if not seen[bag] then seen[bag]=true; result[#result+1]=bag end end
        for _,bucket in ipairs(WARDROBE_BUCKETS) do
            for _,category in ipairs(bucket.categories) do
                if category == item.slot_category then add(bucket.container_id) end
            end
        end
        for _,bucket in ipairs(WARDROBE_BUCKETS) do add(bucket.container_id) end
    else
        for _,bag in ipairs(storage_layout.default_route(item,true)) do
            if bag ~= 2 or automatic.storage_stack_access() then result[#result+1]=bag end
        end
    end
    return result
end

function automatic.save(config)
    local keep, err = current_keep_rules()
    local valid, config_err = housekeeping.validate(config)
    if not keep or not valid then ui.notice = err or config_err; return false end
    cancel_queues("background settings changed")
    preferences.background = config
    local ok, saved = pcall(settings.save)
    local reload_ok, reloaded = false, false
    if ok and saved == true then reload_ok, reloaded = pcall(settings.reload) end
    local actual = preferences.background
    local matched = reload_ok and reloaded == true and housekeeping.validate(actual)
        and actual.enabled == config.enabled and actual.free_slots == config.free_slots
    if matched then
        for id, value in pairs(config.items) do if actual.items[id] ~= value then matched = false end end
        for id, value in pairs(actual.items) do if config.items[id] ~= value then matched = false end end
    end
    if not matched then
        preferences.background = config
        ui.notice = "Background settings apply this session but could not be saved."
        say(ui.notice)
        return false
    end
    ui.notice = "Background settings saved for this character."
    return true
end

-- Apply the four player-facing automation choices as one settings transaction.
function automatic.apply_setup(value)
    if type(value) ~= "table" or type(value.enabled) ~= "boolean"
        or type(value.sort_enabled) ~= "boolean" or type(value.deposit_enabled) ~= "boolean"
        or type(value.free_slots) ~= "number" or value.free_slots % 1 ~= 0
        or value.free_slots < 1 or value.free_slots > 80 then
        ui.notice = "Choose valid automatic settings (free slots must be 1-80)."
        return false
    end
    if not current_keep_rules() then ui.notice = "Wait for this character's settings."; return false end
    local existing = preferences.background or { enabled=false, free_slots=5, items={} }
    if not housekeeping.validate(existing) then ui.notice = "Fix invalid background settings first."; return false end
    local function copy_table(source)
        if type(source) ~= "table" then return source end
        local copy = {}
        for key, item in pairs(source) do copy[key] = copy_table(item) end
        return copy
    end
    local function same_value(left, right)
        if type(left) ~= type(right) then return false end
        if type(left) ~= "table" then return left == right end
        for key, item in pairs(left) do if not same_value(item, right[key]) then return false end end
        for key in pairs(right) do if left[key] == nil then return false end end
        return true
    end
    local previous = { background={ enabled=existing.enabled, free_slots=existing.free_slots, items={} },
        sort_enabled=preferences.sort_enabled, deposit_enabled=preferences.deposit_enabled,
        paused=automatic.paused, keep=preferences.keep, keep_snapshot=copy_table(preferences.keep) }
    for id, allowed in pairs(existing.items or {}) do previous.background.items[id] = allowed end
    local config = { enabled=value.enabled, free_slots=value.free_slots, items={} }
    for id, allowed in pairs(existing.items or {}) do config.items[id] = allowed end
    local unchanged = config.enabled == existing.enabled and config.free_slots == existing.free_slots
        and value.sort_enabled == preferences.sort_enabled and value.deposit_enabled == preferences.deposit_enabled
    if unchanged then
        for id, allowed in pairs(config.items) do if existing.items[id] ~= allowed then unchanged = false end end
        for id, allowed in pairs(existing.items or {}) do if config.items[id] ~= allowed then unchanged = false end end
    end
    if unchanged then ui.notice = "These automatic settings are already saved."; return true end
    cancel_queues("automatic settings changed")
    preferences.background = config
    preferences.sort_enabled, preferences.deposit_enabled = value.sort_enabled, value.deposit_enabled
    local ok, saved = pcall(settings.save)
    local reload_ok, reloaded = false, false
    if ok and saved == true then reload_ok, reloaded = pcall(settings.reload) end
    local actual = preferences.background
    local matched = reload_ok and reloaded == true and housekeeping.validate(actual)
        and actual.enabled == config.enabled and actual.free_slots == config.free_slots
        and preferences.sort_enabled == value.sort_enabled
        and preferences.deposit_enabled == value.deposit_enabled
        and same_value(preferences.keep, previous.keep_snapshot)
    if matched then
        for id, setting in pairs(config.items) do if actual.items[id] ~= setting then matched = false end end
        for id, setting in pairs(actual.items) do if config.items[id] ~= setting then matched = false end end
    end
    if not matched then
        preferences.background, preferences.sort_enabled, preferences.deposit_enabled =
            previous.background, previous.sort_enabled, previous.deposit_enabled
        preferences.keep = previous.keep
        automatic.paused = previous.paused
        ui.automation_draft = nil
        ui.notice = "Could not verify saved settings. Previous settings remain active for this session."
        return false
    end
    automatic.next_check = os.time() + 2
    automatic.notice_key = nil
    automatic.paused = previous.paused
    ui.automation_draft = nil
    ui.notice = "Automatic settings saved for this character."
    return true
end

function automatic.configure(action, item_id, value)
    local existing = preferences.background or { enabled=false, free_slots=5, items={} }
    if not housekeeping.validate(existing) then ui.notice = "Fix invalid background settings first."; return end
    local config = { enabled=existing.enabled, free_slots=existing.free_slots, items={} }
    for id, allowed in pairs(existing.items) do config.items[id] = allowed end
    if action == "on" or action == "off" then
        config.enabled = action == "on"
    elseif action == "slots" then
        config.free_slots = tonumber(item_id)
    elseif action == "item" then
        if not tonumber(item_id) or not AshitaCore:GetResourceManager():GetItemById(tonumber(item_id)) then
            ui.notice = "Choose a valid item ID."; return
        end
        config.items[tostring(item_id)] = value
    else return end
    if automatic.save(config) and action == "on" then automatic.paused = false end
end

local function add_manual_move_intent(item_id, item_name, source, destination, index, quantity)
    local now = os.time()
    local pending = automatic.manual_pending
    if pending == nil or pending.character_slug ~= get_player_slug() then
        pending = { character_slug=get_player_slug(), groups={}, last_event=now, ambiguous=false }
        automatic.manual_pending = pending
    end
    local group
    for _, existing in ipairs(pending.groups) do
        if existing.item_id == item_id then
            if existing.source_container_id == source and existing.target_container_id == destination then
                group = existing
            else
                pending.ambiguous = true
                pending.last_event = now
                return false
            end
        end
    end
    if group == nil then
        local source_before = container_item_count(source, item_id)
        local target_before = container_item_count(destination, item_id)
        if source_before == nil or target_before == nil then return false end
        group = { item_id=item_id, item_name=item_name, source_container_id=source,
            target_container_id=destination, source_before=source_before,
            target_before=target_before, requested=0, slots={} }
        table.insert(pending.groups, group)
    end
    local slot = group.slots[index]
    if not slot then
        local source_item = get_container_item(AshitaCore:GetMemoryManager():GetInventory(), source, index)
        if not is_real_item(source_item) or tonumber(source_item.Id) ~= item_id then return false end
        slot = { before=tonumber(source_item.Count) or 0, requested=0 }
        group.slots[index] = slot
    end
    slot.requested = slot.requested + quantity
    group.requested = group.requested + quantity
    pending.last_event = now
    return true
end

local function inspect_manual_moves(pending)
    if pending.character_slug ~= get_player_slug() then return "failed", "character changed" end
    local now = os.time()
    if now - pending.last_event < 1 then return "pending" end
    if pending.ambiguous then
        return "ambiguous", "Overlapping manual moves of the same item could not be tracked exactly."
    end
    local moved_groups, waiting = {}, false
    for _, group in ipairs(pending.groups) do
        local source = container_item_count(group.source_container_id, group.item_id)
        local target = container_item_count(group.target_container_id, group.item_id)
        if source == nil or target == nil then
            waiting = true
        else
            local source_delta = group.source_before - source
            local target_delta = target - group.target_before
            local slot_delta, slots_valid = 0, true
            local inv = AshitaCore:GetMemoryManager():GetInventory()
            for index, expected in pairs(group.slots) do
                local entry = get_container_item(inv, group.source_container_id, index)
                local current = is_real_item(entry) and tonumber(entry.Id) == group.item_id
                    and tonumber(entry.Count) or 0
                local delta = expected.before - current
                if delta < 0 or delta > expected.requested then slots_valid = false end
                slot_delta = slot_delta + delta
            end
            if source_delta > 0 and source_delta == target_delta and source_delta == slot_delta
                and source_delta <= group.requested and slots_valid then
                group.confirmed_quantity = source_delta
                moved_groups[#moved_groups + 1] = group
            elseif source_delta == 0 and target_delta == 0 and slot_delta == 0 then
                waiting = true
            else
                waiting = true
            end
        end
    end
    if waiting and now - pending.last_event < 5 then return "pending" end
    if #moved_groups == 0 then return "failed", "Manual movement was not confirmed; no temporary item hold was applied." end
    return "confirmed", moved_groups
end

function automatic.tick()
    automatic.flush_storage_access()
    automatic.confirm_manual_acquisition()
    if automatic.manual_acquisition then return end
    if automatic.manual_pending then
        local state, result = inspect_manual_moves(automatic.manual_pending)
        if state == "pending" then return end
        automatic.manual_pending = nil
        automatic.next_check = os.time() + 2
        if state == "confirmed" then
            for _, group in ipairs(result) do
                item_rules.record_manual_move(automatic.holds, group.item_id,
                    group.source_container_id, group.target_container_id, group.confirmed_quantity)
            end
            automatic.owner = get_player_slug()
            local snapshot = collect_live_items()
            automatic.hold_counts = snapshot and item_rules.location_totals(snapshot.items) or {}
            automatic.status = "Manual item movement preserved for this session."
            ui.notice = "Manual item movement saved as a temporary quantity and location override. It clears on reload."
        elseif state == "ambiguous" then
            automatic.paused = true
            automatic.status = result .. " Check Inventory, then resume automatic work."
            ui.notice = automatic.status
        else
            automatic.status = result
            ui.notice = result
        end
        return
    end
    -- Observe already-sent work first. An unconfirmed transfer never auto-retries.
    if automatic.pending then
        local state, message = check_move_observation(automatic.pending)
        if state == "pending" then return end
        if state == "failed" then automatic.pause(message); return end
        local completed = automatic.pending.move
        automatic.pending = nil
        if completed.frees_slot then automatic.freed = automatic.freed + 1 end
        automatic.next_check = os.time() + 2
    end
    if os.time() < automatic.next_check then return end
    automatic.next_check = os.time() + 2
    local config = preferences.background
    if not config then automatic.status = "Background clearing is off."; return end
    local valid, err = housekeeping.validate(config)
    if not valid then automatic.status = err; return end
    local layout_routes, layout_err = storage_layout.active_routes(preferences.storage_layout)
    if layout_err then automatic.status = layout_err; return end
    local sorting = preferences.sort_enabled == true
    if not config.enabled and not sorting then automatic.status = "Automatic sorting and clearing are off."; return end
    if automatic.paused then return end
    local keep, keep_err = current_keep_rules()
    if not keep then automatic.status = keep_err; return end
    if not automatic.ready() then
        automatic.ready_character, automatic.ready_zone = nil, nil
        automatic.status = "Waiting for character to be alive, idle, and ready."
        return
    end
    if organizer.running or ephemeral.running or not new_run_ready() then
        automatic.status = "Waiting for current housekeeping to finish."; return
    end
    local character = get_player_slug()
    local zone = safe_call(nil, function() return AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) end)
    if automatic.ready_character ~= character or automatic.ready_zone ~= zone then
        automatic.ready_character, automatic.ready_zone = character, zone
        automatic.status = "Waiting for inventory to settle after arrival."
        return
    end
    local snapshot, snapshot_err = automatic.snapshot()
    if not snapshot then automatic.status = snapshot_err or "Waiting for a complete inventory snapshot."; return end
    local reserved, reserve_err, refill_reserved = get_keep_reservations(snapshot)
    if not reserved then automatic.status = reserve_err; return end
    if config.enabled then
        for _, item in ipairs(snapshot.items) do
            local source_key = item_key(item.container_id, item.index)
            local quantity = tonumber(refill_reserved[source_key]) or 0
            local explicit = preferences.item_rules and preferences.item_rules.items[tostring(item.item_id)]
            if quantity > 0 and not explicit then
                local free=(snapshot.capacities[0] or 0)-(snapshot.counts[0] or 0)
                local room=0
                for _,carried in ipairs(snapshot.items) do
                    if carried.container_id == 0 and carried.item_id == item.item_id and not carried.locked then
                        room=room+math.max(0,carried.stack_size-carried.quantity)
                    end
                end
                if free <= config.free_slots and room < quantity then quantity=0 end
            end
            if quantity > 0 then
                local move = {
                    move_id="refill-" .. character .. "-" .. item.container_id .. "-" .. item.index,
                    character_slug=character,
                    item_id=item.item_id,
                    item_name=item.item_name,
                    quantity=quantity,
                    source_container_id=item.container_id,
                    source_index=item.index,
                    target_container_id=INVENTORY_CONTAINER_ID,
                    stack_size=item.stack_size,
                    purpose="refill",
                }
                local valid, message = validate_move(move)
                if valid then
                    local observation, observation_err = capture_move_observation(move)
                    if not observation then automatic.pause(observation_err); return end
                    automatic.pending = observation
                    automatic.status = "Restocking: " .. move.item_name .. " -> Inventory"
                    send_move_packet(move)
                    write_audit(move.move_id, "SENT", "automatic carried-supply refill", move_to_command_label(move))
                    return
                elseif message ~= "target container is full" then
                    automatic.pause(message)
                    return
                end
                -- A full Inventory can be cleared below; the refill stays reserved.
                break
            end
        end
    end
    local move, result, free = housekeeping.choose(snapshot, reserved, config, character,
        automatic.destinations,
        function(item)
            local outcome = item_outcome(item)
            return outcome ~= nil and outcome.allowed == true
        end,
        sorting)
    if not move then
        if result == "ready" then
            automatic.status = (sorting and "Incoming items sorted. " or "Ready. ")
                .. ("%u free Inventory slots; %u freed this session."):format(free, automatic.freed)
            automatic.notice_key = nil
        else
            local low = config.enabled and free < math.min(config.free_slots, snapshot.capacities[0] or 0)
            local prefix = free == 0 and "Inventory is full. "
                or ((low and "Only %u free Inventory slots. " or "%u free Inventory slots. "):format(free))
            automatic.status = result == "protected"
                and (prefix .. "Remaining items are kept, held, locked, or not opted in. Make room manually or review Item rules.")
                or (prefix .. (layout_routes and "A chosen quickset bag is full or unavailable. Check its destination in Automatic care."
                    or "Eligible items have no storage room. Free bag space or deposit surplus at an Ephemeral Moogle."))
            local key = character .. ":" .. result .. (free == 0 and ":full" or ":space")
            if automatic.notice_key ~= key then say(automatic.status); automatic.notice_key = key end
        end
        return
    end
    local ok, message = validate_move(move)
    if not ok then automatic.pause(message); return end
    local observation, observation_err = capture_move_observation(move)
    if not observation then automatic.pause(observation_err); return end
    automatic.pending = observation
    automatic.status = (move.purpose=="stack" and "Stacking: " or "Making space: ") .. move.item_name .. " -> " .. CONTAINERS[move.target_container_id]
    send_move_packet(move)
    write_audit(move.move_id, "SENT", move.purpose=="stack" and "fill existing stack" or "background free-space clearing", move_to_command_label(move))
end

-- Native menu/item-use contracts: Windower packets/fields.lua (0x034, 0x05B,
-- 0x037), LSB ephemeral_moogle.lua and elemental cluster item scripts.
-- Observe intent and then inventory results; never send menu or use-item packets.
local function packet_number(data, offset, size)
    if type(data) ~= 'string' or #data < offset + size then return nil end
    local value = 0
    for index = offset + size, offset + 1, -1 do value = value * 256 + data:byte(index) end
    return value
end

function automatic.storage_stack_access()
    local proof=automatic.house_access
    local party=AshitaCore:GetMemoryManager():GetParty()
    return proof~=nil and proof.character==get_player_slug()
        and proof.zone==safe_call(nil,function() return party:GetMemberZone(0) end)
end

-- Native 0x00A LoginState at raw 0x80 (LSB s2c/0x00a_login.h).
-- Feretory uses MYROOM for its menu but is not a residence.
function automatic.observe_house_access(e)
    if e.injected~=false or e.blocked==true or (e.id~=0x00A and e.id~=0x00B) then return end
    automatic.house_access=nil
    local data=e.data
    if e.id~=0x00A or packet_number(data,0x80,4)~=1 then return end
    local party=AshitaCore:GetMemoryManager():GetParty()
    local zone=packet_number(data,0x30,2)
    if not zone or zone==285 or packet_number(data,4,4)~=safe_call(nil,function() return party:GetMemberServerId(0) end) then return end
    automatic.house_access={character=get_player_slug(),zone=zone}
end

function automatic.observe_moogle_menu(e)
    if (e.id ~= 0x032 and e.id ~= 0x034) or e.injected ~= false or e.blocked == true then return end
    automatic.moogle_menu = nil
    local data = e.data_modified or e.data
    local offset = e.id == 0x034 and 0x28 or 0x08
    local index, zone, menu = packet_number(data,offset,2), packet_number(data,offset+2,2), packet_number(data,offset+4,2)
    local server = packet_number(data,4,4)
    if not index or not zone or not menu or not current_keep_rules() then return end
    local target = get_target_by_index(index)
    if not target or target.server_id ~= server or target.zone ~= zone
        or string.lower(target.name or '') ~= 'ephemeral moogle'
        or not target.distance or target.distance > 6 then return end
    automatic.moogle_menu = {target=target, menu=menu, character=get_player_slug()}
end

function automatic.confirm_manual_acquisition()
    local pending = automatic.manual_acquisition
    if not pending then return end
    local party = AshitaCore:GetMemoryManager():GetParty()
    if pending.character ~= get_player_slug()
        or pending.zone ~= safe_call(nil, function() return party:GetMemberZone(0) end) then
        automatic.manual_acquisition = nil
        return
    end
    local snapshot = collect_live_items()
    local totals = snapshot and item_rules.location_totals(snapshot.items)
    local gains, complete, changed = {}, true, false
    if totals then
        for id, expected in pairs(pending.expected) do
            local delta = (totals[id..':0'] or 0) - pending.before[id]
            if delta < 0 or delta > expected then pending.ambiguous = true end
            gains[id] = math.max(0,delta)
            if delta ~= expected then complete = false end
            if delta > 0 then changed = true end
        end
        if pending.cluster then
            local consumed = pending.cluster_before - (totals[tostring(pending.cluster)..':0'] or 0)
            if consumed < 0 or consumed > 1 then pending.ambiguous = true end
            complete = complete and consumed == 1
            -- A cluster's output must be exact; partial packet updates must settle.
        elseif changed then
            local signature = tostring(gains[pending.crystal_id])..':'..tostring(gains[pending.cluster_id])
            if signature ~= pending.signature then pending.signature, pending.changed_at = signature, os.clock() end
            -- "As many as fit" can legitimately yield less than the requested maximum.
            complete = complete or (pending.allow_partial and os.clock() - pending.changed_at >= 1)
        end
    else complete = false end
    if pending.ambiguous or (not complete and os.clock() >= pending.deadline) then
        automatic.manual_acquisition = nil
        automatic.pause('Manual item receipt could not be confirmed exactly.')
        return
    end
    if not complete or not changed then return end
    -- Reconcile consumption once before adding the newly protected quantities.
    item_rules.reconcile_overrides(automatic.holds,snapshot.items,automatic.hold_counts)
    for id, quantity in pairs(gains) do
        if quantity > 0 then item_rules.record_manual_gain(automatic.holds,tonumber(id),0,quantity) end
    end
    automatic.owner, automatic.hold_counts = pending.character, totals
    automatic.manual_acquisition = nil
    automatic.next_check = os.time() + 2
    automatic.status = pending.cluster and 'Crystals from your manually held cluster stay in Inventory.'
        or 'Your Moogle withdrawal stays in Inventory for this session.'
    write_probe('manual_acquisition','CONFIRMED',automatic.status,pending.kind)
end

function automatic.observe_manual_acquisition(e)
    if e.injected ~= false or e.blocked == true or (e.id ~= 0x05B and e.id ~= 0x037) then return end
    automatic.confirm_manual_acquisition()
    if not current_keep_rules() then return end
    local data = e.data_modified or e.data
    local party = AshitaCore:GetMemoryManager():GetParty()
    local zone = safe_call(nil,function() return party:GetMemberZone(0) end)
    local pending = {character=get_player_slug(),zone=zone,expected={},before={},deadline=os.clock()+15}
    if e.id == 0x05B then
        local context = automatic.moogle_menu
        local server, index = packet_number(data,4,4), packet_number(data,12,2)
        local amount, element = packet_number(data,8,2), packet_number(data,10,1)
        if not context or context.character ~= pending.character or context.target.zone ~= zone
            or context.target.server_id ~= server or context.target.index ~= index
            or packet_number(data,18,2) ~= context.menu or packet_number(data,16,2) ~= zone
            or packet_number(data,14,1) ~= 0 then return end
        automatic.moogle_menu = nil
        local target = get_target_by_index(index)
        if not target or target.server_id ~= server or string.lower(target.name or '') ~= 'ephemeral moogle'
            or not target.distance or target.distance > 6 then return end
        if not amount or amount < 1 or amount > 5000 or not element or element < 1 or element > 8 then return end
        pending.kind = 'moogle withdrawal'
        pending.crystal_id, pending.cluster_id = tostring(4095+element), tostring(4103+element)
        pending.expected[pending.crystal_id] = amount % 12
        pending.expected[pending.cluster_id] = math.floor(amount/12)
        pending.allow_partial = bit.band(packet_number(data,11,1) or 0,0x80) ~= 0
        moogle.pass = {target=target,scene=pending.character..':'..tostring(zone),claimed=true}
    else
        local slot, bag = packet_number(data,14,1), packet_number(data,16,1)
        if bag ~= 0 or not slot or slot < 1 or slot > 80
            or packet_number(data,4,4) ~= safe_call(nil,function() return party:GetMemberServerId(0) end)
            or packet_number(data,12,2) ~= safe_call(nil,function() return party:GetMemberTargetIndex(0) end) then return end
        local item = get_container_item(AshitaCore:GetMemoryManager():GetInventory(),0,slot)
        local id = is_real_item(item) and tonumber(item.Id)
        if not id or id < 4104 or id > 4111 then return end
        local held = automatic.owner == pending.character and automatic.holds[tostring(id)]
        if held ~= true and (type(held) ~= 'table' or (tonumber(held['0']) or 0) < 1) then return end
        pending.kind, pending.cluster = 'held cluster use', id
        pending.cluster_before = container_item_count(0,id)
        pending.expected[tostring(id-8)] = 12
        if not pending.cluster_before then return end
    end
    if automatic.manual_acquisition or automatic.manual_pending or automatic.pending
        or organizer.awaiting_move or ephemeral.awaiting_trade or ephemeral.awaiting_inventory then
        if automatic.manual_acquisition then automatic.manual_acquisition.ambiguous = true end
        automatic.pause('Overlapping manual item actions need an Inventory check.')
        return
    end
    for id in pairs(pending.expected) do
        local count = container_item_count(0,tonumber(id))
        if count == nil then return end
        pending.before[id] = count
    end
    automatic.manual_acquisition = pending
    automatic.owner = pending.character
    cancel_queues('Manual item action detected; waiting for its result.')
    automatic.next_check = os.time() + 2
end

-- Passive observation only. Ashita's packet_out.injected flag distinguishes
-- native manual bag moves from addon-generated staging moves.
function automatic.observe_retrieval(e)
    automatic.observe_manual_acquisition(e)
    if e.id ~= MOVE_PACKET_ID or e.injected ~= false or e.blocked == true then return end
    local data = e.data_modified or e.data
    if type(data) ~= "string" or #data < 12 then return end
    local b1, b2, b3, b4 = data:byte(5, 8)
    local source, destination, index = data:byte(9, 11)
    local quantity = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    if not CONTAINERS[source] or not CONTAINERS[destination] or source == destination
        or not index or index < 1 or index > 80 or quantity < 1 or quantity > 99999 then return end
    if not current_keep_rules() then return end
    local inv, resources = AshitaCore:GetMemoryManager():GetInventory(), AshitaCore:GetResourceManager()
    local entry = get_container_item(inv, source, index)
    if not is_real_item(entry) or tonumber(entry.Count) < quantity then return end
    local resource = resources and resources:GetItemById(entry.Id)
    local item_name = first_resource_name(resource)
    if item_name == "" then return end
    local acquisition = automatic.manual_acquisition
    if acquisition and (source == 0 or destination == 0)
        and (acquisition.expected[tostring(entry.Id)] ~= nil or acquisition.cluster == tonumber(entry.Id)) then
        -- The receipt delta can no longer distinguish these two manual actions.
        acquisition.ambiguous = true
    end
    local already_tracking = automatic.manual_pending ~= nil
    if not add_manual_move_intent(tonumber(entry.Id), item_name, source, destination, index, quantity) then
        return
    end
    automatic.owner = get_player_slug()
    if not already_tracking then cancel_queues("manual item movement; waiting for confirmation") end
    automatic.next_check = os.time() + 2
    ui.notice = "Manual item movement detected. Its temporary quantity and location override will apply after the transfer is confirmed."
end

-- One automatic deposit run per proximity encounter, with an outer rearm radius.
-- It never changes selection, walks the player, or retries an uncertain deposit.
function moogle.tick()
    if os.clock() < moogle.next_check then return end
    moogle.next_check = os.clock() + 0.5
    if preferences.deposit_enabled ~= true then moogle.status = "Nearby deposits are off."; return end
    local zone = safe_call(nil, function() return AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) end)
    if not zone or zone <= 0 then return end
    local scene = get_player_slug() .. ":" .. tostring(zone)
    local pass = moogle.pass
    if pass and pass.scene ~= scene then moogle.pass = nil; pass = nil end
    if pass then
        local npc = get_target_by_index(pass.target.index)
        if not npc or npc.server_id ~= pass.target.server_id or npc.name ~= pass.target.name
            or npc.zone ~= pass.target.zone or not npc.distance or npc.distance > 8 then
            pass.left_at = pass.left_at or os.time()
            if os.time() - pass.left_at >= 2 then moogle.pass = nil end
            return
        end
        pass.left_at = nil
        if pass.claimed then
            if pass.started and ephemeral.automatic and not ephemeral.running then
                moogle.status = ephemeral.error and ("Nearby deposit stopped: " .. ephemeral.error)
                    or "Deposit visit complete. Ready for the next visit."
            end
            if pass.empty then moogle.status = "No extra crystals to deposit." end
            return
        end
    end
    if automatic.paused then moogle.status = "Nearby deposits paused."; return end
    if not automatic.ready() or not current_keep_rules() then return end
    local target = pass and get_target_by_index(pass.target.index) or nearby_moogle()
    if not target or not target.distance or target.distance > 6 then
        moogle.status = "Ready to deposit surplus when you pass an Ephemeral Moogle."
        return
    end
    if not pass then
        pass = { target=target, scene=scene, claimed=false }
        moogle.pass = pass
    end
    if organizer.running or ephemeral.running or not new_run_ready() then return end
    if not housekeeping.validate(preferences.background) then return end
    local snapshot, _, snapshot_err = collect_live_items()
    if not snapshot then moogle.status = snapshot_err or "Waiting for bags to finish loading before depositing."; return end
    pass.claimed = true
    moogle.status = "Depositing this Moogle pass; your Keep rules and retrieval holds apply."
    local started, result = handle_ephemeral({ "/oddorg", "ephemeral", "dump", "all" }, target)
    pass.started, pass.empty = started == true, result == "empty"
    if pass.empty then moogle.status = "No extra crystals to deposit."
    elseif not pass.started then moogle.status = "Nearby deposit needs attention; review the status and Keep rules." end
end

function automatic.command(args)
    local action = args[3]
    if action == "on" or action == "off" or action == "slots" then
        automatic.configure(action, args[4])
    elseif action == "allow" or action == "exclude" then
        automatic.configure("item", args[4], action == "allow")
    elseif action == "pause" then automatic.pause("Background clearing paused.")
    elseif action == "resume" then
        automatic.paused, automatic.next_check = false, os.time() + 2
        automatic.status = "Background clearing resumed."
    else
        say("/oddorg auto on|off|pause|resume|status | slots <1-80> | allow|exclude <item ID>")
        say(automatic.status)
        return
    end
    say(ui.notice or automatic.status)
end

local function print_help()
    say("Incoming sorting: /oddorg sort on|off|status. Nearby deposits: /oddorg deposit on|off|status.")
    say("Background clearing: /oddorg auto on|off|pause|resume|status | slots <1-80> | allow|exclude <item ID>.")
    say("Item rules: /oddorg keep <item ID> all|<quantity>|clear | /oddorg keep list. Or open Item rules in /oddorg.")
    say("Commands: /oddorg status | /oddorg move <move_id> <character_slug> <item_id> <quantity> <src_container_id> <src_index> <dst_container_id> \"<name>\" | /oddorg organize preview|run|stop|status [all|wardrobes|storage] [equipped] [social] | /oddorg ephemeral dump|stop|status [all|inventory|storage] | /oddorg probes on|off|clear|status")
end

local function handle_status()
    local slug = get_player_slug()
    write_audit("status", "OK", "loaded", slug)
    write_probe("queue_status", "OK", "addon status", slug)
    say(("loaded for %s organizer=%s ephemeral=%s"):format(slug, tostring(organizer.running), tostring(ephemeral.running)))
end

-- Native controls share the palette and visual primitives in ui_skin.
local UI_COLORS = skin.colors

local function global(name)
    return _G ~= nil and _G[name] or nil
end

local function push_ui_color(slot_name, color, pushed)
    local slot = global(slot_name)
    if imgui ~= nil and imgui.PushStyleColor ~= nil and slot ~= nil then
        imgui.PushStyleColor(slot, color)
        pushed.colors = pushed.colors + 1
    end
end

local function push_ui_var(slot_name, value, pushed)
    local slot = global(slot_name)
    if imgui ~= nil and imgui.PushStyleVar ~= nil and slot ~= nil then
        imgui.PushStyleVar(slot, value)
        pushed.vars = pushed.vars + 1
    end
end

local function push_ui_style()
    local pushed = { colors = 0, vars = 0 }
    if imgui.SetNextWindowBgAlpha ~= nil then
        imgui.SetNextWindowBgAlpha(1.0)
    end
    push_ui_color("ImGuiCol_Text", UI_COLORS.text, pushed)
    push_ui_color("ImGuiCol_WindowBg", UI_COLORS.background, pushed)
    push_ui_color("ImGuiCol_ChildBg", UI_COLORS.transparent, pushed)
    push_ui_color("ImGuiCol_Border", UI_COLORS.border, pushed)
    push_ui_color("ImGuiCol_BorderShadow", UI_COLORS.transparent, pushed)
    push_ui_color("ImGuiCol_TitleBg", UI_COLORS.background, pushed)
    push_ui_color("ImGuiCol_TitleBgActive", UI_COLORS.panel, pushed)
    push_ui_color("ImGuiCol_TitleBgCollapsed", UI_COLORS.background, pushed)
    push_ui_color("ImGuiCol_FrameBg", UI_COLORS.panel, pushed)
    push_ui_color("ImGuiCol_FrameBgHovered", UI_COLORS.blue, pushed)
    push_ui_color("ImGuiCol_FrameBgActive", UI_COLORS.blue_hover, pushed)
    push_ui_color("ImGuiCol_CheckMark", UI_COLORS.blue_highlight, pushed)
    push_ui_color("ImGuiCol_SliderGrab", UI_COLORS.blue_outline, pushed)
    push_ui_color("ImGuiCol_SliderGrabActive", UI_COLORS.blue_highlight, pushed)
    push_ui_color("ImGuiCol_Header", UI_COLORS.blue, pushed)
    push_ui_color("ImGuiCol_HeaderHovered", UI_COLORS.blue_hover, pushed)
    push_ui_color("ImGuiCol_HeaderActive", UI_COLORS.blue, pushed)
    push_ui_color("ImGuiCol_ScrollbarBg", UI_COLORS.background, pushed)
    push_ui_color("ImGuiCol_ScrollbarGrab", UI_COLORS.panel, pushed)
    push_ui_color("ImGuiCol_ScrollbarGrabHovered", UI_COLORS.blue, pushed)
    push_ui_color("ImGuiCol_ScrollbarGrabActive", UI_COLORS.blue_outline, pushed)
    push_ui_color("ImGuiCol_TextDisabled", UI_COLORS.muted, pushed)
    push_ui_color("ImGuiCol_Button", UI_COLORS.panel, pushed)
    push_ui_color("ImGuiCol_ButtonHovered", UI_COLORS.blue_hover, pushed)
    push_ui_color("ImGuiCol_ButtonActive", UI_COLORS.blue_press, pushed)
    push_ui_var("ImGuiStyleVar_WindowPadding", { 18.0, 16.0 }, pushed)
    push_ui_var("ImGuiStyleVar_WindowRounding", 10.0, pushed)
    push_ui_var("ImGuiStyleVar_ChildRounding", 8.0, pushed)
    push_ui_var("ImGuiStyleVar_FrameRounding", 5.0, pushed)
    push_ui_var("ImGuiStyleVar_ItemSpacing", { 12.0, 10.0 }, pushed)
    push_ui_var("ImGuiStyleVar_ItemInnerSpacing", { 8.0, 6.0 }, pushed)
    push_ui_var("ImGuiStyleVar_FramePadding", { 9.0, 7.0 }, pushed)
    push_ui_var("ImGuiStyleVar_ChildBorderSize", 1.0, pushed)
    return pushed
end

local function pop_ui_style(pushed)
    if imgui.PopStyleVar ~= nil and pushed.vars > 0 then
        imgui.PopStyleVar(pushed.vars)
    end
    if imgui.PopStyleColor ~= nil and pushed.colors > 0 then
        imgui.PopStyleColor(pushed.colors)
    end
end

local function ui_text(value, color)
    local pushed = { colors = 0, vars = 0 }
    if color ~= nil then
        push_ui_color("ImGuiCol_Text", color, pushed)
    end
    if imgui.TextUnformatted ~= nil then
        imgui.TextUnformatted(tostring(value or ""))
    elseif imgui.Text ~= nil then
        imgui.Text(tostring(value or ""))
    end
    pop_ui_style(pushed)
end

local function ui_wrapped_text(value, color)
    local pushed = { colors = 0, vars = 0 }
    if color ~= nil then push_ui_color("ImGuiCol_Text", color, pushed) end
    imgui.TextWrapped(tostring(value or ""))
    pop_ui_style(pushed)
end

local function ui_button(label, active, disabled, outlined_when_inactive, size)
    local pushed = { colors = 0, vars = 0 }
    if disabled then
        push_ui_color("ImGuiCol_Text", UI_COLORS.muted, pushed)
        push_ui_color("ImGuiCol_Button", UI_COLORS.background, pushed)
        push_ui_color("ImGuiCol_ButtonHovered", UI_COLORS.background, pushed)
        push_ui_color("ImGuiCol_ButtonActive", UI_COLORS.background, pushed)
    elseif active then
        push_ui_color("ImGuiCol_Button", UI_COLORS.blue, pushed)
    elseif outlined_when_inactive then
        push_ui_color("ImGuiCol_Border", UI_COLORS.blue_outline, pushed)
        push_ui_var("ImGuiStyleVar_FrameBorderSize", 1.0, pushed)
    end
    local used_disabled = disabled and imgui.BeginDisabled ~= nil and imgui.EndDisabled ~= nil
    if used_disabled then
        imgui.BeginDisabled(true)
    end
    local clicked = imgui.Button ~= nil and imgui.Button(label, size or { 0, 0 }) == true
    skin.button_finish(imgui,label,active,disabled)
    if used_disabled then
        imgui.EndDisabled()
    end
    pop_ui_style(pushed)
    return not disabled and clicked
end

local function same_line()
    if imgui.SameLine ~= nil then
        imgui.SameLine()
    end
end

local function ui_scale()
    return math.max(1, (imgui.GetFontSize and imgui.GetFontSize() or 16) / 16)
end

-- Attach guidance to the preceding control without taking up editor space.
local function ui_tooltip(text)
    local hovered = imgui.IsItemHovered and imgui.IsItemHovered()
    local focused = imgui.IsItemFocused and imgui.IsItemFocused()
    if not (hovered or focused) then return end
    if imgui.BeginTooltip and imgui.EndTooltip and imgui.PushTextWrapPos and imgui.PopTextWrapPos then
        local width = math.min(360 * ui_scale(), math.max(160, (imgui.GetWindowWidth and imgui.GetWindowWidth() or 392) - 32))
        imgui.BeginTooltip()
        imgui.PushTextWrapPos(width)
        imgui.TextUnformatted(text)
        imgui.PopTextWrapPos()
        imgui.EndTooltip()
    elseif imgui.SetTooltip then imgui.SetTooltip(text) end
end

local function ui_feature_row(title, caption, value, id)
    local changed, next_value = false, value
    local scale = ui_scale()
    local surface_style = { colors=0, vars=0 }
    push_ui_color("ImGuiCol_ChildBg", UI_COLORS.transparent, surface_style)
    push_ui_color("ImGuiCol_Border", value and UI_COLORS.blue or UI_COLORS.border, surface_style)
    push_ui_var("ImGuiStyleVar_WindowPadding", { 12 * scale, 10 * scale }, surface_style)
    push_ui_var("ImGuiStyleVar_ItemSpacing", { 8 * scale, 4 * scale }, surface_style)
    local available = imgui.GetContentRegionAvail()
    local text_width = math.max(1,available-24*scale-108*scale-12-36*scale)
    local copy_height = skin.text_height(imgui,title,text_width,1.05)
    local height = math.ceil(math.max(34*scale,copy_height)+20*scale)
    local visible = imgui.BeginChild("##" .. id .. "_row", { 0, height }, true)
    if visible then
        skin.panel(imgui,'panel',0.16)
        local width = imgui.GetContentRegionAvail()
        local window_padding = global("ImGuiStyleVar_WindowPadding")
        if imgui.PushStyleVar and imgui.PopStyleVar and window_padding ~= nil then imgui.PushStyleVar(window_padding, { 0, 0 }) end
        if imgui.BeginChild("##" .. id .. "_copy", { math.max(1, width - 108 * scale - 12), 0 }, false) then
            local image = id == 'care_space' and 'inventory' or id == 'care_deposit' and 'moogle' or 'sack'
            local group = imgui.BeginGroup and imgui.EndGroup
            if group then
                if skin.icon(imgui,image,28*scale) then same_line() end
                imgui.BeginGroup()
            end
            skin.heading(imgui, title, 1.05, UI_COLORS.text)
            ui_tooltip(caption)
            if group then imgui.EndGroup() end
        end
        imgui.EndChild()
        same_line()
        if imgui.BeginChild("##" .. id .. "_control", { 108 * scale, 0 }, false) then
            if skin.toggle(imgui, id .. "_toggle", value, false, scale) then
                changed, next_value = true, not value
            end
            ui_tooltip(caption)
        end
        imgui.EndChild()
        if imgui.PushStyleVar and imgui.PopStyleVar and window_padding ~= nil then imgui.PopStyleVar() end
    end
    imgui.EndChild()
    pop_ui_style(surface_style)
    return changed, next_value
end

local function active_progress_state()
    if organizer.running then
        return organizer
    end
    if ephemeral.running then
        return ephemeral
    end
    return nil
end

local function progress_fraction(state)
    if state == ephemeral then
        local _, remaining_units = ephemeral.progress()
        local total_units = ephemeral.summary and ephemeral.summary.units or 0
        return total_units > 0 and math.max(0,math.min(1,1-remaining_units/total_units)) or 1
    end
    local total = #(state.queue or {})
    if total == 0 then
        return 1.0
    end
    local completed = math.max(0, math.min(total, state.cursor - 1))
    return completed / total
end

local function render_micro_progress()
    local state = active_progress_state()
    if state == nil then
        return
    end

    local width = 220.0
    if imgui.GetWindowWidth ~= nil then
        width = math.max(80.0, (tonumber(imgui.GetWindowWidth()) or 252.0) - 32.0)
    end
    local fraction = progress_fraction(state)
    if imgui.GetWindowDrawList ~= nil and imgui.GetCursorScreenPos ~= nil and imgui.Dummy ~= nil then
        local draw = imgui.GetWindowDrawList()
        if draw ~= nil and draw.AddRectFilled ~= nil then
            local x, y = imgui.GetCursorScreenPos()
            local track = imgui.GetColorU32 ~= nil and imgui.GetColorU32(UI_COLORS.progress_track) or UI_COLORS.progress_track
            local fill = imgui.GetColorU32 ~= nil and imgui.GetColorU32(UI_COLORS.blue_highlight) or UI_COLORS.blue_highlight
            draw:AddRectFilled({ x, y }, { x + width, y + 3.0 }, track, 999.0)
            draw:AddRectFilled({ x, y }, { x + (width * fraction), y + 3.0 }, fill, 999.0)
            imgui.Dummy({ width, 3.0 })
            return
        end
    end
    if imgui.ProgressBar ~= nil then
        imgui.ProgressBar(fraction, { width, 3.0 }, "")
    end
end

local layout_choice

local function draft_keep_value(draft)
    if draft.mode == "all" then return "all" end
    if draft.mode == "number" then return draft.quantity[1] end
    return nil
end

local function draft_item_rule(draft)
    return { carry_target=draft.carry_target[1], destination=draft.destination,
        deposit=draft.deposit[1] == true }
end

local function legacy_item_allowed(item_id)
    local resource=AshitaCore:GetResourceManager():GetItemById(item_id)
    local item={item_id=item_id,resource_type=tonumber(resource and resource.Type) or 0,
        resource_flags=tonumber(resource and resource.Flags) or 0,
        equippable=is_equipment(resource),slot_category=slot_name_from_mask(tonumber(resource and resource.Slots) or 0)}
    return storage_layout.effective_allowed(preferences.storage_layout,preferences.background,item)
end

local function item_rule_equal(left, right)
    if left == nil or right == nil then return left == right end
    return left.carry_target == right.carry_target and left.destination == right.destination
        and left.deposit == right.deposit
end

local function new_item_draft(selected, keep, snapshot)
    local rule, err = item_rules.for_item(preferences.item_rules,selected.id)
    if err then return nil, err end
    local quantity = type(keep[tostring(selected.id)]) == "number" and keep[tostring(selected.id)]
        or EPHEMERAL_ITEMS[selected.id] and 24 or 1
    local default_target = 0
    if not rule and snapshot then
        local _,_,_,effective = get_keep_reservations(snapshot)
        default_target=item_rules.carry_target(effective and effective.items[tostring(selected.id)])
    end
    return {
        item_id=selected.id, character=get_player_slug(),
        mode=keep[tostring(selected.id)] == "all" and "all"
            or type(keep[tostring(selected.id)]) == "number" and keep[tostring(selected.id)] > 0 and "number" or "none",
        quantity={quantity}, allowed={legacy_item_allowed(selected.id)},
        item_rule_present=rule ~= nil, item_rule_dirty=false, clear_item_rule=false,
        carry_target={rule and rule.carry_target or default_target}, default_carry_target=default_target,
        destination=rule and rule.destination or "default",
        deposit={rule and rule.deposit or false},
    }
end

local function item_rule_summary(rule)
    if not rule then return nil end
    local destination = rule.destination == "default" and "default placement"
        or rule.destination == "stay" and "leave extras in place"
        or CONTAINERS[rule.destination] or "unknown bag"
    local parts = {}
    if rule.carry_target > 0 then parts[#parts + 1] = ("carry %u"):format(rule.carry_target) end
    parts[#parts + 1] = "extras to " .. destination
    if rule.deposit then parts[#parts + 1] = "donate extra crystals" end
    return table.concat(parts,"; ")
end

local function temporary_hold_label(item_id)
    local held = automatic.owner == get_player_slug() and automatic.holds[tostring(item_id)] or nil
    if held == true then return "all copies this session" end
    if type(held) ~= "table" then return nil end
    local locations, total = {}, 0
    for bag, quantity in pairs(held) do
        local id, amount = tonumber(bag), tonumber(quantity) or 0
        if amount > 0 then
            locations[#locations + 1] = {bag=id,quantity=amount}
            total = total + amount
        end
    end
    table.sort(locations,function(a,b) return a.bag < b.bag end)
    local labels = {}
    for _, entry in ipairs(locations) do
        labels[#labels + 1] = ("%u in %s"):format(entry.quantity,CONTAINERS[entry.bag] or tostring(entry.bag))
    end
    if total == 0 then return nil end
    return table.concat(labels,", ")
end

local function item_settings_preview(selected, snapshot, draft)
    local keep = {}
    for id, quantity in pairs(assert(current_keep_rules())) do keep[id] = quantity end
    keep[tostring(selected.id)] = draft_keep_value(draft)
    local data = {version=1,items={}}
    for id, rule in pairs((preferences.item_rules and preferences.item_rules.items) or {}) do
        data.items[id] = {carry_target=rule.carry_target,destination=rule.destination,deposit=rule.deposit}
    end
    if draft.clear_item_rule then
        data.items[tostring(selected.id)] = nil
    elseif draft.item_rule_present or draft.item_rule_dirty then
        data.items[tostring(selected.id)] = draft_item_rule(draft)
    end
    local holds = automatic.owner == get_player_slug() and automatic.holds or {}
    if automatic.owner == get_player_slug() then
        local _, current_totals=item_rules.reconcile_overrides(holds,snapshot.items,automatic.hold_counts)
        automatic.hold_counts=current_totals or {}
    end
    local effective = item_rules.with_default_supplies(snapshot,keep,data,holds,preferences.storage_layout,
        preferences.background and preferences.background.free_slots or 5)
    local reserved = assert(item_rules.allocate(snapshot.items,keep,effective,holds))
    local refill = assert(item_rules.refill_reservations(snapshot.items,reserved,effective))
    local routes = storage_layout.active_routes(preferences.storage_layout)
    local probe = {item_id=selected.id,item_name=selected.name,
        equippable=is_equipment(AshitaCore:GetResourceManager():GetItemById(selected.id))}
    for _, item in ipairs(snapshot.items) do
        if item.item_id == selected.id then probe=item; break end
    end
    local base_target = storage_layout.target(preferences.storage_layout,probe)
    local default_destination = base_target ~= false and base_target or nil
    local default_allowed = draft.allowed[1]
    local rule = data.items[tostring(selected.id)]
    local destination, mode = item_rules.destination(rule,default_destination)
    if base_target == false and mode == 'default' then mode='stay' end
    local allowed = item_rules.allows_storage(rule,default_allowed)
    local result = { ignored=0, inventory=0, stored=0, store_quantity=0, store_slots=0,
        deposit_quantity=0, held=temporary_hold_label(selected.id) ~= nil,
        carried=selected.carried, carry_target=item_rules.carry_target(effective and effective.items[tostring(selected.id)]),
        refill_quantity=0, destination=destination, destination_mode=mode,
        destination_name=mode=="specific" and CONTAINERS[destination] or mode=="stay" and "Leave where it is"
            or destination and CONTAINERS[destination] or "Default placement" }
    local equipped = ui.items_equipped or {}
    local resource = AshitaCore:GetResourceManager():GetItemById(selected.id)
    local destination_quantity, destination_stack_room, destination_empty = 0, 0, 0
    if destination and destination ~= 2 then
        destination_quantity = selected.locations[destination] or 0
        destination_stack_room = math.max(0,selected.stack_size-destination_quantity)
        destination_empty = math.max(0,(snapshot.capacities[destination] or 0)-(snapshot.counts[destination] or 0))
    end
    for _, item in ipairs(snapshot.items) do
        if item.item_id == selected.id then
            local ignored = reserved[item_key(item.container_id, item.index)] or 0
            local refill_reserved = refill[item_key(item.container_id,item.index)] or 0
            result.ignored = result.ignored + ignored
            if item.container_id == 0 then result.inventory = result.inventory + ignored
            else result.stored = result.stored + ignored end
            result.refill_quantity = result.refill_quantity + refill_reserved
            local locked = bit.band(item.flags or 0, 1) ~= 0
            local available = math.max(0,item.quantity-ignored-refill_reserved)
            if allowed and mode ~= "stay" and item.container_id == 0 and ignored == 0
                and refill_reserved == 0 and available == item.quantity and not locked
                and not equipped[item_key(0,item.index)] and not is_social_item(item) and resource then
                local can_store = destination == nil and mode == "default" and routes == nil
                    or destination ~= nil and destination ~= 2
                        and (destination_empty > 0 or destination_stack_room >= item.quantity)
                if can_store then
                    result.store_quantity = result.store_quantity + item.quantity
                    result.store_slots = result.store_slots + 1
                    if destination_empty > 0 then destination_empty = destination_empty - 1
                    elseif destination_stack_room >= item.quantity then destination_stack_room = destination_stack_room - item.quantity end
                elseif destination ~= nil and destination ~= 2 then result.destination_blocked = true end
            end
            if EPHEMERAL_ITEMS[item.item_id] and item.container_id ~= 2 then
                local deposit_allowed = rule and rule.deposit == true
                    and (item.container_id == 0 or item.container_id == rule.destination)
                    or rule == nil and draft.allowed[1]
                if deposit_allowed and (item.container_id ~= 0 or not locked) then
                    result.deposit_quantity = result.deposit_quantity + available
                end
            end
        end
    end
    result.refill_missing = math.max(0,result.carry_target-result.carried-result.refill_quantity)
    result.route_active = preferences.background.enabled == true or preferences.sort_enabled == true
    if destination == 2 then result.route_status = "Bulk run only"
    elseif destination and mode ~= "stay" and (snapshot.capacities[destination] or 0) == 0 then result.route_status = "Unavailable or locked"
    elseif result.destination_blocked then result.route_status = "Full; no fallback"
    elseif mode == "stay" then result.route_status = "Extra copies stay put"
    elseif mode == "specific" then result.route_status = "Exact destination"
    else result.route_status = "Uses the current default" end
    return result
end

local function item_draft_changes(selected, draft, rule)
    local saved = (preferences.item_rules and preferences.item_rules.items[tostring(selected.id)]) or nil
    -- Returning an inherited rule to its initial controls must not materialize
    -- an explicit rule (which could change inherited deposit permission).
    if not saved and not draft.clear_item_rule and draft.carry_target[1] == (draft.default_carry_target or 0)
        and draft.destination == "default" and not draft.deposit[1] then
        draft.item_rule_dirty = false
    end
    local changed = draft.clear_item_rule and saved ~= nil
        or draft.item_rule_dirty and not item_rule_equal(saved,draft_item_rule(draft))
    local allowed = draft.destination == "default" and draft.allowed[1] ~= legacy_item_allowed(selected.id)
    return draft.save_failed or draft_keep_value(draft) ~= rule or allowed or changed, allowed, saved
end

local function render_protections(embedded)
    if not embedded and not ui.protections_visible then return end
    local visible, pushed = true, nil
    local notice_shown = false
    if not embedded then
        imgui.SetNextWindowSize({ 560, 660 }, global("ImGuiCond_FirstUseEver") or 0)
        pushed = push_ui_style()
        local open = { true }
        visible = imgui.Begin("OddOrg - Item rules", open, 0)
        ui.protections_visible = open[1]
    end
    if visible then
        local keep, err = current_keep_rules()
        if not keep then
            imgui.TextWrapped(err)
        elseif not item_rules.validate(preferences.item_rules) then
            local _, rules_err = item_rules.validate(preferences.item_rules)
            imgui.TextWrapped(rules_err or "Per-item settings are invalid.")
        else
            if ui.items_checked_at ~= os.time() then
                ui.items_snapshot = collect_live_items()
                ui.items_equipped = collect_equipped_keys(true)
                ui.items_checked_at = os.time()
            end
            local snapshot = ui.items_snapshot
            if not snapshot then
                imgui.TextWrapped("Waiting for inventory data.")
            else
                -- The browser stays in place while the selected item's detail scrolls.
                local split = embedded == true
                if split then imgui.BeginChild("oddorg_item_browser", { 248 * ui_scale(), 0 }, false) end
                ui_text("FIND AN ITEM", UI_COLORS.gold)
                if imgui.PushItemWidth then imgui.PushItemWidth(math.max(1, imgui.GetContentRegionAvail() - 1)) end
                imgui.InputText("##ignore_search", ui.filter, 128)
                skin.control_finish(imgui,nil,false,'ignore_search')
                if imgui.PopItemWidth then imgui.PopItemWidth() end
                local rows, ordered = {}, {}
                for _, item in ipairs(snapshot.items) do
                    local row = rows[item.item_id] or { id=item.item_id, name=item.item_name, carried=0, total=0, stack_size=item.stack_size, locations={} }
                    row.total = row.total + item.quantity
                    row.locations[item.container_id] = (row.locations[item.container_id] or 0) + item.quantity
                    if item.container_id == 0 then row.carried = row.carried + item.quantity end
                    rows[item.item_id] = row
                end
                local known_rules = {}
                for id in pairs(keep) do known_rules[id] = true end
                for id in pairs(automatic.holds) do known_rules[id] = true end
                for id in pairs((preferences.background and preferences.background.items) or {}) do known_rules[id] = true end
                for id in pairs((preferences.item_rules and preferences.item_rules.items) or {}) do known_rules[id] = true end
                for id in pairs(known_rules) do
                    local item_id = tonumber(id)
                    if not rows[item_id] then
                        rows[item_id] = { id=item_id, carried=0, total=0,
                            stack_size=stack_size_for(AshitaCore:GetResourceManager():GetItemById(item_id)),
                            name=first_resource_name(AshitaCore:GetResourceManager():GetItemById(item_id)) }
                    end
                end
                for _, row in pairs(rows) do ordered[#ordered + 1] = row end
                table.sort(ordered, function(a, b)
                    if a.name ~= b.name then return a.name < b.name end
                    return a.id < b.id
                end)
                imgui.BeginChild("oddorg_items", { 0, split and 0 or 120 }, true)
                local shown = 0
                for _, row in ipairs(ordered) do
                    if string.lower(row.name):find(string.lower(ui.filter[1]), 1, true)
                        or tostring(row.id) == ui.filter[1] then
                        local rule = keep[tostring(row.id)]
                        local label = ("%s##keep_%u"):format(row.name, row.id)
                        if skin.icon(imgui,nil,24*ui_scale(),row.id) then same_line() end
                        local row_selected = ui.selected_item_id == row.id
                        local row_clicked = imgui.Selectable(label, row_selected)
                        skin.control_finish(imgui,row_selected,false,'item_browser:'..tostring(row.id))
                        if row_clicked then
                            if ui.item_draft then
                                ui.item_draft_cache[tostring(ui.item_draft.item_id)] = ui.item_draft
                            end
                            ui.selected_item_id = row.id
                            ui.item_draft = ui.item_draft_cache[tostring(row.id)]
                            ui.notice = nil
                        end
                        if imgui.IsItemHovered and imgui.IsItemHovered() and imgui.SetTooltip then imgui.SetTooltip(row.name) end
                        local saved_outcome = (preferences.item_rules and preferences.item_rules.items[tostring(row.id)]) or nil
                        local outcome_text = item_rule_summary(saved_outcome)
                        local held_text = temporary_hold_label(row.id)
                        local detail = held_text and (" / temporary: " .. held_text)
                            or outcome_text and (" / " .. outcome_text)
                            or rule and (" / ignore " .. tostring(rule)) or ""
                        ui_wrapped_text(("%u in Inventory / %u total%s"):format(row.carried, row.total,detail), UI_COLORS.muted)
                        shown = shown + 1
                    end
                end
                if shown == 0 then imgui.TextWrapped("No matching items or saved rules.") end
                imgui.EndChild()
                if split then
                    imgui.EndChild()
                    same_line()
                    imgui.BeginChild("oddorg_item_detail", { 0, 0 }, false)
                end

                local selected = rows[ui.selected_item_id]
                local config = preferences.background
                if selected and housekeeping.validate(config) then
                    local rule = keep[tostring(selected.id)]
                    local draft = ui.item_draft
                    if not draft or draft.item_id ~= selected.id or draft.character ~= get_player_slug() then
                        draft = ui.item_draft_cache[tostring(selected.id)]
                    end
                    if not draft or draft.character ~= get_player_slug() then
                        draft = new_item_draft(selected,keep,snapshot)
                        ui.item_draft = draft
                    end
                    if skin.icon(imgui,nil,40*ui_scale(),selected.id) then same_line() end
                    skin.heading(imgui, selected.name, 1.2, UI_COLORS.text)
                    -- Only the editor scrolls. Apply stays reachable below it.
                    local pending = item_draft_changes(selected,draft,rule)
                    local recently_saved = draft.saved_until and os.clock() < draft.saved_until
                    local footer_height = pending and 70 * ui_scale() or recently_saved and 28 * ui_scale() or 0
                    local editor_open = imgui.BeginChild("oddorg_item_choices", { 0, -footer_height }, false)
                    if editor_open then
                    -- One consistent preview per frame; edits appear on the next draw.
                    local result = item_settings_preview(selected, snapshot, draft)
                    ui_text("CURRENT STOCK", UI_COLORS.gold)
                    ui_tooltip("Current quantities in each bag. These rules also apply to future copies. Apply saves this item's rules.")
                    skin.locations(imgui,selected.locations,CONTAINERS,ui_scale())
                    if selected.total == 0 then ui_wrapped_text("None in your bags. This rule also applies to future copies.", UI_COLORS.muted) end
                    if not draft.item_rule_dirty and (not draft.item_rule_present or draft.clear_item_rule) then
                        draft.carry_target[1],draft.default_carry_target=result.carry_target,result.carry_target
                    end
                    ui_text("KEEP IN INVENTORY", UI_COLORS.gold)
                    ui_tooltip("OddOrg Default keeps one stack of recognized combat supplies when the empty-slot budget allows. A saved item target overrides that budget; 0 disables refill for this item. Free Inventory slots must be enabled to restock.")
                    if imgui.PushItemWidth then imgui.PushItemWidth(150*ui_scale()) end
                    if imgui.InputInt("##item_carry_target",draft.carry_target) then
                        draft.carry_target[1]=math.max(0,math.min(99999,draft.carry_target[1]))
                        draft.item_rule_dirty,draft.clear_item_rule=true,false
                    end
                    skin.control_finish(imgui,nil,false,'item_carry_target')
                    ui_tooltip("Set a target in individual items, not stacks. Automatic care refills from accessible bags; 0 means no refill target.")
                    if imgui.PopItemWidth then imgui.PopItemWidth() end
                    if selected.stack_size > 1 then
                        same_line()
                        if ui_button(("+1 stack (+%u)##item_carry_stack"):format(selected.stack_size),false,false) then
                            draft.carry_target[1]=math.min(99999,draft.carry_target[1]+selected.stack_size)
                            draft.item_rule_dirty,draft.clear_item_rule=true,false
                        end
                        ui_tooltip("Add one full stack to the current carry target.")
                    end
                    if result.carried > 0 or result.carry_target > 0 then
                        ui_wrapped_text(("Carrying now: %u items | Target: %u")
                            :format(result.carried,result.carry_target),UI_COLORS.blue_highlight)
                    end
                    if result.carry_target > result.carried then
                        ui_wrapped_text(("Refill stock: %u available in other bags; %u still missing.")
                            :format(result.refill_quantity,result.refill_missing),UI_COLORS.muted)
                    end
                    imgui.Separator()
                    local selected_resource=AshitaCore:GetResourceManager():GetItemById(selected.id)
                    local compatible_gear=is_equipment(selected_resource)
                    local destination_choices={
                        {value="default",label="Use default placement"},
                        {value="stay",label="Leave extras where they are"},
                    }
                    for _,bag in ipairs(SCANNED_CONTAINERS) do
                        if bag~=0 and (not GEAR_ONLY_CONTAINERS[bag] or compatible_gear) then
                            local access=(snapshot.capacities[bag] or 0)==0 and " (locked or unavailable)"
                                or bag==2 and " (bulk run only)" or ""
                            destination_choices[#destination_choices+1]={value=bag,label=CONTAINERS[bag]..access}
                        end
                    end
                    ui_text("TARGET STORAGE PLACEMENT",UI_COLORS.gold)
                    ui_tooltip("Choose the home for new stacks. Automatic care fills compatible existing stacks first, even in another bag. Bulk Run applies this destination after consolidation. Automatic moves require a character automation switch.")
                    local prior_destination=draft.destination
                    draft.destination=layout_choice("##item_destination",draft.destination,destination_choices,
                        math.max(1,imgui.GetContentRegionAvail()-1))
                    if draft.destination~=prior_destination then
                        draft.item_rule_dirty,draft.clear_item_rule=true,false
                        if type(draft.destination)~="number" or draft.destination==2 then draft.deposit[1]=false end
                    end
                    local route_text=draft.destination=="default" and "Follows your storage layout, starting from OddOrg defaults."
                        or draft.destination=="stay" and "Extra copies stay in their current bags."
                        or draft.destination==2 and "Storage is used only by a manual bulk run."
                        or (snapshot.capacities[draft.destination] or 0)==0 and "This exact bag is locked or unavailable; no alternate bag will be chosen."
                        or "This exact bag is used. If it is full, the item stays put until room is available."
                    ui_tooltip(route_text.."\nDestination: "..result.destination_name.." - "..result.route_status..".")
                    local crystal = EPHEMERAL_ITEMS[selected.id] ~= nil
                    if draft.destination=="default" then
                        local routes=storage_layout.active_routes(preferences.storage_layout)
                        local _, assigned=automatic.item_allowed(selected.id)
                        if assigned or not routes then
                            imgui.Checkbox((routes and "Allow this quickset to move extras" or "Allow automatic storing").."##ignore_auto",draft.allowed)
                            skin.control_finish(imgui,draft.allowed[1],false,'ignore_auto')
                            local permission_help = draft.allowed[1]
                                and "Allows this item to follow your automatic storage layout. Character automation switches must also be enabled."
                                or routes
                                    and "Excluded from automatic care and quickset organization. Ignore all also protects it from manual crystal deposits."
                                    or "Automatic actions are off for this item. Your manual Organize/Deposit actions can still use items you did not ignore."
                            if not result.route_active then
                                permission_help = permission_help .. "\nAutomatic movement is off for this character. Enable automatic care to use this permission."
                            end
                            ui_tooltip(permission_help)
                        else
                            draft.allowed[1]=false
                            ui_wrapped_text("This item type has no route in the active quickset. Choose a specific bag to add one.",UI_COLORS.muted)
                        end
                    end
                    if result.route_active and (result.store_quantity > 0 or result.store_slots > 0) then
                        imgui.TextWrapped(("Eligible to store: %u items, freeing %u whole Inventory slots.")
                            :format(result.store_quantity,result.store_slots))
                        if draft.allowed[1] and selected.carried-result.inventory > result.store_quantity then
                            ui_tooltip("Some remaining items share an ignored, carried-target, or temporary-hold stack; automatic moves leave those stacks in Inventory.")
                        end
                    end
                    if result.destination_blocked then imgui.TextWrapped("The chosen bag is full. OddOrg will wait there and will not choose a different bag.") end
                    if crystal then
                        ui_text("MOOGLE DEPOSITS",UI_COLORS.gold)
                        ui_tooltip("Select an accessible staging bag to allow deposits. Storage routes alone never grant deposit permission. The character Moogle switch must also be on.")
                    end
                    local can_stage=EPHEMERAL_ITEMS[selected.id]~=nil and type(draft.destination)=="number" and draft.destination~=2
                    if can_stage then
                        if imgui.Checkbox("Deposit extra crystals at an Ephemeral Moogle##item_deposit",draft.deposit) then
                            draft.item_rule_dirty,draft.clear_item_rule=true,false
                        end
                        skin.control_finish(imgui,draft.deposit[1],false,'item_deposit')
                        ui_tooltip("The selected bag is the staging location. Deposits still require the character Moogle switch.")
                    elseif EPHEMERAL_ITEMS[selected.id] then
                        if draft.deposit[1] then draft.deposit[1]=false; draft.item_rule_dirty=true end
                    end
                    if crystal then
                        local explicit_rule=not draft.clear_item_rule and (draft.item_rule_present or draft.item_rule_dirty)
                        local donation_allowed=explicit_rule and draft.deposit[1] or not explicit_rule and draft.allowed[1]
                        imgui.TextWrapped(donation_allowed
                            and (preferences.deposit_enabled
                                and (explicit_rule
                                    and ("Nearby Moogle: up to %u items can be deposited from Inventory or the selected staging bag."):format(result.deposit_quantity)
                                    or ("Nearby Moogle: up to %u items can be deposited under the existing item rules."):format(result.deposit_quantity))
                                or "Moogle deposits paused: character switch is off.")
                            or "Moogle deposits off for this item.")
                    end
                    imgui.Separator()
                    ui_text("LEAVE COPIES UNTOUCHED", UI_COLORS.gold)
                    ui_tooltip("Ignored copies stay in their current bags, even during manual actions. This does not refill Inventory.")
                    local choice_width = math.max(1, (imgui.GetContentRegionAvail() - 24) / 3)
                    local choice_size = { choice_width, 36 * ui_scale() }
                    if ui_button("Ignore all##ignore_all", draft.mode == "all", false, false, choice_size) then draft.mode = "all" end
                    ui_tooltip("Every copy stays where it is. No moves or deposits.")
                    same_line()
                    if ui_button("Ignore amount##ignore_number", draft.mode == "number", false, false, choice_size) then draft.mode = "number" end
                    ui_tooltip("Protect a quantity of individual items, starting with Inventory.")
                    same_line()
                    if ui_button("Ignore none##ignore_none", draft.mode == "none", false, false, choice_size) then draft.mode = "none" end
                    ui_tooltip("No copies are protected by the Ignore rule. Carry targets and temporary holds still apply.")
                    if draft.mode == "number" then
                        if imgui.PushItemWidth then imgui.PushItemWidth(130 * ui_scale()) end
                        imgui.InputInt("Items to ignore##ignore_quantity", draft.quantity)
                        skin.control_finish(imgui,nil,false,'ignore_quantity')
                        if imgui.PopItemWidth then imgui.PopItemWidth() end
                        draft.quantity[1] = math.max(0, math.min(99999, draft.quantity[1]))
                        -- Keep the scale steady while dragging, including amounts above current stock.
                        draft.slider_max = math.min(99999, math.max(draft.slider_max or 1, selected.total, draft.quantity[1]))
                        local ceiling = draft.slider_max
                        if imgui.PushItemWidth then imgui.PushItemWidth(math.max(1, imgui.GetContentRegionAvail() - 1)) end
                        if imgui.SliderInt then imgui.SliderInt("##ignore_slider", draft.quantity, 0, ceiling, "%d items") end
                        skin.control_finish(imgui,nil,false,'ignore_slider')
                        if imgui.PopItemWidth then imgui.PopItemWidth() end
                        draft.quantity[1] = math.max(0, math.min(99999, draft.quantity[1]))
                        ui_tooltip(("0 to %u items. Type a larger amount above if needed."):format(ceiling))
                        if selected.stack_size > 1 then
                            if ui_button(("+1 stack (+%u)##ignore_stack"):format(selected.stack_size), false, false) then
                                draft.quantity[1] = math.min(99999,draft.quantity[1]+selected.stack_size)
                            end
                            ui_tooltip("Add one full stack to the quantity left untouched.")
                        end
                    end
                    if result.inventory > 0 or result.stored > 0 then
                        ui_wrapped_text(("Reserved from moves: %u in Inventory; %u in other bags.")
                            :format(result.inventory,result.stored),UI_COLORS.blue_highlight)
                        ui_tooltip("Includes your carry target, ignored copies, and temporary holds.")
                    end
                    if draft.mode == "number" and draft.quantity[1] > selected.total then
                        ui_wrapped_text(("You own %u. Ignore also covers the next %u you collect.")
                            :format(selected.total,draft.quantity[1]-selected.total),UI_COLORS.muted)
                    end
                    local held_text=temporary_hold_label(selected.id)
                    if held_text then
                        ui_text("TEMPORARY MANUAL CHOICE",UI_COLORS.gold)
                        ui_wrapped_text("Leave "..held_text.." untouched this session. The held quantity shrinks as stock is consumed.",UI_COLORS.muted)
                        if ui_button("Release temporary choice##release_hold", false, false) then
                            cancel_queues("temporary item pause ended")
                            item_rules.release_override(automatic.holds,selected.id)
                            ui.notice = "Temporary manual choice released. Saved rules apply; unsaved edits remain a preview."
                        end
                    end
                    if draft.item_rule_present and ui_button("Use defaults for this item##clear_item_rule",false,false) then
                        draft.clear_item_rule=true
                        draft.item_rule_dirty=false
                        draft.destination="default"; draft.carry_target[1]=0; draft.deposit[1]=false
                    end
                    if ui.notice then ui_wrapped_text(ui.notice, UI_COLORS.muted) end
                    end
                    imgui.EndChild()
                    notice_shown = true
                    local dirty, allowed_changed, saved_item_rule = item_draft_changes(selected,draft,rule)
                    local edited_item_rule = draft_item_rule(draft)
                    -- Reserve space on the next frame before adding a new footer.
                    if dirty and pending then
                        ui_text(draft.save_failed and "Not saved - retry Apply" or "Unsaved changes",UI_COLORS.attention)
                    elseif not dirty and recently_saved then
                        ui_text("Saved item rules",UI_COLORS.muted)
                    end
                    if dirty and pending and ui_button("Apply item settings##ignore_apply", true, false, false, { 240 * ui_scale(), 36 * ui_scale() }) then
                        local allowed
                        if allowed_changed then allowed=draft.allowed[1] end
                        local item_rule_update
                        if draft.clear_item_rule then item_rule_update=false
                        elseif draft.item_rule_dirty then item_rule_update=edited_item_rule end
                        if draft.character == get_player_slug() then
                            draft.save_failed = not set_keep_rule(selected.id, draft_keep_value(draft), allowed, item_rule_update)
                            -- settings.reload clears the editor, including a failed-save retry.
                            if draft.character == get_player_slug() then
                                ui.selected_item_id, ui.item_draft = selected.id, draft
                            end
                            if not draft.save_failed then
                                draft.item_rule_present=item_rule_update~=false and (item_rule_update~=nil or saved_item_rule~=nil)
                                draft.item_rule_dirty,draft.clear_item_rule=false,false
                                ui.item_draft_cache[tostring(selected.id)]=nil
                                dirty = false
                                draft.saved_until = os.clock() + 3
                                ui.notice = nil
                            end
                        end
                    end
                elseif selected then
                    imgui.TextWrapped("Automatic item settings are invalid. Fix them before editing this item.")
                else
                    skin.icon(imgui,'ignored',80*ui_scale())
                    skin.heading(imgui, "Keep what matters.", 1.3, UI_COLORS.text)
                    imgui.TextWrapped("Choose how OddOrg handles your items.")
                end
                if split then
                    if ui.notice and not notice_shown then imgui.TextWrapped(ui.notice); notice_shown = true end
                    imgui.EndChild()
                end
            end
        end
        if ui.notice and not notice_shown then imgui.TextWrapped(ui.notice) end
    end
    if not embedded then
        imgui.End()
        pop_ui_style(pushed)
    end
end

local function render_preview()
    if not ui.preview_visible or not ui.preview_plan then return end
    local plan = ui.preview_plan
    ui_text((plan.stacking and "Stack consolidation: " or "")
        ..("%u item moves; %u items kept in place."):format(#plan.logical_moves, plan.kept_quantity),UI_COLORS.text)
    if plan.batch_limited then ui_tooltip("This batch stops at a safe boundary within 50 transfers. Use View Plan afterward to continue remaining work.") end
    if plan.stacking then ui_tooltip("Bulk Run combines partial stacks first, then moves completed stacks to their configured homes.") end
    if imgui.BeginChild("oddorg_preview_moves", { 0, 0 }, true) then
        skin.panel(imgui,'slot',0.3)
        if (plan.default_blocked or 0) > 0 then
            imgui.TextWrapped(("%u stacks left in place: default homes are full or unavailable."):format(plan.default_blocked))
        elseif #plan.logical_moves == 0 then imgui.TextWrapped("Nothing needs moving in this scope.") end
        for _, move in ipairs(plan.logical_moves) do
            if skin.icon(imgui,nil,24*ui_scale(),move.item_id) then same_line() end
            imgui.TextWrapped(("%s x%u: %s -> %s"):format(move.item_name, move.quantity,
                CONTAINERS[move.source_container_id], CONTAINERS[move.target_container_id]))
        end
    end
    imgui.EndChild()
end

layout_choice = function(id, value, choices, width)
    local label = tostring(value or "")
    for _, entry in ipairs(choices) do if entry.value == value then label = entry.label end end
    if imgui.PushItemWidth then imgui.PushItemWidth(width) end
    local result = value
    if imgui.BeginCombo then
        local combo_open = imgui.BeginCombo(id,label)
        skin.control_finish(imgui,nil,false,'combo:'..tostring(id))
        if combo_open then
            for _, entry in ipairs(choices) do
                local selected = entry.value == value
                local clicked = imgui.Selectable(entry.label .. "##" .. id .. tostring(entry.value), selected)
                skin.control_finish(imgui,selected,false,'combo_option:'..tostring(id)..':'..tostring(entry.value))
                if clicked then result = entry.value end
            end
            imgui.EndCombo()
        end
    elseif not imgui.BeginCombo then ui_text(label) end
    if imgui.PopItemWidth then imgui.PopItemWidth() end
    return result
end

local function quickset_choices(data)
    local result = { {value="",label="OddOrg Default"} }
    -- Retain an already selected legacy preset without offering new canned choices.
    if data and storage_layout.preset(data.active) then
        result[#result+1]={value=data.active,label=storage_layout.name(data.active).." (previous layout)"}
    end
    local names = {}
    for name in pairs(data and data.sets or {}) do names[#names+1]=name end
    table.sort(names)
    for _, name in ipairs(names) do result[#result+1]={value=name,label=name} end
    return result
end

local function classification_help(key, snapshot)
    local descriptions = {
        item = "Miscellaneous materials and objects with different uses. This mixed group is not a junk category.",
        quest_item = "Objects associated with quests. Being in this group does not tell you whether you still need them.",
        usable_item = "Items you activate or consume for an effect, such as supplies and consumables.",
        linkshell = "Linkshell communication items used to join or manage a linkshell.",
        furnishing = "Furniture and decorations for your Mog House.",
        scroll = "Scrolls used to learn magic or other abilities.",
        crystals = "Individual elemental crystals used in synthesis.",
        clusters = "Bundles that can be used to obtain elemental crystals. Counts here are clusters, not the crystals inside.",
        fish = "Fish and other catches grouped as fish.",
        currency = "Physical currency items held in bags, rather than your gil balance.",
        plant = "Plants and gardening-related items in the plant category.",
        flowerpot = "Containers used for gardening in your Mog House.",
        puppet_item = "Items for customizing an automaton.",
        mannequin = "Mannequin-related items used for equipment displays.",
        book = "Books and book-like items with assorted uses.",
        racing_form = "Forms associated with chocobo racing.",
        betting_slip = "Slips associated with wagers.",
        soul_plate = "Plates that record information about a monster.",
        reflector = "Reflector items associated with monster-based activities.",
        logs = "Items in the game's Logs category; check the examples for the stock this includes.",
        lottery_ticket = "Tickets for lottery participation.",
        tabula_m = "Maze tabulae used to configure a maze.",
        tabula_r = "Rallying tabulae used for rallying activities.",
        voucher = "Vouchers exchanged or redeemed for a service or reward.",
        rune = "Rune items used to customize maze content.",
        evolith = "Stones used in the evolith equipment-enhancement system.",
        storage_slip = "Slips that track equipment entrusted to a Porter Moogle.",
        instinct = "Instinct items associated with monster abilities and traits.",
        unknown = "Items OddOrg cannot place in a supported type. They are not necessarily unusable or unwanted.",
    }
    local category = storage_layout.by_key[key]
    local description = descriptions[key]
    if not description and category and category.gear then
        description = key == 'gear.other' and "Equipment without a recognized equipment slot."
            or (category.label .. ": equipment grouped by where it is worn or wielded.")
    end
    local examples, seen = {}, {}
    for _, item in ipairs(snapshot and snapshot.items or {}) do
        if (storage_layout.classify(item) or "unknown") == key
            and not seen[item.item_id] and type(item.item_name) == "string" and item.item_name ~= "" then
            examples[#examples+1] = item.item_name
            seen[item.item_id] = true
            if #examples == 2 then break end
        end
    end
    return (description or descriptions.unknown) .. (#examples > 0
        and ("\nExamples from your bags: "..table.concat(examples, ", ")..".")
        or "\nNo matching examples in the current bag snapshot.")
end

local function classification_tooltip(key, plan)
    if not ((imgui.IsItemHovered and imgui.IsItemHovered())
        or (imgui.IsItemFocused and imgui.IsItemFocused())) then return end
    -- Reuse the item browser's character-scoped snapshot; collect only on hover.
    if not plan and ui.items_checked_at ~= os.time() then
        ui.items_snapshot = collect_live_items()
        ui.items_equipped = collect_equipped_keys(true)
        ui.items_checked_at = os.time()
    end
    ui_tooltip(classification_help(key, plan and plan.snapshot or ui.items_snapshot)
        .. (plan and "\nCount: individual items projected in this bag after the plan, including copies left untouched." or ""))
end

local function render_layout_map(routes, plan)
    local grouped = {}
    if plan and plan.snapshot then
        local moved = {}
        for _, move in ipairs(plan.logical_moves) do moved[item_key(move.source_container_id,move.source_index)] = move end
        local function add(bag, item, quantity)
            if quantity <= 0 then return end
            local key = storage_layout.classify(item) or "unknown"
            grouped[bag] = grouped[bag] or {}
            grouped[bag][key] = (grouped[bag][key] or 0) + quantity
        end
        for _, item in ipairs(plan.snapshot.items) do
            local move = moved[item_key(item.container_id,item.index)]
            add(item.container_id,item,item.quantity-(move and move.quantity or 0))
            if move then add(move.target_container_id,item,move.quantity) end
        end
    else
        for key, bag in pairs(routes or {}) do grouped[bag]=grouped[bag] or {}; grouped[bag][key]=0 end
    end
    local bag_ids = {}
    for bag in pairs(grouped) do bag_ids[#bag_ids+1]=bag end
    table.sort(bag_ids)
    if #bag_ids == 0 then
        ui_text("No custom destinations",UI_COLORS.text)
        ui_tooltip("Choose an item type and destination in Automatic care to build your layout.")
    end
    local art = require('ui_art')
    local width = imgui.GetContentRegionAvail()
    local gap, scale = 12*ui_scale(), ui_scale()
    local columns = math.max(1,math.floor((width+gap)/(280*scale+gap)))
    local card_width = math.max(1,(width-gap*(columns-1))/columns)
    local ordered_keys = {}
    for _, bag in ipairs(bag_ids) do
        local keys = {}
        for key in pairs(grouped[bag]) do keys[#keys+1]=key end
        table.sort(keys)
        ordered_keys[bag] = keys
    end
    for index, bag in ipairs(bag_ids) do
        local inner_width = math.max(1,card_width-36)
        local height = 32 + math.max(32*scale,
            skin.text_height(imgui,CONTAINERS[bag],inner_width-32*scale-12,1.1))
        for _,key in ipairs(ordered_keys[bag]) do
            local category = storage_layout.by_key[key]
            local label = (category and category.label or "Unclassified items")
                .. (plan and (": " .. grouped[bag][key] .. " items") or "")
            height = height + 10 + skin.text_height(imgui,label,inner_width)
        end
        if not plan and bag == 2 then
            height = height + 10 + skin.text_height(imgui,"Mog House bulk runs only",inner_width)
        end
        if (index-1)%columns > 0 and imgui.SameLine then imgui.SameLine(0,gap) end
        if imgui.BeginChild("layout_bag_"..bag,{card_width,math.ceil(height)},true) then
            skin.panel(imgui,'route',0.16)
            if skin.icon(imgui,art.bags[bag],32*ui_scale()) then same_line() end
            skin.heading(imgui,CONTAINERS[bag],1.1,UI_COLORS.gold)
            for _, key in ipairs(ordered_keys[bag]) do
                local category = storage_layout.by_key[key]
                ui_wrapped_text((category and category.label or "Unclassified items")
                    .. (plan and (": " .. grouped[bag][key] .. " items") or ""),UI_COLORS.text)
                classification_tooltip(key,plan)
            end
            if not plan and bag == 2 then ui_wrapped_text("Mog House bulk runs only",UI_COLORS.attention) end
        end
        imgui.EndChild()
    end
end

local function same_layout_routes(left, right)
    for key, value in pairs(left or {}) do if (right or {})[key] ~= value then return false end end
    for key, value in pairs(right or {}) do if (left or {})[key] ~= value then return false end end
    return true
end

local function render_layout_editor(busy)
    local valid, err = storage_layout.validate(preferences.storage_layout)
    if not valid then ui_wrapped_text(err,UI_COLORS.attention); return end
    local data = preferences.storage_layout or {version=1,active="",sets={}}
    local character = get_player_slug()
    local draft = ui.layout_draft
    if not draft or draft.character ~= character then
        local routes = data.active == '' and (data.overrides or {}) or storage_layout.routes_for(data,data.active) or {}
        draft = {character=character,selected=data.active,name={data.active ~= "" and storage_layout.name(data.active) or "My layout"},
            routes=storage_layout.clone(routes),category="crystals",bag=routes.crystals == false and -1 or routes.crystals or (data.active == '' and 0 or -1)}
        ui.layout_draft = draft
    end
    local width = imgui.GetContentRegionAvail()
    local choices = quickset_choices(data)
    local selected = draft.selected
    ui_text("STORAGE LAYOUT",UI_COLORS.gold)
    if #choices > 1 then
        ui_wrapped_text("Active: " .. (data.active == '' and 'OddOrg Default' or storage_layout.name(data.active)),UI_COLORS.blue_highlight)
        selected = layout_choice("##layout_saved",draft.selected,choices,width-1)
        ui_tooltip(draft.selected == '' and 'Start with OddOrg placement. Change only the item types you want stored differently.'
            or 'Editing an existing saved layout. Choose OddOrg Default to customize the base layout.')
    end
    if selected ~= draft.selected then
        draft.selected=selected; draft.routes=storage_layout.clone(selected == '' and (data.overrides or {}) or storage_layout.routes_for(data,selected) or {})
        draft.name[1]=selected ~= "" and storage_layout.name(selected) or "My layout"
        local bag=draft.routes[draft.category]
        draft.bag=bag == false and -1 or bag or (selected == '' and 0 or -1)
    end
    local base = draft.selected == ''
    local types = {}
    for _, category in ipairs(storage_layout.types) do types[#types+1]={value=category.key,label=category.label} end
    ui_text("Item type",UI_COLORS.text)
    ui_tooltip("Types use game data. General items is a mixed group; check the bulk preview before arranging it.")
    local next_category=layout_choice("##layout_type",draft.category,types,width-1)
    classification_tooltip(next_category)
    if next_category ~= draft.category then
        draft.category=next_category
        local bag=draft.routes[next_category]
        draft.bag=bag == false and -1 or bag or (base and 0 or -1)
    end
    local destinations = {{value=-1,label="Leave where it is"}}
    if base then table.insert(destinations,1,{value=0,label='OddOrg placement (base)'}) end
    local category = storage_layout.by_key[draft.category]
    for _, bag in ipairs(SCANNED_CONTAINERS) do
        if bag ~= 0 and (not GEAR_ONLY_CONTAINERS[bag] or category.gear) then
            destinations[#destinations+1]={value=bag,label=CONTAINERS[bag] .. (bag==2 and " (bulk only)" or "")}
        end
    end
    if GEAR_ONLY_CONTAINERS[draft.bag] and not category.gear then draft.bag=6 end
    ui_text("Store in",UI_COLORS.text)
    draft.bag=layout_choice("##layout_bag",draft.bag,destinations,width-1)
    if base and draft.bag == 0 then
        local route=storage_layout.default_route_for_category(draft.category)
        ui_tooltip(#route > 0 and ("OddOrg Default: "..CONTAINERS[route[1]].."; overflow: "..CONTAINERS[route[2]]
            ..". Full or unavailable homes leave extras in place. Carried supplies and item protections take priority.")
            or "Equipment follows the wardrobe layout. Unclassified and social items stay in place.")
    end
    local staged_bag = draft.routes[draft.category]
    local selected_bag = draft.bag
    local staged_choice = staged_bag == false and -1 or staged_bag or (base and 0 or -1)
    if staged_choice ~= selected_bag and ui_button("Set destination##layout_set",false,busy) then
        if base then
            if draft.bag == 0 then draft.routes[draft.category]=nil
            elseif draft.bag == -1 then draft.routes[draft.category]=false
            else draft.routes[draft.category]=draft.bag end
        else draft.routes[draft.category]=draft.bag ~= -1 and draft.bag or nil end
    end
    ui_tooltip(base and 'Unchanged types keep OddOrg placement. Specific bags permit automatic storage when care is enabled. Item rules and protections still apply.'
        or 'Assigned types are managed automatically. Unassigned types stay put. Ignore rules and item exclusions always win.')
    if not base then
    ui_text("Layout name",UI_COLORS.text)
    if imgui.PushItemWidth then imgui.PushItemWidth(math.max(1,width-1)) end
    imgui.InputText("##layout_name",draft.name,33)
    skin.control_finish(imgui,nil,false,'layout_name')
    if imgui.PopItemWidth then imgui.PopItemWidth() end
    end
    local saved_routes = base and (data.overrides or {}) or storage_layout.routes_for(data,draft.selected) or {}
    local layout_dirty = draft.selected ~= data.active or not same_layout_routes(draft.routes,saved_routes)
        or (not base and draft.name[1] ~= storage_layout.name(draft.selected))
    if layout_dirty then ui_text("Unsaved layout changes",UI_COLORS.attention)
    elseif ui.layout_saved_until and os.clock() < ui.layout_saved_until then ui_text("Layout saved",UI_COLORS.muted) end
    if layout_dirty and ui_button(base and "Apply layout##layout_save" or "Save & use layout##layout_save",true,busy) then
        local desired=storage_layout.clone(data)
        if base then desired.active=''; desired.overrides=storage_layout.clone(draft.routes)
        else
            desired.sets[draft.name[1]]=storage_layout.clone(draft.routes)
            desired.active=draft.name[1]
        end
        if automatic.save_layout(desired) then
            draft.selected=desired.active
            ui.layout_saved_until=os.clock()+3
            ui.notice=nil
        end
        if draft.character==get_player_slug() then ui.layout_draft=draft end
    end
    if data.active ~= "" and ui_button("Use OddOrg Default##layout_defaults",false,busy) then
        local desired=storage_layout.clone(data); desired.active=""
        if automatic.save_layout(desired) then ui.layout_saved_until=os.clock()+3; ui.notice=nil end
        ui.layout_draft=nil
    end
    if next(draft.routes) then
        ui_text("LAYOUT PREVIEW",UI_COLORS.gold)
        ui_tooltip("Apply layout to save these changes. Unchanged types keep OddOrg placement and its normal fallback bags.")
    end
    if base then
        local destinations_only={}
        for key,bag in pairs(draft.routes) do
            if bag == false then ui_wrapped_text(storage_layout.by_key[key].label..': leave where it is',UI_COLORS.text)
            else destinations_only[key]=bag end
        end
        if next(destinations_only) then render_layout_map(destinations_only) end
    else render_layout_map(draft.routes) end
end

local function render_ui()
    if imgui == nil or ui.visible ~= true or imgui.Begin == nil or imgui.End == nil then
        return
    end

    local pushed = push_ui_style()
    local open = { true }
    local home = ui.page ~= "settings"
    local scale = ui_scale()
    if home then push_ui_var("ImGuiStyleVar_WindowPadding", {18,7}, pushed) end
    if imgui.SetNextWindowSize ~= nil then
        -- Owner-approved Oddone dimensions from config/imgui.ini (2026-09-26).
        -- Reset on opening, not every frame; dragging remains available.
        imgui.SetNextWindowSize(home and { 360, 223 } or { 855, 646 },
            global("ImGuiCond_Appearing") or 0)
    end
    if imgui.SetNextWindowSizeConstraints ~= nil then
        imgui.SetNextWindowSizeConstraints(home and { 320.0 * scale, 160.0 * scale }
            or { 760.0 * scale, 420.0 * scale }, { 3.402823466e+38, 3.402823466e+38 })
    end
    local visible = imgui.Begin(home and "OddOrg##oddorg_home_v3" or "OddOrg - Settings##oddorg_settings_v4", open, 0)
    ui.visible = open[1] == true

    if visible == true then
        skin.panel(imgui,'panel',0.14)
        local busy = organizer.running or ephemeral.running or automatic.pending ~= nil
        local width = imgui.GetContentRegionAvail()
        local automation_active = not automatic.paused and ((preferences.background and preferences.background.enabled == true)
            or preferences.sort_enabled == true or preferences.deposit_enabled == true)
        local page_title = home and "OddOrg" or ui.settings_tab == "ignore" and "Item rules"
            or ui.settings_tab == "bulk" and "Bulk Run" or "Automatic care"
        if home then
            local background = preferences.background
            local any_enabled = background and background.enabled == true
                or preferences.sort_enabled == true or preferences.deposit_enabled == true
            local label = automatic.paused and "Automatic care is paused."
                or not any_enabled and "Automatic care is off."
                or "Automatic care is on."
            local context
            if ephemeral.running then context = ephemeral.progress()
            elseif organizer.running then context = ("Organizing: %u actions remaining."):format(math.max(0, #organizer.queue - organizer.cursor + 1))
            elseif automatic.pending then context = automatic.status
            elseif automatic.paused then context = automatic.status or "Resume automatic actions in Settings > Automatic care."
            elseif not any_enabled then context = ""
            elseif not (background and background.enabled) and preferences.sort_enabled ~= true then context = moogle.status
            elseif type(automatic.status) == "string" then context = automatic.status
            else context = "" end
            context = type(context) == "string" and context:gsub("(%.) (%d+ free Inventory slots)","%1\n%2") or ""
            context = context:gsub("(free Inventory slots); (%d+ freed this session)%.","%1\n%2")
            if skin.home_header(imgui,width,
                string.upper(tostring(settings.name or "Unknown")),{
                    label=label,context=context,automation_active=automation_active,
                    color=automatic.paused and UI_COLORS.attention or any_enabled and UI_COLORS.blue_highlight or UI_COLORS.muted,
                    context_color=automatic.paused and UI_COLORS.attention or UI_COLORS.muted,
                },scale,function(size)
                    return ui_button("Settings##oddorg_settings",false,false,false,size)
                end) then ui.page = "settings" end
        else
            local header_x, header_y = imgui.GetCursorPos()
            imgui.SetCursorPos({header_x,math.max(0,header_y-4*scale)})
            skin.banner(imgui,width,page_title,
                string.upper(tostring(settings.name or "Unknown")),scale,automation_active)
            local nav_x, nav_y = imgui.GetCursorPos()
            imgui.SetCursorPos({nav_x,nav_y+8*scale})
            -- A single navigation row leaves the editor the full window width.
            if ui_button("Home##oddorg_home", false, false, false, { 88 * scale, 40 * scale }) then ui.page = "home" end
            same_line()
            local nav_size = { (width - 88 * scale - 36) / 3, 40 * scale }
            if ui_button("Automatic care##settings_auto", ui.settings_tab == "automatic", false, false, nav_size) then ui.settings_tab = "automatic" end
            same_line()
            if ui_button("Item rules##settings_ignore", ui.settings_tab == "ignore", false, false, nav_size) then ui.settings_tab = "ignore" end
            same_line()
            if ui_button("Bulk Run##settings_bulk", ui.settings_tab == "bulk", false, false, nav_size) then ui.settings_tab = "bulk" end
            local content_width, content_height = imgui.GetContentRegionAvail()
            if imgui.BeginChild("oddorg_settings_body", { math.max(1, content_width), math.max(1, content_height) }, true) then
            skin.panel(imgui,'panel',0.13)
            if ui.settings_tab == "automatic" then
            local auto_width = imgui.GetContentRegionAvail()
            imgui.BeginChild("oddorg_automatic_controls", { math.min(420*scale, auto_width*0.48), 0 }, false)
            local background = preferences.background
            local enabled = background and background.enabled == true
            local sort_enabled = preferences.sort_enabled == true
            local deposit_enabled = preferences.deposit_enabled == true
            local any_enabled = enabled or sort_enabled or deposit_enabled
            local character = get_player_slug()
            local draft = ui.automation_draft
            if type(draft) ~= "table" or draft.character ~= character then
                draft = { character=character, owner=tostring(settings.name or "") .. "_" .. tostring(settings.server_id or 0),
                    saved_signature=automation_settings_signature(preferences),
                    enabled={enabled}, free_slots={background and background.free_slots or 5},
                    sort_enabled={sort_enabled}, deposit_enabled={deposit_enabled} }
                ui.automation_draft = draft
            end
            do
            if automatic.paused and automatic.status then ui_wrapped_text(automatic.status, UI_COLORS.attention) end
            if draft.enabled[1] then
                imgui.PushItemWidth(220 * scale)
                imgui.SliderInt("##care_slots", draft.free_slots, 1, 80, "%d slots")
                skin.control_finish(imgui,nil,false,'care_slots')
                ui_tooltip("Empty Inventory slots (1-80). Choose how many slots automatic care should keep free.")
                imgui.PopItemWidth()
                draft.free_slots[1] = math.max(1, math.min(80, draft.free_slots[1]))
            end
            local changed, value = ui_feature_row("Free Inventory slots", "Move spare stacks to storage.", draft.enabled[1], "care_space")
            if changed then draft.enabled[1] = value end
            changed, value = ui_feature_row("Sort incoming items", "Follow your active layout.", draft.sort_enabled[1], "care_sort")
            if changed then draft.sort_enabled[1] = value end
            changed, value = ui_feature_row("Moogle deposits", "Deposit extras as you walk by.", draft.deposit_enabled[1], "care_deposit")
            if changed then draft.deposit_enabled[1] = value end
            end
            local draft_dirty = draft.enabled[1] ~= enabled or draft.free_slots[1] ~= (background and background.free_slots or 5)
                or draft.sort_enabled[1] ~= sort_enabled or draft.deposit_enabled[1] ~= deposit_enabled
            if draft_dirty then
                ui_text("Unsaved changes",UI_COLORS.attention)
            elseif ui.automatic_saved_until and os.clock() < ui.automatic_saved_until then
                ui_text("Saved for this character",UI_COLORS.muted)
            end
            if draft_dirty and ui_button("Apply automatic settings##care_apply", true, false, false, { 250 * scale, 38 * scale }) then
                if draft.character == get_player_slug() then
                    if automatic.apply_setup({ enabled=draft.enabled[1], free_slots=draft.free_slots[1],
                        sort_enabled=draft.sort_enabled[1], deposit_enabled=draft.deposit_enabled[1] }) then
                        ui.automatic_saved_until = os.clock() + 3
                        ui.notice = nil
                    end
                end
            end
            if any_enabled or automatic.paused then
                if draft_dirty and math.min(420*scale,auto_width*0.48) >= 374*scale then same_line() end
                if ui_button(automatic.paused and "Resume##auto_pause" or "Pause all##auto_pause", false, false, false, { 112 * scale, 38 * scale }) then
                    if automatic.paused then
                        automatic.paused, automatic.next_check = false, os.time() + 2
                        automatic.status = "Automatic actions resumed."
                    else automatic.pause("Automatic actions paused.") end
                end
            end
            if ui.notice then imgui.TextWrapped(ui.notice) end
            imgui.EndChild()
            same_line()
            if imgui.BeginChild("oddorg_storage_layout_editor", { 0, 0 }, false) then render_layout_editor(busy) end
            imgui.EndChild()
            elseif ui.settings_tab == "ignore" then
                render_protections(true)
            else
            local bulk_width = imgui.GetContentRegionAvail()
            imgui.BeginChild("oddorg_bulk_controls", { math.min(350*scale, bulk_width*0.40), 0 }, false)
            local crystals_selected = ui.scope == "crystals"
            local data = preferences.storage_layout or {version=1,active="",sets={}}
            local choices = storage_layout.validate(data) and quickset_choices(data) or {}
            if #choices > 1 then
                ui_text("Storage Layout:",UI_COLORS.gold)
                ui.bulk_quickset = layout_choice("##bulk_quickset",ui.bulk_quickset or data.active,
                    choices,math.max(1,imgui.GetContentRegionAvail()-1))
                local preset = storage_layout.preset(ui.bulk_quickset)
                ui_tooltip("Active layout: " .. (data.active == '' and 'OddOrg Default' or storage_layout.name(data.active))
                    .. (preset and ("\n"..preset.description) or ""))
                if ui_button("Use layout##bulk_use",false,busy or ui.bulk_quickset==data.active) then
                    local desired=storage_layout.clone(data); desired.active=ui.bulk_quickset
                    automatic.save_layout(desired)
                    ui.bulk_preview_ready, ui.bulk_preview_displayed = nil, nil
                    ui.bulk_notice = ui.notice
                end

            end
            ui_text("Organize what...", UI_COLORS.gold)
            ui_tooltip(crystals_selected and "Choose crystal source, then deposit surplus. Deposits use only crystals and clusters you have not ignored."
                or "Choose bags, preview the plan, then run. Uses accessible bags and leaves equipped items alone. Storage requires the appropriate Mog House.")
            local previous_scope = ui.scope
            local scope_width = math.max(1, (imgui.GetContentRegionAvail() - 12) / 2)
            local scope_size = { scope_width, 32 * scale }
            if ui_button("All bags##oddorg_scope_all", ui.scope == "all", busy, true, scope_size) then
                ui.scope = "all"
            end
            same_line()
            if ui_button("Wardrobes##oddorg_scope_wardrobes", ui.scope == "wardrobes", busy, true, scope_size) then
                ui.scope = "wardrobes"
            end
            if ui_button("Storage bags##oddorg_scope_storage", ui.scope == "storage", busy, true, scope_size) then
                ui.scope = "storage"
            end
            same_line()
            if ui_button("Crystals##oddorg_mode_crystals", crystals_selected, busy, true, scope_size) then
                ui.scope = "crystals"
                crystals_selected = true
            end

            if ui.scope ~= previous_scope then
                ui.bulk_result = nil
                ui.bulk_preview_ready, ui.bulk_preview_displayed = nil, nil
                ui.preview_plan, ui.preview_visible = nil, false
            end
            crystals_selected = ui.scope == "crystals"
            if crystals_selected then
                ui_text("Collect crystals from", UI_COLORS.gold)
                for index, scope in ipairs({ "all", "inventory", "storage" }) do
                    if index > 1 then same_line() end
                    local label = scope == "all" and "All bags" or scope == "inventory" and "Inventory" or "Storage bags"
                    if ui_button(label .. "##crystal_scope", ui.crystal_scope == scope, busy, true) then
                        ui.crystal_scope = scope
                    end
                end
                ui_text("Deposit the extras", UI_COLORS.gold)
                if ui_button("Deposit surplus##oddorg_crystals_dump", true, busy) then
                    handle_ephemeral({ "/oddorg", "ephemeral", "dump", ui.crystal_scope })
                end
                if ephemeral.running then
                same_line()
                if ui_button("Stop##oddorg_crystals_stop", false, not ephemeral.running) then
                    handle_ephemeral({ "/oddorg", "ephemeral", "stop" })
                end
                same_line()
                if ui_button("Status##oddorg_crystals_status", false, false) then
                    handle_ephemeral({ "/oddorg", "ephemeral", "status" })
                end
                end
            else
                if ui_button("View Plan##oddorg_preview", false, busy, false,
                    { scope_width * 2 + 12, imgui.GetFrameHeight() * 2 }) then
                    ui.preview_plan = nil
                    ui.bulk_result = nil
                    ui.bulk_preview_ready, ui.bulk_preview_displayed = nil, nil
                    handle_organize({ "/oddorg", "organize", "preview", ui.scope })
                    ui.bulk_preview_ready = ui.preview_plan
                    ui.preview_visible = false
                end
                ui_tooltip("Build a plan from current bags. Review destinations and individual moves before running.")
                if not organizer.running and ui.preview_plan and ui.preview_plan.scope == ui.scope
                    and ui.bulk_preview_ready == ui.preview_plan and ui.bulk_preview_displayed == ui.preview_plan then
                if ui_button("Run organization##oddorg_run", true, busy) then
                    ui.bulk_preview_ready, ui.bulk_preview_displayed = nil, nil
                    handle_organize({ "/oddorg", "organize", "run", ui.scope })
                end
                local run_help = "Build a fresh plan from current bags and run it. The preview is an estimate, not a saved move queue. Equipped and protected items stay untouched. Storage requires the appropriate Mog House."
                local access = preferences.safe2_access
                if ui.scope ~= "wardrobes" and (type(access) ~= "table" or access.character ~= get_player_slug() or access.unlocked ~= true) then
                    run_help = run_help .. "\nSafe2 is locked or not yet confirmed; organization uses the other bags."
                end
                ui_tooltip(run_help)
                end
                if organizer.running then
                if ui_button("Stop##oddorg_stop", false, not organizer.running) then
                    handle_organize({ "/oddorg", "organize", "stop" })
                end
                same_line()
                if ui_button("Status##oddorg_status", false, false) then
                    handle_organize({ "/oddorg", "organize", "status" })
                end
                end
            end

            local state = ephemeral.running and ephemeral or organizer.running and organizer or nil
            if state then
                if ephemeral.running then ui_wrapped_text(ephemeral.progress(),UI_COLORS.muted)
                else ui_wrapped_text(("Pass %u: %u actions remaining (%u transfers completed)"):format(
                    organizer.pass or 1, math.max(0, #state.queue - state.cursor + 1),
                    (organizer.completed_transfers or 0) + math.max(0,state.cursor-1)), UI_COLORS.text) end
            else
                local selected_error
                if crystals_selected then selected_error = ephemeral.error else selected_error = organizer.error end
                if selected_error then imgui.TextWrapped(selected_error) end
            end
            render_micro_progress()
            if ui.bulk_result and not organizer.running and not crystals_selected then
                ui_wrapped_text(ui.bulk_result,UI_COLORS.text)
                if ui_button("Dismiss result##bulk_result",false,false) then ui.bulk_result=nil end
            end
            if ui.bulk_notice then
                ui_wrapped_text(ui.bulk_notice,UI_COLORS.muted)
                if ui_button("Dismiss##bulk_notice",false,false) then ui.bulk_notice=nil end
            end
            imgui.EndChild()
            if ui.preview_plan and ui.preview_plan.scope == ui.scope and not crystals_selected then
                same_line()
                if imgui.BeginChild("oddorg_bulk_layout_preview", { 0, 0 }, false) then
                    ui_text("ORGANIZER PREVIEW",UI_COLORS.gold)
                    ui_tooltip("After this plan - includes items left untouched. Run rebuilds the plan from current bags.")
                    if #ui.preview_plan.logical_moves == 0 then
                        ui_text((ui.preview_plan.default_blocked or 0) > 0
                            and "Default homes are full or unavailable; items stay in place."
                            or "Already organized - no moves needed.",UI_COLORS.text)
                    end
                    if ui_button((ui.preview_visible and "Show bag summary" or "Show individual moves").."##bulk_details",false,false) then
                        ui.preview_visible=not ui.preview_visible
                    end
                    if ui_button("Dismiss preview##bulk_dismiss",false,organizer.running) then
                        ui.preview_plan=nil
                        ui.bulk_preview_ready, ui.bulk_preview_displayed = nil, nil
                        ui.preview_visible=false
                    end
                    if ui.preview_plan then
                        if ui.preview_visible then render_preview()
                        else render_layout_map(nil,ui.preview_plan) end
                        if ui.bulk_preview_ready == ui.preview_plan then
                            ui.bulk_preview_displayed = ui.preview_plan
                        end
                    end
                end
                imgui.EndChild()
            end
            end
            end
            imgui.EndChild()
        end
    end

    imgui.End()
    pop_ui_style(pushed)
end

ashita.events.register("command", "oddorg_command", function(e)
    local args = e.command:args()
    if #args == 0 or string.lower(args[1] or "") ~= "/oddorg" then
        return
    end

    e.blocked = true

    if #args == 1 then
        ui.visible = true
        ui.page = "home"
        return
    end

    if args[2] == "settings" then
        ui.visible, ui.page = true, "settings"
        return
    end

    if args[2] == "move" then
        handle_move(args)
        return
    end

    if args[2] == "keep" then
        handle_keep(args)
        return
    end

    if args[2] == "auto" then automatic.command(args); return end
    if args[2] == "sort" or args[2] == "house" or args[2] == "deposit" then
        local key = args[2] == "deposit" and "deposit_enabled" or "sort_enabled"
        if args[3] == "on" or args[3] == "off" then
            automatic.set_feature(key, args[3] == "on"); say(ui.notice or "Automation updated.")
        end
        say((key == "sort_enabled" and "Incoming sorting: " or "Nearby deposits: ") .. tostring(preferences[key] == true))
        return
    end

    if args[2] == "organize" then
        handle_organize(args)
        return
    end

    if args[2] == "probes" then
        handle_probes(args)
        return
    end

    if args[2] == "ephemeral" then
        handle_ephemeral(args)
        return
    end

    if args[2] == "status" then
        handle_status()
        return
    end

    print_help()
end)

ashita.events.register("d3d_present", "oddorg_organizer_tick", function()
    moogle.tick()
    automatic.tick()
    run_organizer_tick()
    run_ephemeral_tick()
    render_ui()
end)

ashita.events.register("packet_out", "oddorg_manual_item_move", automatic.observe_retrieval)
ashita.events.register("packet_in", "oddorg_zone_change", function(e)
    observe_storage_access(e)
    automatic.observe_house_access(e)
    automatic.observe_moogle_menu(e)
    if e.injected == false and e.blocked ~= true and e.id == 0x01D
        and type(e.data) == "string" and #e.data >= 12 then
        local flags = 0
        for index=12,9,-1 do flags = flags * 256 + e.data:byte(index) end
        local detail = ("native_state=%u native_flags=0x%X"):format(e.data:byte(5), flags)
        if completion_note ~= detail then
            completion_note = detail
            write_probe("inventory_completion", "OBSERVED", "native inventory update", detail)
        end
    end
    if e.injected == false and e.blocked ~= true and (e.id == 0x00A or e.id == 0x00B) then
        automatic.manual_acquisition, automatic.moogle_menu = nil, nil
        local organizer_error = organizer.running and "Organization stopped when you changed zones." or organizer.error
        local ephemeral_error = ephemeral.running and "Crystal deposit stopped when you changed zones." or ephemeral.error
        cancel_queues(nil)
        -- Queue errors describe interrupted work. Loading is transient status,
        -- updated by the automatic runner, not a permanent error on idle queues.
        organizer.error, ephemeral.error = organizer_error, ephemeral_error
        automatic.status = "Waiting for the arriving character and loaded bags."
        automatic.ready_character, automatic.ready_zone = nil, nil
        automatic.next_check = os.time() + 6
        moogle.pass = nil
        readiness_note, completion_note = nil, nil
    end
end)

ashita.events.register("load", "oddorg_load", function()
    write_audit("load", "OK", "loaded", get_player_slug())
    write_probe("probe_state", "OK", "loaded", "probes=" .. tostring(PROBES_ENABLED))
    say("loaded. Use /oddorg to open the organizer.")
end)

ashita.events.register("unload", "oddorg_release_ui", function()
    skin.release()
end)
