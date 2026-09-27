-- Pure saved-layout policy. This module deliberately has no Ashita, UI, or I/O dependencies.
local layout = {}

local definitions = {
    { 'gear.main_sub', 'Main/sub weapons', true }, { 'gear.main', 'Main weapons', true },
    { 'gear.sub', 'Off-hand equipment', true }, { 'gear.range', 'Ranged weapons', true },
    { 'gear.ammo', 'Ammo', true }, { 'gear.head', 'Head equipment', true },
    { 'gear.body', 'Body equipment', true }, { 'gear.hands', 'Hand equipment', true },
    { 'gear.legs', 'Leg equipment', true }, { 'gear.feet', 'Foot equipment', true },
    { 'gear.neck', 'Neck equipment', true }, { 'gear.waist', 'Waist equipment', true },
    { 'gear.ear', 'Earrings', true }, { 'gear.ring', 'Rings', true },
    { 'gear.back', 'Back equipment', true }, { 'gear.other', 'Other equipment', true },
    { 'item', 'General items (mixed)', false }, { 'quest_item', 'Quest items (mixed)', false },
    { 'fish', 'Fish', false }, { 'linkshell', 'Linkshell items', false },
    { 'usable_item', 'Usable items', false }, { 'crystals', 'Crystals', false },
    { 'clusters', 'Clusters', false }, { 'currency', 'Currency', false },
    { 'furnishing', 'Furnishings', false }, { 'plant', 'Plants', false },
    { 'flowerpot', 'Flowerpots', false }, { 'puppet_item', 'Puppet items', false },
    { 'mannequin', 'Mannequins', false }, { 'book', 'Books', false },
    { 'racing_form', 'Racing forms', false }, { 'betting_slip', 'Betting slips', false },
    { 'soul_plate', 'Soul plates', false }, { 'reflector', 'Reflectors', false },
    { 'logs', 'Logs', false }, { 'lottery_ticket', 'Lottery tickets', false },
    { 'tabula_m', 'Maze tabulae', false }, { 'tabula_r', 'Rallying tabulae', false },
    { 'voucher', 'Vouchers', false }, { 'rune', 'Runes', false },
    { 'evolith', 'Evoliths', false }, { 'storage_slip', 'Storage slips', false },
    { 'instinct', 'Instincts', false }, { 'scroll', 'Scrolls', false },
}

layout.types, layout.by_key = {}, {}
for _, value in ipairs(definitions) do
    local entry = { key=value[1], label=value[2], gear=value[3] }
    layout.types[#layout.types + 1], layout.by_key[entry.key] = entry, entry
end

local type_keys = {
    [1]='item', [2]='quest_item', [3]='fish', [6]='linkshell', [7]='usable_item',
    [9]='currency', [10]='furnishing', [11]='plant', [12]='flowerpot',
    [13]='puppet_item', [14]='mannequin', [15]='book', [16]='racing_form',
    [17]='betting_slip', [18]='soul_plate', [19]='reflector', [20]='logs',
    [21]='lottery_ticket', [22]='tabula_m', [23]='tabula_r', [24]='voucher',
    [25]='rune', [26]='evolith', [27]='storage_slip', [30]='instinct',
}
local bags = { [1]=true,[2]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,[9]=true,
    [10]=true,[11]=true,[12]=true,[13]=true,[14]=true,[15]=true,[16]=true }
local wardrobes = { [8]=true,[10]=true,[11]=true,[12]=true,[13]=true,[14]=true,[15]=true,[16]=true }
local gear_slots = { main_sub=true,main=true,sub=true,range=true,ammo=true,head=true,body=true,
    hands=true,legs=true,feet=true,neck=true,waist=true,ear=true,ring=true,back=true,other=true }

layout.presets = {
    {id='@portable',name='Portable split',description='Equipment in Wardrobe; general items in Satchel; crystals in Sack; usable items, scrolls, currency and quest items in Case.',
        routes={item=5,fish=5,logs=5,crystals=6,clusters=6,usable_item=7,scroll=7,currency=7,quest_item=7}},
    {id='@crafting',name='Crafting bench',description='Crystals, clusters, fish, logs and general items together in Safe. Usable items in Case, quest items in Sack, equipment in Wardrobe. General items includes non-crafting stock; preview first.',
        routes={item=1,fish=1,logs=1,crystals=1,clusters=1,usable_item=7,quest_item=6}},
    {id='@wardrobes',name='Wardrobe by slot',description='Weapons and ammo in Wardrobe; armor in Wardrobe 2; accessories in Wardrobe 3. Requires those wardrobes to be accessible. Usable items in Case and crystals in Sack; other item types stay put.',
        routes={usable_item=7,crystals=6,clusters=6}},
    {id='@archive',name='Home archive',description='Equipment in Locker; general stock and quest items in Safe; crystals and clusters in Storage (bulk runs in Mog House only). Usable items remain in Case. Locker must be accessible.',
        routes={item=1,quest_item=1,fish=1,logs=1,book=1,scroll=1,furnishing=1,plant=1,flowerpot=1,mannequin=1,crystals=2,clusters=2,usable_item=7}},
}
local presets_by_id = {}
for _,preset in ipairs(layout.presets) do
    presets_by_id[preset.id] = preset
    for _,category in ipairs(layout.types) do
        if category.gear then preset.routes[category.key] = preset.id == '@archive' and 4 or 8 end
    end
end
for _,slot in ipairs({'head','body','hands','legs','feet'}) do
    presets_by_id['@wardrobes'].routes['gear.'..slot] = 10
end
for _,slot in ipairs({'neck','waist','ear','ring','back'}) do
    presets_by_id['@wardrobes'].routes['gear.'..slot] = 11
end

function layout.preset(id) return presets_by_id[id] end
function layout.name(id)
    return presets_by_id[id] and presets_by_id[id].name or (id ~= '' and id or 'OddOrg defaults')
end
function layout.routes_for(data,id)
    return presets_by_id[id] and presets_by_id[id].routes or (data and data.sets and data.sets[id])
end

local function valid_name(value)
    return type(value) == 'string' and #value >= 1 and #value <= 32
        and value:match('^[A-Za-z0-9 _%-]+$') ~= nil
        and value:match('[A-Za-z0-9]') ~= nil
end

function layout.validate(data)
    if data == nil then return true end
    if type(data) ~= 'table' or data.version ~= 1 or type(data.active) ~= 'string'
        or type(data.sets) ~= 'table' then return false, 'Invalid storage layout.' end
    if data.overrides ~= nil then
        if type(data.overrides) ~= 'table' then return false, 'Invalid base layout overrides.' end
        for key,bag in pairs(data.overrides) do
            local category=layout.by_key[key]
            if not category or (bag ~= false and not bags[bag]) then return false, 'Invalid base layout destination.' end
            if wardrobes[bag] and not category.gear then return false, 'Only equipment can be assigned to a wardrobe.' end
        end
    end
    local count = 0
    for name, routes in pairs(data.sets) do
        count = count + 1
        if count > 12 then return false, 'Storage layouts are limited to 12 sets.' end
        if not valid_name(name) or type(routes) ~= 'table' then return false, 'Invalid storage layout name.' end
        for key, bag in pairs(routes) do
            local category = layout.by_key[key]
            if not category then return false, 'Unknown storage category: ' .. tostring(key) end
            if type(bag) ~= 'number' or bag ~= math.floor(bag) or not bags[bag] then
                return false, 'Invalid destination for ' .. key .. '.'
            end
            if wardrobes[bag] and not category.gear then
                return false, 'Only equipment can be assigned to a wardrobe.'
            end
        end
    end
    if data.active ~= '' and data.sets[data.active] == nil and not presets_by_id[data.active] then
        return false, 'Active storage layout does not exist.'
    end
    return true
end

function layout.active_routes(data)
    local ok, err = layout.validate(data)
    if not ok then return nil, err end
    if data == nil or data.active == '' then return nil end
    return layout.routes_for(data,data.active)
end

function layout.classify(item)
    if type(item) ~= 'table' then return nil end
    local id = tonumber(item.item_id) or 0
    if id >= 4096 and id <= 4103 then return 'crystals' end
    if id >= 4104 and id <= 4111 then return 'clusters' end
    local item_type = tonumber(item.resource_type) or 0
    local equippable = item.equippable == true or item_type == 4 or item_type == 5
    if equippable then
        local slot = tostring(item.slot_category or 'other')
        if not gear_slots[slot] then slot = 'other' end
        return 'gear.' .. slot
    end
    -- Arithmetic is sufficient for this single flag and keeps the module dependency-free.
    if math.floor((tonumber(item.resource_flags) or 0) / 0x0080) % 2 == 1 then return 'scroll' end
    if item_type == 8 then return nil end -- Unknown crystal-family IDs fail closed.
    return type_keys[item_type]
end

function layout.target(data, item)
    local valid, validation_error = layout.validate(data)
    if not valid then return nil, validation_error end
    if data and data.active == '' then
        local key=layout.classify(item)
        return key and data.overrides and data.overrides[key]
    end
    local routes, err = layout.active_routes(data)
    if err or not routes then return nil, err end
    local key = layout.classify(item)
    return key and routes[key] or nil
end

function layout.assigned(data, item)
    local target=layout.target(data,item)
    return target ~= nil and target ~= false
end

function layout.effective_allowed(data, config, item)
    local rules = type(config) == 'table' and config.items or nil
    local explicit = nil
    if type(rules) == 'table' then
        explicit = rules[tostring(tonumber(item and item.item_id) or 0)]
    end
    if explicit == false then return false end
    local routes, err = layout.active_routes(data)
    if err then return false end
    if data and data.active == '' then
        local destination=layout.target(data,item)
        if destination ~= nil then return destination ~= false end
    end
    if routes then return layout.assigned(data, item) end
    if explicit ~= nil then return explicit end
    local id = tonumber(item and item.item_id) or 0
    return id >= 4096 and id <= 4111
end

function layout.clone(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, item in pairs(value) do copy[layout.clone(key)] = layout.clone(item) end
    return copy
end

function layout.signature(data)
    if data == nil then return 'legacy' end
    local ok = layout.validate(data)
    if not ok then return nil end
    local names = {}
    for name in pairs(data.sets) do names[#names + 1] = name end
    table.sort(names)
    local parts = { 'v1', 'active=' .. data.active }
    for _,category in ipairs(layout.types) do
        local bag=data.overrides and data.overrides[category.key]
        if bag ~= nil then parts[#parts+1]='override:'..category.key..'='..tostring(bag) end
    end
    local preset = presets_by_id[data.active]
    if preset then
        for _,category in ipairs(layout.types) do
            local bag = preset.routes[category.key]
            if bag then parts[#parts+1]='preset:'..category.key..'='..bag end
        end
    end
    for _, name in ipairs(names) do
        parts[#parts + 1] = 'set=' .. name
        local keys = {}
        for key in pairs(data.sets[name]) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do parts[#parts + 1] = key .. '=' .. data.sets[name][key] end
    end
    return table.concat(parts, '|')
end

return layout
