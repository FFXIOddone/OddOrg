local textures = {}

local MAX_ITEM_TEXTURES = 128
local ffi, d3d
local backend_failed = false
local device_id = nil
local file_cache, item_cache = {}, {}
local item_count, item_clock = 0, 0
local warned = {}

local function warn_once(asset, reason, detail)
    local key = tostring(asset) .. '|' .. tostring(reason)
    if warned[key] then return end
    warned[key] = true
    if print ~= nil then
        local suffix = detail ~= nil and (': ' .. tostring(detail)) or ''
        print(('[OddOrg UI] Texture fallback for %s (%s)%s'):format(asset, reason, suffix))
    end
end

local function load_backend()
    if backend_failed then return false end
    if ffi ~= nil and d3d ~= nil then return true end

    local ok_ffi, ffi_value = pcall(require, 'ffi')
    local ok_d3d, d3d_value = pcall(require, 'd3d8')
    if not ok_ffi or not ok_d3d then
        backend_failed = true
        warn_once('native backend', 'unavailable', ok_ffi and d3d_value or ffi_value)
        return false
    end
    -- d3d8 owns the Direct3D and D3DX declarations used below.
    ffi, d3d = ffi_value, d3d_value
    return true
end

local function release_entry(entry)
    if entry == nil or entry.texture == nil then return end
    local owned = entry.texture
    entry.texture = nil
    ffi.gc(owned, nil)
    owned:Release()
end

local function clear_caches()
    for _, entry in pairs(file_cache) do release_entry(entry) end
    for _, entry in pairs(item_cache) do release_entry(entry) end
    file_cache, item_cache = {}, {}
    item_count, item_clock = 0, 0
end

local function current_device()
    if not load_backend() then return nil end
    local ok, device = pcall(d3d.get_device)
    if not ok then
        backend_failed = true
        warn_once('native backend', 'device lookup failed', device)
        return nil
    end
    -- Device creation/reset is transient; retain the prior cache until a real
    -- replacement device can be identified.
    if device == nil then return nil end
    local observed_id = tonumber(ffi.cast('uint32_t', device))
    if observed_id == nil or observed_id == 0 then
        warn_once('native backend', 'invalid device')
        return nil
    end
    if device_id ~= nil and device_id ~= observed_id then clear_caches() end
    device_id = observed_id
    return device
end

local function texture_result(out, asset)
    local raw = out[0]
    if raw == nil or (ffi.NULL ~= nil and raw == ffi.NULL) then
        warn_once(asset, 'empty native result')
        return nil
    end
    local owned = ffi.new('IDirect3DTexture8*', raw)
    local guarded = d3d.gc_safe_release(owned)
    if guarded ~= nil then owned = guarded end
    local id = tonumber(ffi.cast('uint32_t', owned))
    if id == nil or id == 0 then
        ffi.gc(owned, nil)
        owned:Release()
        warn_once(asset, 'invalid texture id')
        return nil
    end
    return { texture = owned, id = id }
end

local function failed(cache, key, asset, reason, detail)
    cache[key] = { failed = true }
    warn_once(asset, reason, detail)
    return nil
end

function textures.file(addon_path, filename)
    if type(addon_path) ~= 'string' or addon_path == ''
        or type(filename) ~= 'string' or filename == '' then
        return nil
    end
    local device = current_device()
    if device == nil then return nil end

    local path = addon_path:gsub('[\\/]+$', '') .. '\\assets\\' .. filename
    local cached = file_cache[path]
    if cached ~= nil then return cached.id end

    local out = ffi.new('IDirect3DTexture8*[1]')
    local ok, hr = pcall(function()
        return ffi.C.D3DXCreateTextureFromFileA(device, path, out)
    end)
    if not ok then
        return failed(file_cache, path, filename, 'file binding failed', hr)
    end
    if hr ~= ffi.C.S_OK then
        return failed(file_cache, path, filename, 'file load failed', ('HRESULT %08X'):format(tonumber(hr)))
    end
    local entry = texture_result(out, filename)
    if entry == nil then
        file_cache[path] = { failed = true }
        return nil
    end
    file_cache[path] = entry
    return entry.id
end

local function valid_item_id(item_id)
    return type(item_id) == 'number' and item_id == math.floor(item_id)
        and item_id > 0 and item_id < 65535
end

local function touch_item(entry)
    item_clock = item_clock + 1
    entry.used = item_clock
end

local function evict_oldest_item()
    if item_count < MAX_ITEM_TEXTURES then return end
    local oldest_key, oldest_used
    for key, entry in pairs(item_cache) do
        if oldest_used == nil or entry.used < oldest_used then
            oldest_key, oldest_used = key, entry.used
        end
    end
    if oldest_key ~= nil then
        release_entry(item_cache[oldest_key])
        item_cache[oldest_key] = nil
        item_count = item_count - 1
    end
end

local function cache_item(item_id, entry)
    evict_oldest_item()
    touch_item(entry)
    item_cache[item_id] = entry
    item_count = item_count + 1
    return entry.id
end

function textures.item(item_id)
    if not valid_item_id(item_id) then return nil end
    local device = current_device()
    if device == nil then return nil end

    local cached = item_cache[item_id]
    if cached ~= nil then
        touch_item(cached)
        return cached.id
    end

    local asset = 'item ' .. tostring(item_id)
    local manager
    if AshitaCore and AshitaCore.GetResourceManager then
        local ok, value = pcall(AshitaCore.GetResourceManager, AshitaCore)
        if not ok then
            warn_once(asset, 'resource manager failed', value)
            cache_item(item_id, { failed = true })
            return nil
        end
        manager = value
    end
    local item
    if manager and manager.GetItemById then
        local ok, value = pcall(manager.GetItemById, manager, item_id)
        if not ok then
            warn_once(asset, 'resource lookup failed', value)
            cache_item(item_id, { failed = true })
            return nil
        end
        item = value
    end
    if item == nil then
        warn_once(asset, 'resource unavailable')
        cache_item(item_id, { failed = true })
        return nil
    end
    local size = tonumber(item.ImageSize)
    if item.Bitmap == nil or (ffi.NULL ~= nil and item.Bitmap == ffi.NULL) or size == nil or size <= 0 then
        warn_once(asset, 'missing bitmap')
        cache_item(item_id, { failed = true })
        return nil
    end

    local out = ffi.new('IDirect3DTexture8*[1]')
    local ok, hr = pcall(function()
        return ffi.C.D3DXCreateTextureFromFileInMemoryEx(
            device, item.Bitmap, size, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 1, 0,
            ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT,
            ffi.C.D3DX_DEFAULT, 0xFF000000, nil, nil, out)
    end)
    if not ok then
        warn_once(asset, 'bitmap binding failed', hr)
        cache_item(item_id, { failed = true })
        return nil
    end
    if hr ~= ffi.C.S_OK then
        warn_once(asset, 'bitmap load failed', ('HRESULT %08X'):format(tonumber(hr)))
        cache_item(item_id, { failed = true })
        return nil
    end
    local entry = texture_result(out, asset)
    if entry == nil then
        cache_item(item_id, { failed = true })
        return nil
    end
    return cache_item(item_id, entry)
end

function textures.release()
    clear_caches()
    device_id = nil
    warned = {}
    backend_failed = false
end

return textures
