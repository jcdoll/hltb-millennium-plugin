local json = require("json")
local logger = require("logger")
local millennium = require("millennium")

local M = {}

-- Result cache constants
local CACHE_DURATION = 12 * 60 * 60 -- 12 hours (seconds)
local MAX_CACHE_AGE = 90 * 24 * 60 * 60 -- 90 days (seconds)
local MAX_CACHE_ENTRIES = 2000
local PRUNE_INTERVAL = 50

-- In-memory stores
local result_cache = {} -- { [app_id] = { data, timestamp, notFound } }
local id_cache = { mappings = {}, metadata = {} } -- { mappings = { [steam_id] = hltb_id }, metadata = { timestamp, steamUserId } }
local write_count = 0

-- File paths

local function get_cache_path()
    return millennium.get_install_path() .. "/cache.json"
end

local function get_id_cache_path()
    return millennium.get_install_path() .. "/id_cache.json"
end

-- File I/O helpers

local function read_json_file(path)
    local file = io.open(path, "r")
    if not file then return nil end

    local content = file:read("*a")
    file:close()

    local ok, parsed = pcall(json.decode, content)
    if not ok or type(parsed) ~= "table" then
        return nil
    end

    return parsed
end

local function write_json_file(path, data)
    local file, err = io.open(path, "w")
    if not file then
        logger:error("Failed to write " .. path .. ": " .. (err or "unknown"))
        return false
    end

    file:write(json.encode(data))
    file:close()
    return true
end

-- Result cache

local function prune_result_cache()
    local now = os.time()

    -- Remove expired entries
    for app_id, entry in pairs(result_cache) do
        if now - entry.timestamp >= MAX_CACHE_AGE then
            result_cache[app_id] = nil
        end
    end

    -- If still over limit, keep only the newest entries
    local count = 0
    for _ in pairs(result_cache) do count = count + 1 end

    if count > MAX_CACHE_ENTRIES then
        local entries = {}
        for app_id, entry in pairs(result_cache) do
            table.insert(entries, { app_id = app_id, entry = entry })
        end
        table.sort(entries, function(a, b)
            return a.entry.timestamp > b.entry.timestamp
        end)

        result_cache = {}
        for i = 1, MAX_CACHE_ENTRIES do
            result_cache[entries[i].app_id] = entries[i].entry
        end
        logger:info("Pruned cache to " .. MAX_CACHE_ENTRIES .. " entries")
    end
end

function M.get(app_id)
    local key = tostring(app_id)
    local entry = result_cache[key]
    if not entry then return nil end

    local age = os.time() - entry.timestamp

    -- Hard expiry
    if age > MAX_CACHE_AGE then
        result_cache[key] = nil
        return nil
    end

    local is_stale = age > CACHE_DURATION
    return entry, is_stale
end

-- Merge new data with existing cached data, preferring new values where present
-- but preserving existing values when new is missing them. This protects against
-- transient HLTB responses that drop a field (e.g. comp_100 unset on this fetch
-- but present last fetch) from erasing previously-known values.
local function merge_with_existing(new_data, existing_data)
    if not existing_data then return new_data end
    if not new_data then return existing_data end

    local merged = {}
    for k, v in pairs(new_data) do merged[k] = v end

    -- Preserve game identity if new data is just a search miss
    if not merged.game_id and existing_data.game_id then
        merged.game_id = existing_data.game_id
        merged.game_name = merged.game_name or existing_data.game_name
    end

    -- Preserve completion times field-by-field
    for _, field in ipairs({ "comp_main", "comp_plus", "comp_100" }) do
        local new_val = merged[field] or 0
        local old_val = existing_data[field] or 0
        if new_val <= 0 and old_val > 0 then
            merged[field] = existing_data[field]
        end
    end

    return merged
end

function M.set(app_id, data)
    local key = tostring(app_id)

    local existing = result_cache[key]
    local merged = merge_with_existing(data, existing and existing.data or nil)

    result_cache[key] = {
        data = merged,
        timestamp = os.time(),
        -- True when fetch_fresh returned nil (network/lookup error).
        -- Partial results (HLTB returned no match) have data.searched_name
        -- but no data.game_id; the frontend handles these via the isMiss check.
        notFound = merged == nil,
    }

    write_count = write_count + 1
    if write_count >= PRUNE_INTERVAL then
        write_count = 0
        prune_result_cache()
    end

    M.save_result_cache()
end

function M.clear()
    result_cache = {}
    write_count = 0
    os.remove(get_cache_path())
    logger:info("Result cache cleared")
end

function M.stats()
    local count = 0
    local oldest = nil

    for _, entry in pairs(result_cache) do
        count = count + 1
        if oldest == nil or entry.timestamp < oldest then
            oldest = entry.timestamp
        end
    end

    return { count = count, oldestTimestamp = oldest }
end

-- ID cache

function M.get_hltb_id(app_id)
    return id_cache.mappings[tostring(app_id)]
end

function M.set_id_mappings(mappings, steam_user_id)
    local store = {}
    for _, mapping in ipairs(mappings) do
        if mapping.steam_id and mapping.hltb_id and mapping.hltb_id ~= 0 then
            -- Use string keys to avoid sparse array issues in JSON serialization
            store[tostring(mapping.steam_id)] = mapping.hltb_id
        end
    end

    id_cache = {
        mappings = store,
        metadata = {
            timestamp = os.time(),
            steamUserId = steam_user_id,
        },
    }

    M.save_id_cache()
    local count = 0
    for _ in pairs(store) do count = count + 1 end
    logger:info("ID cache updated with " .. count .. " mappings")
end

function M.clear_id_cache()
    id_cache = { mappings = {}, metadata = {} }
    os.remove(get_id_cache_path())
    logger:info("ID cache cleared")
end

function M.id_cache_stats()
    local count = 0
    for _ in pairs(id_cache.mappings) do count = count + 1 end

    local age_seconds = nil
    if id_cache.metadata.timestamp then
        age_seconds = os.time() - id_cache.metadata.timestamp
    end

    return {
        count = count,
        steamUserId = id_cache.metadata.steamUserId,
        ageSeconds = age_seconds,
    }
end

function M.is_id_cache_valid(steam_user_id)
    if not id_cache.metadata.steamUserId then return false end
    if id_cache.metadata.steamUserId ~= steam_user_id then return false end

    local count = 0
    for _ in pairs(id_cache.mappings) do count = count + 1 end
    return count > 0
end

-- Persistence

function M.save_result_cache()
    write_json_file(get_cache_path(), result_cache)
end

function M.save_id_cache()
    write_json_file(get_id_cache_path(), id_cache)
end

function M.load()
    -- Load result cache (keys are already strings from JSON)
    local cached = read_json_file(get_cache_path())
    if cached then
        result_cache = {}
        for k, v in pairs(cached) do
            -- Only load entries with numeric string keys (app IDs) to skip
            -- any JSON metadata or deserialization artifacts
            if tonumber(k) and type(v) == "table" and v.timestamp then
                result_cache[k] = v
            end
        end
        local count = 0
        for _ in pairs(result_cache) do count = count + 1 end
        logger:info("Loaded " .. count .. " result cache entries")
    end

    -- Load ID cache (keys are already strings from JSON)
    local id_data = read_json_file(get_id_cache_path())
    if id_data and type(id_data.mappings) == "table" and type(id_data.metadata) == "table" then
        id_cache = {
            mappings = id_data.mappings,
            metadata = id_data.metadata,
        }
        local count = 0
        for _ in pairs(id_cache.mappings) do count = count + 1 end
        logger:info("Loaded " .. count .. " ID cache mappings")
    end
end

return M
