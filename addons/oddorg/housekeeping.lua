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
        local protected = reserved['0:' .. item.index] or 0
        if item.container_id == 0 and permitted
            and protected < item.quantity and (protected == 0 or sort_all) and not item.locked
            and not item.equipped and not item.social then
            local candidate = {}
            for key,value in pairs(item) do candidate[key]=value end
            candidate.quantity=item.quantity-protected
            candidate.frees_slot=protected == 0
            candidates[#candidates + 1] = candidate
        end
    end
    local function move_for(item,bag,quantity,stacking)
        return {move_id='background-'..character..'-'..item.index,character_slug=character,
            item_id=item.item_id,item_name=item.item_name,quantity=quantity,
            source_container_id=0,source_index=item.index,target_container_id=bag,
            stack_size=item.stack_size,frees_slot=item.frees_slot and quantity==item.quantity,
            purpose=stacking and 'stack' or nil}
    end
    -- Existing partial stacks beat placement preferences. Only Inventory is a
    -- source here: completed stored stacks never get relocated by automatic care.
    local targets={}
    for _,stored in ipairs(snapshot.items) do
        if stored.container_id~=0 and not stored.locked and not stored.equipped and (tonumber(stored.flags) or 0)==0
            and (stored.stack_size or 1)>stored.quantity
            and (snapshot.capacities[stored.container_id] or 0)>0
            and (not snapshot.stack_access or snapshot.stack_access[stored.container_id]~=false) then
            targets[#targets+1]=stored
        end
    end
    table.sort(targets,function(a,b)
        if a.quantity~=b.quantity then return a.quantity>b.quantity end
        if a.container_id~=b.container_id then return a.container_id<b.container_id end
        return a.index<b.index
    end)
    for _,item in ipairs(candidates) do
        for _,target in ipairs(targets) do
            if item.item_id==target.item_id and item.item_name==target.item_name then
                local room=math.max(0,math.min(item.stack_size,target.stack_size)-target.quantity)
                local quantity=math.min(room,item.quantity)
                local empty=(snapshot.capacities[target.container_id] or 0)-(snapshot.counts[target.container_id] or 0)
                -- Native split transfers need an empty destination slot before
                -- Auto Sort can combine them. Whole-source transfers can merge.
                if quantity>0 and (empty>0 or (item.frees_slot and quantity==item.quantity)) then
                    return move_for(item,target.container_id,quantity,true),'moving',free
                end
            end
        end
    end
    for _,item in ipairs(candidates) do
        local route=destinations and destinations(item) or {5,6,7}
        for _,bag in ipairs(route) do
            if (snapshot.capacities[bag] or 0)>(snapshot.counts[bag] or 0) then
                return move_for(item,bag,item.quantity,false),'moving',free
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
