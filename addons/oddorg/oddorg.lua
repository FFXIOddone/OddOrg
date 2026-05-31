addon.name = "oddorg"
addon.author = "Odd"
addon.version = "0.2.0"
addon.desc = "Guarded in-addon storage organization mover."

require("common")
local bit = require("bit")
local chat = require("chat")

local MOVE_PACKET_ID = 0x029
local DESTINATION_AUTO_INDEX = 0x52
local INVENTORY_CONTAINER_ID = 0
local PROBES_ENABLED = true
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

local STORAGE_BUCKETS = {
    { container_id = 0, label = "Inventory", description = "active carry: medicines, food, tools, and use-now rewards", categories = { "active" } },
    { container_id = 4, label = "Locker", description = "keys, testimonies, missives, chips, and pop/access items", categories = { "access" } },
    { container_id = 7, label = "Case", description = "currencies, seals, pouches, scrolls, abjurations, tatters, and upgrade tokens", categories = { "progression", "scroll" } },
    { container_id = 5, label = "Satchel", description = "craft materials A: wood, metal, gems, ore, beads, and alchemy base materials", categories = { "craft_a" } },
    { container_id = 6, label = "Sack", description = "craft materials B: cloth, leather, bone, beast drops, garden, and food ingredients", categories = { "craft_b" } },
    { container_id = 1, label = "Safe", description = "rare/ex, furnishings, oddities, and long-term overflow", categories = { "rare_misc", "furnishing", "other" } },
}

local organizer = {
    running = false,
    queue = {},
    cursor = 1,
    last_send = 0,
    delay = 0.8,
    inventory_wait_timeout = 5.0,
    scope = "all",
    started_at = 0,
    error = nil,
    summary = nil,
    awaiting_inventory = nil,
}

local bag_access_pointer = nil
local resource_name_matches

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

local function container_is_unlocked(inv, container_id, raw_capacity, account_flags, flags_err)
    raw_capacity = raw_capacity
    if raw_capacity == nil then
        raw_capacity = get_container_capacity(inv, container_id)
    end
    raw_capacity = tonumber(raw_capacity) or 0

    if raw_capacity <= 0 then
        return false, 0, "capacity unavailable"
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
    local account_flags, flags_err = read_account_storage_flags()
    local access_by_container = {}
    local details = {}
    local unlocked_count = 0
    local locked_count = 0
    local unavailable_count = 0

    for _, container_id in ipairs(SCANNED_CONTAINERS) do
        local raw_capacity = get_container_capacity(inv, container_id)
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

local function name_has_any(name, terms)
    for _, term in ipairs(terms) do
        if name:find(term, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function non_equipment_category(item_name)
    local name = string.lower(tostring(item_name or ""))
    local compact = name:gsub("%.", ""):gsub("'", "")

    if name_has_any(name, {
        "holy water", "echo drops", "eye drops", "antidote", "remedy", "instant warp",
        "instant reraise", "silent oil", "prism powder", "special brew", "goblin brew",
        "gysahl greens", "chronicles", "theory", "miratete", "mint drop", "food", "feast",
        "sushi", "taco", "risotto", "pie", "parfait", "rusk", "biscuit", "dumpling",
        "indulgence", "blank", "blnk", "shihei", "sandwich", "hatchet", "pickaxe",
    }) then
        return "active"
    end

    if name_has_any(name, {
        "testimony", "coffer key", "chest key", "missive", "codex", "chip", "lantern",
        "odious", "tanscale key", "dangruf stone", "dream coffer", "radiant chip",
    }) or name:match(" key$") ~= nil or name:find(" key", 1, true) ~= nil then
        return "access"
    end

    if name_has_any(name, { " spirit", "scroll", "scroll of" }) then
        return "scroll"
    end

    if name_has_any(name, {
        "seal", "crest", "voucher", "pouch", "purse", "parcel", "case", "tatter",
        "abjuration", "forgotten", "frgtn", "void", "storage slip", "alexandrite",
        "bronzepiece", "beitetsu", "pluton", "rift", "commendation", "slime spirit",
        "beastcoin", "relic iron", " mitts -1", " -1",
    }) then
        return "progression"
    end

    if name_has_any(name, {
        "lumber", "lbr", " log", "ore", "ingot", "sheet", "nugget", "rivet", "stud",
        "steel", "bronze", "brass", "copper", "silver", "mythril", "gold", "darksteel",
        "cobalt", "orichalc", "adaman", "bead", "ametrine", "garnet", "zircon", "topaz",
        "sapphire", "diamond", "ruby", "emerald", "crystal", "cluster",
    }) then
        return "craft_a"
    end

    if name_has_any(name, {
        "cloth", "thread", "yarn", "silk", "cotton", "wool", "velvet", "leather",
        "skin", "hide", "pelt", "fur", "doeskin", "bone", "shell", "scale", "claw",
        "fang", "jaw", "wing", "feather", "hair", "meat", "root", "herb", "flower",
        "seed", "acorn", "almond", "fruit", "fish", "ink", "wax", "honey", "blood",
        "chip", "calculus", "fiber", "acid", "horn", "tusk", "stinger", "talon",
        "heart", "egg", "sugar", "nut", "garlic", "sap", "twine", "lanolin", "salt",
        "persikos", "walnut", "foliage", "shadeleaf", "nebimonite", "beard",
    }) then
        return "craft_b"
    end

    if name_has_any(name, { "dream platter", "dream stocking", "red jar", "wood kit", "kit " })
        or compact:match("^wood kit") ~= nil then
        return "furnishing"
    end

    return "rare_misc"
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

    local capacity = get_container_capacity(inv, move.target_container_id)
    for index = 1, capacity, 1 do
        local item = get_container_item(inv, move.target_container_id, index)
        if is_real_item(item) and tonumber(item.Id) == move.item_id then
            local count = tonumber(item.Count) or 0
            if count + move.quantity <= stack_size then
                return true
            end
        end
    end

    return false
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

local function validate_move(move)
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
    if move.source_container_id == 0 and bit.band(tonumber(item.Flags) or 0, 1) ~= 0 then
        return false, "source inventory item is locked", tostring(move.source_index)
    end

    local resource = resources:GetItemById(item.Id)
    if not resource_name_matches(resource, move.item_name) then
        return false, "source item name mismatch", move.item_name
    end
    if GEAR_ONLY_CONTAINERS[move.target_container_id] and not is_equipment(resource) then
        return false, "target wardrobe is gear-only", move.item_name
    end

    local used, capacity = count_used_slots(inv, move.target_container_id)
    if used >= capacity and not can_stack_into_target(inv, resource, move) then
        return false, "target container is full", ("%s %u/%u"):format(CONTAINERS[move.target_container_id], used, capacity)
    end

    return true, "validated", ("%s[%u] -> %s"):format(CONTAINERS[move.source_container_id], move.source_index, CONTAINERS[move.target_container_id])
end

local function send_move_packet(move)
    local packet = struct.pack('IIBBBB', 0, move.quantity, move.source_container_id, move.target_container_id, move.source_index, DESTINATION_AUTO_INDEX):totable()
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

    send_move_packet(move)
    write_audit(move.move_id, "SENT", message, details)
    say(("sent %s: %s x%u to %s"):format(move.move_id, move.item_name, move.quantity, CONTAINERS[move.target_container_id]))
end

local function collect_equipped_keys()
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

    write_probe("equipped_scan_done", "OK", "equipped items scanned", "count=" .. tostring(count))
    return equipped
end

local function collect_live_items()
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

    local container_access = collect_container_access(inv)
    for _, container_id in ipairs(SCANNED_CONTAINERS) do
        local access = container_access[container_id] or {
            unlocked = false,
            capacity = 0,
            raw_capacity = 0,
            reason = "access missing",
        }
        capacities[container_id] = access.capacity
        counts[container_id] = 0
        if access.unlocked and access.capacity > 0 then
            for index = 1, access.capacity, 1 do
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
                        item_name = name,
                        stack_size = stack_size_for(resource),
                        equippable = is_equipment(resource),
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

    write_probe(
        "snapshot_done",
        "OK",
        "live items collected",
        ("items=%u equipment=%u non_equipment=%u containers=%u"):format(#items, equipment_count, non_equipment_count, table_len(capacities))
    )
    write_probe("snapshot_counts", "OK", "current container counts", counts_to_details(counts, capacities))
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

local function add_assignment(plan, item, target_container_id, bucket, category, reason)
    local key = item_key(item.container_id, item.index)
    plan.assignments[key] = {
        item = item,
        target_container_id = target_container_id,
        bucket = bucket,
        category = category,
        reason = reason,
    }
    plan.target_counts[target_container_id] = (plan.target_counts[target_container_id] or 0) + 1
end

local function reserve_pinned(plan, item, reason)
    add_assignment(plan, item, item.container_id, {
        label = CONTAINERS[item.container_id] or tostring(item.container_id),
        description = reason,
    }, "pinned", reason)
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
            local item = leftovers[1]
            table.remove(leftovers, 1)
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
    local grouped = group_items_by_category(movable_items, function(item)
        return non_equipment_category(item.item_name)
    end)

    for _, bucket in ipairs(STORAGE_BUCKETS) do
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
                    "non-equipment standard: " .. bucket.description .. "; category=" .. category
                )
            end
        end
    end

    local leftovers = collect_leftovers(grouped, function(item) return non_equipment_category(item.item_name) end)
    local overflow_order = { 1, 7, 5, 6, 0, 4 }
    local buckets_by_container = {}
    for _, bucket in ipairs(STORAGE_BUCKETS) do
        buckets_by_container[bucket.container_id] = bucket
    end

    for _, container_id in ipairs(overflow_order) do
        local bucket = buckets_by_container[container_id]
        local capacity = capacities[container_id] or 0
        while bucket ~= nil and (plan.target_counts[container_id] or 0) < capacity and #leftovers > 0 do
            local item = leftovers[1]
            table.remove(leftovers, 1)
            local category = non_equipment_category(item.item_name)
            add_assignment(
                plan,
                item,
                container_id,
                bucket,
                category,
                "non-equipment overflow standard: " .. bucket.description .. "; category=" .. category
            )
        end
    end

    if #leftovers > 0 then
        return false, "not enough non-wardrobe capacity for " .. tostring(#leftovers) .. " non-equipment items"
    end
    return true, nil
end

local function build_organize_plan(snapshot, options)
    local equipped_keys = options.allow_equipped and {} or collect_equipped_keys()
    local plan = {
        assignments = {},
        target_counts = {},
        logical_moves = {},
        pinned_social = 0,
        pinned_equipped = 0,
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
        local key = item_key(item.container_id, item.index)
        if equipped_keys[key] then
            plan.pinned_equipped = plan.pinned_equipped + 1
            reserve_pinned(plan, item, "equipped item pinned")
            write_probe("pin_equipped", "OK", item.item_name, key)
        elseif is_social_item(item) and not options.include_social then
            plan.pinned_social = plan.pinned_social + 1
            reserve_pinned(plan, item, "social shell item pinned")
            write_probe("pin_social", "OK", item.item_name, key)
        elseif item.equippable then
            table.insert(equipment_items, item)
        else
            table.insert(storage_items, item)
        end
    end

    local ok, err = build_wardrobe_plan(plan, equipment_items, snapshot.capacities)
    if not ok then
        write_probe("capacity_preflight", "REJECT", err, "wardrobes")
        return nil, err
    end

    ok, err = build_storage_plan(plan, storage_items, snapshot.capacities)
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
                    quantity = item.quantity,
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
        if capacity > 0 and count > capacity then
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
    -- STACKING_IS_LIVE_VALIDATION_ONLY: planner treats stack deposits as slot-consuming.
    -- The live validator may still allow a full-target stack, but queue simulation stays conservative.
    local capacity = capacities[move.target_container_id] or 0
    if capacity <= 0 then
        return false, nil
    end
    return (counts[move.target_container_id] or 0) < capacity, nil
end

local function remove_state_item(item, counts, inventory_slots, items_by_slot)
    items_by_slot[item_key(item.container_id, item.index)] = nil
    counts[item.container_id] = math.max(0, (counts[item.container_id] or 0) - 1)
    if item.container_id == INVENTORY_CONTAINER_ID then
        inventory_slots[item.index] = nil
    end
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
        if move.source_container_id ~= move.target_container_id then
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
                    remove_state_item(source_item, counts, inventory_slots, items_by_slot)
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
                                remove_state_item(source_item, counts, inventory_slots, items_by_slot)
                                append_physical(physical, move, "pull", move.source_container_id, move.source_index, INVENTORY_CONTAINER_ID)
                                place_state_item(source_item, INVENTORY_CONTAINER_ID, inventory_index, counts, inventory_slots, items_by_slot, nil)
                                remove_pending(pending, move)
                                progressed = true
                                break
                            end
                        else
                            local accepts, stack_key = target_accepts(move, counts, snapshot.capacities, items_by_slot, blocked)
                            if accepts and inventory_index ~= nil then
                                remove_state_item(source_item, counts, inventory_slots, items_by_slot)
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
                            remove_state_item(source_item, counts, inventory_slots, items_by_slot)
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
        action = args[3] or "status",
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

local function build_preview_or_queue(options)
    local snapshot, _, err = collect_live_items()
    if snapshot == nil then
        return nil, nil, err
    end

    local plan, plan_err = build_organize_plan(snapshot, options)
    if plan == nil then
        return nil, nil, plan_err
    end

    local queue, queue_err = build_physical_queue(plan.logical_moves, snapshot)
    if queue == nil then
        write_probe("plan_done", "REJECT", queue_err, "logical_moves=" .. tostring(#plan.logical_moves))
        return nil, nil, queue_err
    end

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

local function logical_move_id(move)
    local move_id = tostring(move and move.move_id or "")
    move_id = move_id:gsub("%-pull$", "")
    move_id = move_id:gsub("%-put$", "")
    return move_id
end

local function pull_matches_put(pull_move, put_move)
    return pull_move ~= nil
        and put_move ~= nil
        and pull_move.target_container_id == INVENTORY_CONTAINER_ID
        and pull_move.source_container_id ~= INVENTORY_CONTAINER_ID
        and put_move.source_container_id == INVENTORY_CONTAINER_ID
        and put_move.source_index == 0
        and pull_move.item_id == put_move.item_id
        and pull_move.quantity == put_move.quantity
        and string.lower(pull_move.item_name or "") == string.lower(put_move.item_name or "")
        and logical_move_id(pull_move) == logical_move_id(put_move)
end

local function find_inventory_item_for_move(move)
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    local resources = AshitaCore:GetResourceManager()
    if inv == nil or resources == nil then
        return false, nil
    end

    local probe_move = copy_move(move)
    probe_move.source_container_id = INVENTORY_CONTAINER_ID
    probe_move.source_index = 0
    local resolved = resolve_inventory_source(inv, resources, probe_move)
    if resolved then
        return true, probe_move.source_index
    end
    return false, nil
end

local function maybe_start_inventory_wait(sent_move)
    local next_move = organizer.queue[organizer.cursor + 1]
    if not pull_matches_put(sent_move, next_move) then
        organizer.awaiting_inventory = nil
        return
    end

    organizer.awaiting_inventory = {
        pull_move_id = sent_move.move_id,
        put_move_id = next_move.move_id,
        item_id = sent_move.item_id,
        quantity = sent_move.quantity,
        item_name = sent_move.item_name,
        started_at = os.clock(),
        last_probe = 0,
    }
    write_probe(
        "queue_wait_inventory",
        "OK",
        "waiting for pulled item to appear in Inventory",
        ("%s -> %s %s x%u"):format(sent_move.move_id, next_move.move_id, sent_move.item_name, sent_move.quantity)
    )
end

local function wait_for_inventory_stage(now)
    if organizer.awaiting_inventory == nil then
        return true
    end

    local move = organizer.queue[organizer.cursor]
    local waiting = organizer.awaiting_inventory
    if move == nil or move.move_id ~= waiting.put_move_id then
        write_probe("queue_wait_inventory", "REJECT", "wait state did not match cursor", tostring(waiting.put_move_id))
        organizer.awaiting_inventory = nil
        return true
    end

    local visible, index = find_inventory_item_for_move(move)
    if visible then
        write_probe(
            "inventory_stage_visible",
            "OK",
            "pulled item is visible in Inventory",
            ("%s inventory_index=%u"):format(move.move_id, tonumber(index) or 0)
        )
        organizer.awaiting_inventory = nil
        return true
    end

    local elapsed = now - waiting.started_at
    if elapsed >= organizer.inventory_wait_timeout then
        organizer.running = false
        organizer.error = "inventory stage timeout"
        local details = ("%s x%u after %.2fs pull=%s"):format(waiting.item_name, waiting.quantity, elapsed, waiting.pull_move_id)
        write_audit(waiting.put_move_id, "REJECT", "inventory stage timeout", details)
        write_probe("inventory_stage_timeout", "REJECT", "pulled item did not appear in Inventory", details)
        say("organizer stopped waiting for Inventory stage: " .. waiting.item_name)
        return false
    end

    if waiting.last_probe == 0 or (now - waiting.last_probe) >= 1.0 then
        waiting.last_probe = now
        write_probe(
            "queue_wait_inventory",
            "WAIT",
            "pulled item not visible yet",
            ("%s x%u elapsed=%.2f"):format(waiting.item_name, waiting.quantity, elapsed)
        )
    end
    return false
end

local function handle_organize(args)
    if args[3] == "preview" or args[3] == "run" or args[3] == "stop" or args[3] == "status" then
        -- Explicit command verbs are kept visible for static safety tests and operator trust.
    end
    local options = parse_organize_options(args)

    if options.action == "stop" then
        organizer.running = false
        organizer.error = nil
        organizer.awaiting_inventory = nil
        write_probe("queue_stop", "OK", "stopped by command", "cursor=" .. tostring(organizer.cursor))
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

    local plan, queue, err = build_preview_or_queue(options)
    if plan == nil then
        write_probe("plan_done", "REJECT", err, options.scope)
        print(chat.header("OddOrg") .. chat.error(err or "plan failed"))
        return
    end

    if options.action == "preview" then
        say(("preview built: logical=%u physical=%u plan=%s"):format(#plan.logical_moves, #queue, plan_path()))
        return
    end

    organizer.running = true
    organizer.queue = queue
    organizer.cursor = 1
    organizer.scope = options.scope
    organizer.started_at = os.clock()
    organizer.last_send = 0
    organizer.error = nil
    organizer.awaiting_inventory = nil
    organizer.summary = {
        logical = #plan.logical_moves,
        physical = #queue,
    }
    write_probe("queue_start", "OK", "organization queue started", ("scope=%s physical=%u"):format(options.scope, #queue))
    say(("organizer started: logical=%u physical=%u delay=%.2fs"):format(#plan.logical_moves, #queue, organizer.delay))
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

local function run_organizer_tick()
    if not organizer.running then
        return
    end

    if organizer.cursor > #organizer.queue then
        organizer.running = false
        organizer.awaiting_inventory = nil
        write_probe("queue_done", "OK", "organization queue complete", ("sent=%u"):format(#organizer.queue))
        say("organizer complete.")
        return
    end

    local now = os.clock()
    if organizer.last_send ~= 0 and (now - organizer.last_send) < organizer.delay then
        return
    end

    if not wait_for_inventory_stage(now) then
        return
    end

    local move = organizer.queue[organizer.cursor]
    local ok, message, details = validate_move(move)
    if not ok then
        organizer.running = false
        organizer.error = message
        organizer.awaiting_inventory = nil
        fail_move(move.move_id, message, details)
        say("organizer stopped on validation reject at " .. tostring(organizer.cursor) .. ".")
        return
    end

    send_move_packet(move)
    write_audit(move.move_id, "SENT", message, details)
    write_probe(
        "queue_step",
        "SENT",
        move.move_id,
        ("%u/%u %s"):format(organizer.cursor, #organizer.queue, move_to_command_label(move))
    )
    maybe_start_inventory_wait(move)
    organizer.cursor = organizer.cursor + 1
    organizer.last_send = now
end

local function print_help()
    say("Commands: /oddorg status | /oddorg move <move_id> <character_slug> <item_id> <quantity> <src_container_id> <src_index> <dst_container_id> \"<name>\" | /oddorg organize preview|run|stop|status [all|wardrobes|storage] [equipped] [social] | /oddorg probes on|off|clear|status")
end

local function handle_status()
    local slug = get_player_slug()
    write_audit("status", "OK", "loaded", slug)
    write_probe("queue_status", "OK", "addon status", slug)
    say("loaded for " .. slug)
end

ashita.events.register("command", "oddorg_command", function(e)
    local args = e.command:args()
    if #args == 0 or args[1] ~= "/oddorg" then
        return
    end

    e.blocked = true

    if args[2] == "move" then
        handle_move(args)
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

    if args[2] == "status" then
        handle_status()
        return
    end

    print_help()
end)

ashita.events.register("d3d_present", "oddorg_organizer_tick", function()
    run_organizer_tick()
end)

ashita.events.register("load", "oddorg_load", function()
    write_audit("load", "OK", "loaded", get_player_slug())
    write_probe("probe_state", "OK", "loaded", "probes=" .. tostring(PROBES_ENABLED))
    say("loaded. Use /oddorg status.")
end)
