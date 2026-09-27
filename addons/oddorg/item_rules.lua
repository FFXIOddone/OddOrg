-- Shared per-item outcomes and temporary manual-move reservations.
-- This module has no Ashita, UI, filesystem, or transport access.
local item_rules = {}
local keep_rules = require('keep_rules')
local storage_layout = require('storage_layout')

local bags = { [1]=true,[2]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,
    [9]=true,[10]=true,[11]=true,[12]=true,[13]=true,[14]=true,[15]=true,[16]=true }
local wardrobes = { [8]=true,[10]=true,[11]=true,[12]=true,[13]=true,[14]=true,[15]=true,[16]=true }

local function integer(value, minimum, maximum)
    return type(value) == 'number' and value == value and value == math.floor(value)
        and value >= minimum and value <= maximum
end

local function valid_item_id(value)
    local number = tonumber(value)
    return number ~= nil and number >= 1 and number <= 65535 and number == math.floor(number)
        and tostring(number) == value
end

local function valid_location(value)
    return value == 0 or bags[value] == true
end

function item_rules.validate(data)
    if data == nil then return true end
    if type(data) ~= 'table' or data.version ~= 1 or type(data.items) ~= 'table' then
        return false, 'Invalid per-item rules.'
    end
    local count = 0
    for id, rule in pairs(data.items) do
        count = count + 1
        if count > 4096 then return false, 'Per-item rules are limited to 4096 items.' end
        if not valid_item_id(id) or type(rule) ~= 'table'
            or not integer(rule.carry_target, 0, 99999) or type(rule.deposit) ~= 'boolean' then
            return false, 'Invalid per-item outcome for item ' .. tostring(id) .. '.'
        end
        local destination = rule.destination
        if destination ~= 'default' and destination ~= 'stay'
            and not (integer(destination, 1, 16) and bags[destination]) then
            return false, 'Invalid per-item destination for item ' .. tostring(id) .. '.'
        end
        local item_id = tonumber(id)
        if rule.deposit then
            if item_id < 4096 or item_id > 4111 or not integer(destination, 1, 16)
                or not bags[destination] or destination == 2 then
                return false, 'Crystal deposits need a specific, accessible staging bag.'
            end
        end
    end
    return true
end

function item_rules.validate_for_item(rule, item)
    if type(rule) ~= 'table' or type(item) ~= 'table' then
        return false, 'Item outcome is unavailable.'
    end
    local destination = rule.destination
    if integer(destination, 1, 16) then
        if wardrobes[destination] and item.equippable ~= true then
            return false, 'Only equipment can be assigned to a wardrobe.'
        end
    end
    local item_id = tonumber(item.item_id) or 0
    if rule.deposit and (item_id < 4096 or item_id > 4111) then
        return false, 'Only crystals and clusters can be assigned to Moogle deposits.'
    end
    return true
end

function item_rules.for_item(data, item_id)
    local ok, err = item_rules.validate(data)
    if not ok then return nil, err end
    return data and data.items[tostring(tonumber(item_id) or 0)] or nil
end

-- A specific bag overrides a type quickset. "default" keeps the current
-- category/default placement, while "stay" disables extra-item storage.
function item_rules.destination(rule, default_destination)
    if type(rule) ~= 'table' or rule.destination == 'default' then
        return default_destination, 'default'
    end
    if rule.destination == 'stay' then return nil, 'stay' end
    return rule.destination, 'specific'
end

function item_rules.allows_storage(rule, default_allowed)
    if type(rule) ~= 'table' or rule.destination == 'default' then return default_allowed == true end
    return rule.destination ~= 'stay'
end

-- A saved per-item outcome owns deposit permission for that item. In
-- particular, choosing a storage route never inherits legacy donation access.
function item_rules.allows_deposit(rule, default_allowed)
    if type(rule) == 'table' then return rule.deposit == true end
    return default_allowed == true
end

function item_rules.carry_target(rule)
    return type(rule) == 'table' and rule.carry_target or 0
end

local function add_reserved(items, reserved, item_id, location, quantity)
    local remaining = quantity
    for _, item in ipairs(items) do
        if item.item_id == item_id and item.container_id == location and remaining > 0 then
            local key = tostring(item.container_id) .. ':' .. tostring(item.index)
            local already = math.max(0, math.min(item.quantity, tonumber(reserved[key]) or 0))
            local amount = math.min(math.max(0, item.quantity - already), remaining)
            reserved[key] = already + amount
            remaining = remaining - amount
        end
    end
    return quantity - remaining
end

local function valid_overrides(overrides)
    if type(overrides) ~= 'table' then return false end
    for id, locations in pairs(overrides) do
        if not valid_item_id(id) then return false end
        if locations ~= true then
            if type(locations) ~= 'table' then return false end
            for location, quantity in pairs(locations) do
                local number = tonumber(location)
                if number == nil or tostring(number) ~= tostring(location) or not valid_location(number)
                    or not integer(quantity, 1, 99999) then return false end
            end
        end
    end
    return true
end

function item_rules.allocate(items, keep, data, overrides)
    local valid, err = item_rules.validate(data)
    if not valid then return nil, err end
    if overrides ~= nil and not valid_overrides(overrides) then
        return nil, 'Invalid temporary item move reservations.'
    end
    local reserved, reserve_err = keep_rules.allocate(items, keep)
    if not reserved then return nil, reserve_err end

    for id, locations in pairs(overrides or {}) do
        local item_id = tonumber(id)
        if locations == true then
            for _, item in ipairs(items) do
                if item.item_id == item_id then
                    reserved[tostring(item.container_id) .. ':' .. tostring(item.index)] = item.quantity
                end
            end
        else
            for location, quantity in pairs(locations) do
                add_reserved(items, reserved, item_id, tonumber(location), quantity)
            end
        end
    end

    for id, rule in pairs((data and data.items) or {}) do
        local item_id, target = tonumber(id), rule.carry_target
        if target > 0 then
            local already, total = 0, 0
            for _, item in ipairs(items) do
                if item.item_id == item_id and item.container_id == 0 then
                    local key = tostring(item.container_id) .. ':' .. tostring(item.index)
                    already = already + math.min(item.quantity, tonumber(reserved[key]) or 0)
                    total = total + item.quantity
                end
            end
            local remaining = math.max(0, math.min(target, total) - already)
            for _, item in ipairs(items) do
                if item.item_id == item_id and item.container_id == 0 and remaining > 0 then
                    local key = tostring(item.container_id) .. ':' .. tostring(item.index)
                    local protected = math.max(0, math.min(item.quantity, tonumber(reserved[key]) or 0))
                    local amount = math.min(item.quantity - protected, remaining)
                    reserved[key] = protected + amount
                    remaining = remaining - amount
                end
            end
        end
    end
    return reserved
end

-- Stored stock needed to reach a carried target must not be organized away or
-- staged for a deposit. Refill execution may consume only this separate map.
function item_rules.refill_reservations(items, reserved, data)
    local valid, err = item_rules.validate(data)
    if not valid then return nil, err end
    if type(reserved) ~= 'table' then return nil, 'Item reservations are unavailable.' end
    local targets = {}
    for id, rule in pairs((data and data.items) or {}) do
        if rule.carry_target > 0 then targets[#targets + 1] = {id=tonumber(id),rule=rule} end
    end
    table.sort(targets, function(left,right) return left.id < right.id end)

    local result = {}
    for _, entry in ipairs(targets) do
        local carried, shortage = 0, entry.rule.carry_target
        for _, item in ipairs(items) do
            if item.item_id == entry.id and item.container_id == 0 then carried = carried + item.quantity end
        end
        shortage = math.max(0, shortage - carried)
        if shortage > 0 then
            local candidates = {}
            for _, item in ipairs(items) do
                if item.item_id == entry.id and item.container_id ~= 0 and item.container_id ~= 2 and not item.locked then
                    candidates[#candidates + 1] = item
                end
            end
            table.sort(candidates, function(left,right)
                local preferred = entry.rule.destination
                local left_preferred = type(preferred) == 'number' and left.container_id == preferred
                local right_preferred = type(preferred) == 'number' and right.container_id == preferred
                if left_preferred ~= right_preferred then return left_preferred end
                if left.container_id ~= right.container_id then return left.container_id < right.container_id end
                return left.index < right.index
            end)
            for _, item in ipairs(candidates) do
                if shortage == 0 then break end
                local key = tostring(item.container_id) .. ':' .. tostring(item.index)
                local protected = math.max(0, math.min(item.quantity, tonumber(reserved[key]) or 0))
                local available = item.quantity - protected
                local amount = math.min(shortage, available)
                if amount > 0 then result[key] = amount; shortage = shortage - amount end
            end
        end
    end
    return result
end

-- Derived defaults are never written into the player's saved item rules.
-- Count occupied and explicitly promised slots first, then fit one stack per
-- supply type. Existing supplies win ties so repeated snapshots remain stable.
function item_rules.with_default_supplies(snapshot, keep, data, overrides, layout, free_slots)
    local reserved, err = item_rules.allocate(snapshot.items,keep,data,overrides)
    if not reserved then return nil,err end
    if layout and layout.active ~= '' then return data end
    local result = {version=1,items={}}
    for id,rule in pairs((data and data.items) or {}) do result.items[id]=rule end
    local candidates, occupied, carried = {}, 0, {}
    for _,item in ipairs(snapshot.items) do
        local id, key = tostring(item.item_id), tostring(item.container_id)..':'..tostring(item.index)
        local protected = reserved[key] or 0
        local supply = storage_layout.supply_kind(item)
        local eligible = supply and not result.items[id] and (keep[id] == nil or keep[id] == 0)
            and storage_layout.target(layout,item) ~= false
        if item.container_id == 0 then
            carried[id] = (carried[id] or 0) + item.quantity
            if not eligible or protected > 0 or item.locked or item.equipped or item.social then occupied=occupied+1 end
        end
        if eligible and item.container_id ~= 2 and not item.locked and not item.equipped
            and (item.quantity > protected or (item.container_id == 0 and protected > 0)) then
            local entry = candidates[id] or {id=id,stack=item.stack_size or 1,available=0,carried=false,protected=false}
            entry.available=entry.available+item.quantity-(item.container_id == 0 and 0 or protected)
            if item.container_id == 0 then
                entry.carried=true
                if protected > 0 then entry.protected=true end
            end
            candidates[id]=entry
        end
    end
    local explicit_refill = item_rules.refill_reservations(snapshot.items,reserved,data)
    local promised = {}
    for _,item in ipairs(snapshot.items) do
        local amount=explicit_refill[tostring(item.container_id)..':'..tostring(item.index)] or 0
        local id=tostring(item.item_id)
        if amount > 0 then
            promised[id]=promised[id] or {quantity=0,stack=item.stack_size or 1}
            promised[id].quantity=promised[id].quantity+amount
        end
    end
    for id,entry in pairs(promised) do
        local current=carried[id] or 0
        occupied=occupied+math.max(0,math.ceil((current+entry.quantity)/entry.stack)-math.ceil(current/entry.stack))
    end
    local capacity=snapshot.capacities[0] or 0
    local slots=math.max(0,capacity-math.min(capacity,free_slots or 5)-occupied)
    local ordered={}
    for _,entry in pairs(candidates) do ordered[#ordered+1]=entry end
    table.sort(ordered,function(a,b)
        if a.carried ~= b.carried then return a.carried end
        return tonumber(a.id) < tonumber(b.id)
    end)
    for _,entry in ipairs(ordered) do
        if entry.protected or slots > 0 then
            result.items[entry.id]={carry_target=math.min(entry.stack,entry.available),destination='default',deposit=false}
            if not entry.protected then slots=slots-1 end
        end
    end
    return result
end

function item_rules.signature(data)
    local ok = item_rules.validate(data)
    if not ok then return nil end
    if data == nil then return 'legacy' end
    local ids = {}
    for id in pairs(data.items) do ids[#ids + 1] = id end
    table.sort(ids)
    local parts = { 'v1' }
    for _, id in ipairs(ids) do
        local rule = data.items[id]
        parts[#parts + 1] = table.concat({ id, tostring(rule.carry_target), tostring(rule.destination), tostring(rule.deposit) }, ':')
    end
    return table.concat(parts, '|')
end

function item_rules.record_manual_move(overrides, item_id, source, destination, quantity)
    if type(overrides) ~= 'table' or not integer(item_id, 1, 65535)
        or not valid_location(source) or not valid_location(destination)
        or source == destination or not integer(quantity, 1, 99999) then
        return false, 'Invalid confirmed manual item move.'
    end
    local id = tostring(item_id)
    local held = overrides[id]
    if held == true then return true, quantity end
    if held == nil then held = {}; overrides[id] = held end
    local from = tostring(source)
    local moved_hold = math.min(tonumber(held[from]) or 0, quantity)
    if moved_hold > 0 then
        held[from] = held[from] - moved_hold
        if held[from] == 0 then held[from] = nil end
    end
    local to = tostring(destination)
    held[to] = math.min(99999, (tonumber(held[to]) or 0) + quantity)
    return true, quantity
end

function item_rules.record_manual_gain(overrides, item_id, location, quantity)
    if type(overrides) ~= 'table' or not integer(item_id, 1, 65535)
        or not valid_location(location) or not integer(quantity, 1, 99999) then
        return false, 'Invalid confirmed manual item gain.'
    end
    local id, key = tostring(item_id), tostring(location)
    if overrides[id] == true then return true end
    overrides[id] = overrides[id] or {}
    overrides[id][key] = math.min(99999, (tonumber(overrides[id][key]) or 0) + quantity)
    return true
end

function item_rules.consume_override(overrides, item_id, location, quantity)
    if type(overrides) ~= 'table' or not integer(item_id, 1, 65535)
        or not valid_location(location) or not integer(quantity, 1, 99999) then
        return 0
    end
    local id, key = tostring(item_id), tostring(location)
    local held = overrides[id]
    if type(held) ~= 'table' then return 0 end
    local consumed = math.min(tonumber(held[key]) or 0, quantity)
    held[key] = held[key] - consumed
    if held[key] == 0 then held[key] = nil end
    if next(held) == nil then overrides[id] = nil end
    return consumed
end

function item_rules.release_override(overrides, item_id)
    if type(overrides) ~= 'table' or not integer(item_id, 1, 65535) then return false end
    overrides[tostring(item_id)] = nil
    return true
end

function item_rules.location_totals(items)
    if type(items) ~= 'table' then return nil end
    local totals = {}
    for _, item in ipairs(items) do
        if type(item) == 'table' and integer(item.item_id, 1, 65535)
            and valid_location(item.container_id) and integer(item.quantity, 0, 99999) then
            local key = tostring(item.item_id) .. ':' .. tostring(item.container_id)
            totals[key] = (totals[key] or 0) + item.quantity
        end
    end
    return totals
end

function item_rules.reconcile_overrides(overrides, items, previous_totals)
    if type(overrides) ~= 'table' or type(items) ~= 'table' then return false end
    local current_totals = item_rules.location_totals(items)
    previous_totals = type(previous_totals) == 'table' and previous_totals or {}
    for id, locations in pairs(overrides) do
        if locations ~= true then
            for location, quantity in pairs(locations) do
                local key = id .. ':' .. location
                local available = current_totals[key] or 0
                local consumed = math.max(0, (tonumber(previous_totals[key]) or available) - available)
                local keep = math.min(math.max(0, quantity - consumed), available)
                if keep == 0 then locations[location] = nil else locations[location] = keep end
            end
            if next(locations) == nil then overrides[id] = nil end
        end
    end
    return true, current_totals
end

return item_rules
