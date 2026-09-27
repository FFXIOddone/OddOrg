-- Shared item reservations. This module has no game, filesystem, or UI access.
local rules = {}

local function key(item)
    return tostring(item.container_id) .. ":" .. tostring(item.index)
end

function rules.validate(keep)
    if type(keep) ~= "table" then return false, "item protections are not a table" end
    for id, quantity in pairs(keep) do
        local number = tonumber(id)
        if not number or number < 1 or number > 65535 or number ~= math.floor(number)
            or tostring(number) ~= id then
            return false, "invalid protected item ID"
        end
        if quantity ~= "all" and (type(quantity) ~= "number" or quantity ~= quantity
            or quantity < 0 or quantity > 99999 or quantity ~= math.floor(quantity)) then
            return false, "invalid protected quantity for item " .. id
        end
    end
    return true
end

-- Reserve carried stock first, in stable slot order, then stored stock if short.
-- Keep-all freezes all copies; a quantity is a minimum reserve, never a retrieval.
function rules.allocate(items, keep)
    local ok, err = rules.validate(keep)
    if not ok then return nil, err end
    local ordered, remaining, reserved = {}, {}, {}
    for _, item in ipairs(items) do ordered[#ordered + 1] = item end
    table.sort(ordered, function(a, b)
        if a.container_id ~= b.container_id then return a.container_id < b.container_id end
        return a.index < b.index
    end)
    for _, item in ipairs(ordered) do
        local id = tostring(item.item_id)
        local wanted = keep[id]
        if wanted == "all" then
            reserved[key(item)] = item.quantity
        elseif type(wanted) == "number" then
            if remaining[id] == nil then remaining[id] = wanted end
            local quantity = math.min(item.quantity, remaining[id])
            reserved[key(item)] = quantity
            remaining[id] = remaining[id] - quantity
        end
    end
    return reserved
end

function rules.carried_surplus(items, keep, item_id, carry_floor)
    local ok = rules.validate(keep)
    if not ok or keep[tostring(item_id)] == "all" then return 0 end
    local carried, total = 0, 0
    for _, item in ipairs(items) do
        if item.item_id == item_id then
            total = total + item.quantity
            if item.container_id == 0 then carried = carried + item.quantity end
        end
    end
    local wanted = keep[tostring(item_id)] or 0
    local minimum = carry_floor == nil and wanted or math.min(wanted, math.max(0, carry_floor))
    return math.max(0, math.min(carried - minimum, total - wanted))
end

return rules
