package.path = './addons/oddorg/?.lua;' .. package.path

local real_print = print
local calls = { file = 0, item = 0, resources = 0, releases = {}, warnings = 0 }
local device = nil
local next_texture = 1000
local fail_file, fail_bitmap = {}, {}
local resources = {}
local throw_device, throw_file, throw_resource = false, false, false

local function make_texture()
    next_texture = next_texture + 1
    local id = next_texture
    return {
        id = id,
        Release = function()
            calls.releases[id] = (calls.releases[id] or 0) + 1
        end,
    }
end

local ffi_stub = {
    NULL = false,
    cdef = function() end,
    new = function(kind, value)
        if kind == 'IDirect3DTexture8*[1]' then return {} end
        assert(kind == 'IDirect3DTexture8*')
        return value
    end,
    cast = function(_, value) return value.id end,
    gc = function(value, callback)
        assert(value.id ~= nil and callback == nil, 'manual release did not detach the finalizer')
        return value
    end,
    C = {
        S_OK = 0,
        D3DX_DEFAULT = 0xFFFFFFFF,
        D3DFMT_A8R8G8B8 = 21,
        D3DPOOL_MANAGED = 1,
        D3DXCreateTextureFromFileA = function(_, path, out)
            calls.file = calls.file + 1
            if throw_file then error('file binding unavailable') end
            if fail_file[path] then return -1 end
            out[0] = make_texture()
            return 0
        end,
        D3DXCreateTextureFromFileInMemoryEx = function(_, bitmap, size, _, _, _, _, _, _, _, _, _, _, _, out)
            calls.item = calls.item + 1
            assert(bitmap ~= nil and size > 0)
            if fail_bitmap[bitmap] then return -2 end
            out[0] = make_texture()
            return 0
        end,
    },
}

package.loaded.ffi = ffi_stub
package.loaded.d3d8 = {
    get_device = function()
        calls.devices = (calls.devices or 0) + 1
        if throw_device then error('device unavailable') end
        return device
    end,
    gc_safe_release = function(value) return value end,
}
AshitaCore = {
    GetResourceManager = function()
        return {
            GetItemById = function(_, id)
                calls.resources = calls.resources + 1
                if throw_resource then error('resource table unavailable') end
                return resources[id]
            end,
        }
    end,
}
print = function(message)
    calls.warnings = calls.warnings + 1
    assert(tostring(message):find('[OddOrg UI]', 1, true))
end

local texture = assert(loadfile('./addons/oddorg/ui_textures.lua'))()
local passed = 0
local function test(name, fn)
    texture.release()
    device = { id = 1 }
    calls.file, calls.item, calls.resources, calls.warnings, calls.devices = 0, 0, 0, 0, 0
    calls.releases, fail_file, fail_bitmap, resources = {}, {}, {}, {}
    throw_device, throw_file, throw_resource = false, false, false
    fn()
    passed = passed + 1
    real_print('PASS ' .. name)
end

test('file textures cache success and failure while a missing device stays transient', function()
    device = nil
    assert(texture.file('root', 'destination-atlas.png') == nil and calls.file == 0)
    device = { id = 1 }
    local id = assert(texture.file('root', 'destination-atlas.png'))
    assert(texture.file('root', 'destination-atlas.png') == id and calls.file == 1)
    fail_file['root\\assets\\surface-atlas.png'] = true
    assert(texture.file('root', 'surface-atlas.png') == nil)
    assert(texture.file('root', 'surface-atlas.png') == nil)
    assert(calls.file == 2 and calls.warnings == 1, 'failed file retried or warned every frame')
end)

test('item textures reject bad ids and cache resource and bitmap failures', function()
    assert(texture.item(nil) == nil and texture.item(0) == nil and texture.item(-1) == nil)
    assert(texture.item(1.5) == nil and texture.item(65535) == nil)
    assert(calls.resources == 0 and calls.item == 0, 'invalid ids reached native bindings')

    assert(texture.item(10) == nil and texture.item(10) == nil)
    resources[11] = { Bitmap = nil, ImageSize = 32 }
    assert(texture.item(11) == nil and texture.item(11) == nil)
    resources[12] = { Bitmap = 'bitmap-12', ImageSize = nil }
    assert(texture.item(12) == nil and texture.item(12) == nil)
    assert(calls.resources == 3 and calls.item == 0, 'failed item lookup was not cached')
    assert(calls.warnings == 3, 'item failure reasons did not warn exactly once')

    resources[13] = { Bitmap = 'bitmap-13', ImageSize = 64 }
    local id = assert(texture.item(13))
    assert(texture.item(13) == id and calls.item == 1, 'item texture was recreated for a visible row')
end)

test('device replacement and release retry failures and free each texture once', function()
    fail_file['root\\assets\\surface-atlas.png'] = true
    assert(texture.file('root', 'surface-atlas.png') == nil and calls.file == 1)
    local first = assert(texture.file('root', 'destination-atlas.png'))
    fail_file['root\\assets\\surface-atlas.png'] = nil
    device = { id = 2 }
    assert(texture.file('root', 'surface-atlas.png') and calls.file == 3,
        'new device reused the previous device failure')
    assert(calls.releases[first] == 1, 'device replacement did not release old ownership once')
    texture.release()
    for _, count in pairs(calls.releases) do assert(count == 1, 'texture released more than once') end
    texture.release()
    for _, count in pairs(calls.releases) do assert(count == 1, 'idempotent release freed ownership twice') end
    device = { id = 2 }
    assert(texture.file('root', 'surface-atlas.png') and calls.file == 4,
        'release did not reset the cache for addon reload')
end)

test('thrown native boundaries fall back once and reload permits a retry', function()
    throw_device = true
    assert(texture.file('root', 'destination-atlas.png') == nil)
    assert(texture.file('root', 'destination-atlas.png') == nil)
    assert(calls.devices == 1 and calls.warnings == 1, 'device exception repeated every frame')
    texture.release()
    throw_device = false

    throw_file = true
    assert(texture.file('root', 'destination-atlas.png') == nil)
    assert(texture.file('root', 'destination-atlas.png') == nil)
    assert(calls.file == 1, 'thrown file binding was not cached')
    texture.release()
    assert(texture.file('root', 'destination-atlas.png') == nil and calls.file == 2,
        'release did not permit a failed binding retry')
    throw_file = false

    throw_resource = true
    assert(texture.item(40) == nil and texture.item(40) == nil)
    assert(calls.resources == 1 and calls.item == 0, 'resource exception reached a native bitmap binding')
    throw_resource = false
    resources[41] = { Bitmap = nil, ImageSize = 64 }
    assert(texture.item(41) == nil and calls.item == 0, 'nil bitmap reached a native binding')
end)

test('item cache evicts at 128 entries and releases all ownership exactly once', function()
    for id = 1, 129 do resources[id] = { Bitmap = 'bitmap-' .. id, ImageSize = 64 } end
    local first = assert(texture.item(1))
    assert(texture.item(1) == first and calls.item == 1, 'item cache did not reuse a hit')
    for id = 2, 129 do assert(texture.item(id)) end
    assert(calls.item == 129 and calls.releases[first] == 1, 'oldest item was not evicted exactly once')
    texture.release()
    local released = 0
    for _, count in pairs(calls.releases) do
        assert(count == 1, 'evicted or retained texture was released more than once')
        released = released + 1
    end
    assert(released == 129, 'release did not cover every owned item texture')
end)

print = real_print
real_print(('PASS %u ui texture backend cases; inert native stubs only'):format(passed))
