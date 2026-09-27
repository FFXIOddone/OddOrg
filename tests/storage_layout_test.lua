package.path = 'addons/oddorg/?.lua;' .. package.path
local layout = require('storage_layout')
local function yes(value, message) assert(value, message or 'expected true') end
local function no(value, message) assert(not value, message or 'expected false') end

yes(layout.validate(nil))
local data = { version=1, active='Automatic Care', sets={
    ['Automatic Care']={ crystals=7, clusters=7, ['gear.head']=12, furnishing=1 }
} }
yes(layout.validate(data))
no(layout.validate({version=1,active='x',sets={}}))
no(layout.validate({version=1,active='',sets={['bad!']={}}}))
no(layout.validate({version=1,active='',sets={['   ']={}}}))
no(layout.validate({version=1,active='x',sets={x={crystals=0}}}))
no(layout.validate({version=1,active='x',sets={x={crystals=8}}}))
no(layout.validate({version=1,active='x',sets={x={made_up=7}}}))
local thirteen={version=1,active='',sets={}}
for index=1,13 do thirteen.sets['Set '..index]={} end
no(layout.validate(thirteen))

assert(layout.classify({item_id=4096,resource_type=1,item_name='Misleading Ore'}) == 'crystals')
assert(layout.classify({item_id=4104,resource_type=1}) == 'clusters')
assert(layout.classify({item_id=1,resource_type=10}) == 'furnishing')
assert(layout.classify({item_id=2,resource_type=7,resource_flags=0x80}) == 'scroll')
assert(layout.classify({item_id=2,resource_type=0,item_name='Fire Crystal'}) == nil)
assert(layout.classify({item_id=2,resource_type=28}) == nil)
assert(layout.classify({item_id=2,resource_type=29}) == nil)
assert(layout.classify({item_id=2,resource_type=5,equippable=true,slot_category='head'}) == 'gear.head')
assert(layout.classify({item_id=2,resource_type=1,item_name='Headpiece'}) == 'item')

assert(layout.target(data,{item_id=4096,resource_type=8}) == 7)
yes(layout.assigned(data,{item_id=3,resource_type=10}))
no(layout.assigned(data,{item_id=3,resource_type=1}))
local config={items={['4096']=false,['3']=true}}
no(layout.effective_allowed(data,config,{item_id=4096,resource_type=8}))
yes(layout.effective_allowed(data,config,{item_id=3,resource_type=10}))
no(layout.effective_allowed(data,config,{item_id=3,resource_type=1}))
yes(layout.effective_allowed(nil,{items={}},{item_id=4096,resource_type=8}))
no(layout.effective_allowed(nil,{items={['4096']=false}},{item_id=4096,resource_type=8}))
no(layout.effective_allowed(nil,{items={}},{item_id=3,resource_type=1}))
yes(layout.effective_allowed(nil,{items={['3']=true}},{item_id=3,resource_type=1}))

local reordered={version=1,active='Automatic Care',sets={['Automatic Care']={furnishing=1,['gear.head']=12,clusters=7,crystals=7}}}
assert(layout.signature(data) == layout.signature(reordered))
local copy=layout.clone(data); copy.sets['Automatic Care'].crystals=5
assert(data.sets['Automatic Care'].crystals == 7)

print('storage_layout_test: ok')
