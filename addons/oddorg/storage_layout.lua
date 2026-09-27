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

-- Preferred home and overflow, followed by spare general-purpose storage.
-- Inventory is reserved for carried supplies, never a general overflow bag.
local default_routes = {
    item={5,9}, fish={5,9}, logs={5,9},
    usable_item={7,1}, scroll={7,1},
    crystals={6,9}, clusters={6,9},
    quest_item={4,9}, currency={1,9},
    furnishing={2,1}, plant={2,1}, flowerpot={2,1}, mannequin={2,1},
}
function layout.default_route_for_category(category)
    if not category or category == 'linkshell' or category:find('gear.',1,true) == 1 then return {} end
    return default_routes[category] or {1,9}
end
function layout.default_route(item, include_spare)
    local preferred=layout.default_route_for_category(layout.classify(item))
    if not include_spare then return preferred end
    if #preferred==0 then return {} end
    local route,seen={},{}
    local function add(bag)
        if not seen[bag] then route[#route+1]=bag; seen[bag]=true end
    end
    for _,bag in ipairs(preferred) do add(bag) end
    for _,bag in ipairs({1,9,5,6,7,4,2}) do add(bag) end
    return route
end

-- Prepared foods/drinks: exact usable-item IDs from CatsEye item_basic.sql,
-- AH categories 52-58 (excludes raw fish and ingredients), source SHA-256
-- 044b84c8ae93fca8bff9d2f6864f536e4eb06a8f8e26f263c97fbc8884254ab6.
-- Membership is explicit; similarly named rewards and ingredients are not food.
local food_ids = {}
for _,id in ipairs({
    4266,4267,4268,4269,4270,4271,4275,4276,4277,4278,4279,4280,4281,4282,4283,4284,4285,4286,4287,4292,4293,4294,4295,4296,
    4297,4298,4299,4300,4301,4302,4303,4320,4321,4322,4323,4324,4325,4326,4327,4328,4329,4330,4331,4332,4333,4334,4335,4336,
    4337,4338,4339,4340,4341,4342,4343,4344,4345,4346,4347,4348,4349,4350,4353,4355,4356,4364,4371,4376,4380,4381,4391,4393,
    4394,4395,4396,4397,4398,4404,4405,4406,4407,4408,4409,4410,4411,4413,4414,4415,4416,4417,4418,4419,4420,4421,4422,4423,
    4424,4425,4430,4433,4434,4436,4437,4438,4439,4440,4441,4442,4446,4452,4453,4455,4456,4457,4458,4459,4465,4466,4467,4487,
    4488,4489,4490,4492,4493,4494,4495,4496,4497,4498,4499,4502,4506,4507,4510,4512,4516,4517,4518,4519,4520,4521,4522,4523,
    4524,4525,4532,4533,4534,4535,4536,4537,4538,4539,4540,4541,4542,4543,4544,4546,4547,4548,4549,4550,4551,4552,4553,4554,
    4555,4556,4557,4558,4559,4560,4561,4563,4564,4568,4572,4573,4574,4575,4576,4577,4578,4581,4582,4583,4584,4585,4586,4587,
    4588,4589,4590,4591,4592,4594,4595,4599,4601,4603,4604,4605,5142,5143,5144,5145,5146,5147,5148,5149,5150,5151,5153,5155,
    5156,5157,5158,5159,5160,5161,5162,5163,5166,5167,5168,5169,5170,5171,5172,5173,5174,5175,5176,5177,5178,5179,5180,5181,
    5182,5183,5184,5185,5186,5188,5189,5190,5191,5192,5193,5196,5197,5198,5199,5200,5201,5202,5207,5211,5212,5213,5214,5215,
    5216,5217,5218,5219,5220,5230,5231,5238,5239,5240,5266,5542,5543,5544,5545,5546,5547,5548,5549,5550,5551,5552,5553,5554,
    5555,5556,5557,5558,5559,5560,5567,5570,5572,5573,5574,5576,5577,5578,5579,5580,5582,5583,5584,5585,5586,5587,5588,5589,
    5590,5591,5592,5593,5594,5595,5596,5597,5598,5599,5600,5601,5602,5603,5609,5610,5611,5612,5613,5614,5615,5616,5617,5618,
    5619,5623,5624,5625,5626,5627,5628,5629,5630,5631,5632,5633,5634,5635,5636,5637,5638,5642,5643,5644,5645,5646,5647,5648,
    5652,5653,5654,5655,5656,5657,5658,5659,5660,5663,5664,5665,5666,5669,5670,5671,5672,5673,5676,5677,5678,5679,5681,5683,
    5685,5686,5687,5689,5690,5691,5692,5693,5694,5695,5696,5697,5698,5699,5700,5701,5702,5718,5719,5720,5721,5722,5727,5728,
    5729,5730,5731,5732,5737,5738,5739,5743,5744,5745,5746,5750,5751,5752,5753,5756,5757,5758,5759,5760,5761,5762,5763,5764,
    5765,5766,5767,5771,5772,5773,5774,5775,5776,5777,5778,5779,5780,5781,5782,5783,5784,5859,5860,5861,5862,5885,5886,5887,
    5888,5889,5890,5891,5892,5922,5923,5924,5925,5926,5927,5928,5929,5930,5931,5932,5933,5934,5935,5940,5941,5942,5943,5944,
    5968,5969,5970,5971,5972,5973,5974,5975,5976,5977,5978,5979,5980,5981,5982,5983,5998,5999,6009,6010,6063,6064,6069,6070,
    6071,6072,6211,6212,6213,6214,6215,6216,6217,6218,6219,6220,6221,6223,6224,6225,6257,6258,6259,6260,6261,6262,6263,6272,
    6273,6274,6275,6276,6277,6339,6340,6341,6342,6343,6344,6381,6394,6395,6396,6397,6406,6407,6458,6459,6460,6461,6462,6463,
    6464,6465,6466,6467,6468,6469,6470,6471,6567,6568,6583,6584,6599,6600,6601,6602,6609,6610,6611,6612,6686,6687,
}) do food_ids[id]=true end
local medicine_ids = {}
for id=4112,4145 do medicine_ids[id]=true end
for _,id in ipairs({4148,4149,4150,4151,4153,4154,4155,4156,4164,4165,4174,4175,
    5254,5255,5327,5328,5356,5357,5358,5431,5432,5433,5716,
    5824,5825,5826,5827,5828,5829,5830,5831,5986,5987}) do medicine_ids[id]=true end
function layout.supply_kind(item)
    if layout.classify(item) ~= 'usable_item' then return nil end
    if medicine_ids[item.item_id] then return 'medicine' end
    if food_ids[item.item_id] then return 'food' end
    return nil
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
    return #layout.default_route(item) > 0
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
