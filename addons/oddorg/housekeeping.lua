-- Background policy only: no game, files, UI, or transport access.
local policy = {}

function policy.validate(config)
    if type(config) ~= 'table' or type(config.enabled) ~= 'boolean'
        or type(config.free_slots) ~= 'number' or config.free_slots ~= math.floor(config.free_slots)
        or config.free_slots < 1 or config.free_slots > 80 or type(config.items) ~= 'table' then
        return false, 'Invalid background settings; expected 1-80 free slots and an item allowlist.'
    end
    for id, allowed in pairs(config.items) do
        local number = tonumber(id)
        if not number or number < 1 or number > 65534 or tostring(number) ~= id or number ~= math.floor(number)
            or type(allowed) ~= 'boolean' then
            return false, 'Invalid background item rule.'
        end
    end
    return true
end

function policy.allowed(config, id)
    local explicit = config.items[tostring(id)]
    if explicit ~= nil then return explicit end
    return id >= 4096 and id <= 4111
end

-- A partial move that leaves a protected stack behind creates no space. Prefer
-- whole unreserved stacks, using existing stack room before empty bag slots.
function policy.choose(snapshot, reserved, config, character, destinations, allowed, sorting)
    local free = (snapshot.capacities[0] or 0) - (snapshot.counts[0] or 0)
    local goal = math.min(config.free_slots, snapshot.capacities[0] or 0)
    local sort_all = sorting == true or (sorting == nil and destinations ~= nil)
    if not sort_all and free >= goal then return nil, 'ready', free end
    local candidates = {}
    for _, item in ipairs(snapshot.items) do
        local permitted = allowed and allowed(item)
        if allowed == nil then permitted = policy.allowed(config, item.item_id) end
        if item.container_id == 0 and permitted
            and (reserved['0:' .. item.index] or 0) == 0 and not item.locked
            and not item.equipped and not item.social then
            candidates[#candidates + 1] = item
        end
    end
    -- Index destination room once per fresh snapshot, rather than rescanning
    -- every stored item for each candidate, destination and preference pass.
    local smallest_stack, routes = {}, {}
    for _, stored in ipairs(snapshot.items) do
        if not stored.locked then
            local bag = smallest_stack[stored.container_id] or {}
            smallest_stack[stored.container_id] = bag
            bag[stored.item_id] = math.min(bag[stored.item_id] or stored.quantity, stored.quantity)
        end
    end
    for _, item in ipairs(candidates) do
        routes[item] = destinations and destinations(item) or { 5, 6, 7 }
    end
    for pass = 1, 2 do
        for _, item in ipairs(candidates) do
            for _, bag in ipairs(routes[item]) do
                local count = smallest_stack[bag] and smallest_stack[bag][item.item_id]
                local room = count and math.max(0, item.stack_size - count) or 0
                local empty = (snapshot.capacities[bag] or 0) - (snapshot.counts[bag] or 0)
                if (pass == 1 and room >= item.quantity) or (pass == 2 and empty > 0) then
                    return {
                        move_id='background-' .. character .. '-' .. item.index,
                        character_slug=character, item_id=item.item_id, item_name=item.item_name,
                        quantity=item.quantity, source_container_id=0, source_index=item.index,
                        target_container_id=bag, stack_size=item.stack_size,
                    }, 'moving', free
                end
            end
        end
    end
    -- Sorting can be finished while Inventory still needs attention. Honor an
    -- enabled space target, and never call a completely full Inventory ready.
    if sort_all and #candidates == 0 and free > 0
        and (not config.enabled or free >= goal) then return nil, 'ready', free end
    return nil, #candidates == 0 and 'protected' or 'bags_full', free
end

return policy
