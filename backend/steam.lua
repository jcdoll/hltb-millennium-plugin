--[[
    Steam API Helpers for Lua

    Standalone module for Steam store API queries.
    Requires: http, json modules

    Usage:
        local steam = require("steam")
        local name, err = steam.get_game_name(1234)
        local clean_name = steam.sanitize_game_name(name)
]]

local http = require("http")
local json = require("json")

local M = {}

M.STORE_API_URL = "https://store.steampowered.com/api/appdetails"
M.TIMEOUT = 10

-- Get game details from Steam API
function M.get_app_details(app_id)
    local url = M.STORE_API_URL .. "?appids=" .. app_id

    local response, err = http.get(url, { timeout = M.TIMEOUT })

    if not response then
        return nil, "Request failed: " .. (err or "unknown")
    end

    if response.status ~= 200 then
        return nil, "HTTP " .. response.status
    end

    local success, data = pcall(json.decode, response.body)
    if not success or not data then
        return nil, "Invalid JSON response"
    end

    local app_data = data[tostring(app_id)]
    if not app_data or not app_data.success then
        return nil, "App not found"
    end

    return app_data.data, nil
end

-- Get just the game name
function M.get_game_name(app_id)
    local details, err = M.get_app_details(app_id)
    if not details then
        return nil, err
    end
    return details.name, nil
end

-- Sanitize game name for better search matching
function M.sanitize_game_name(name)
    -- Remove non-ASCII (trademark symbols, etc.)
    name = name:gsub("[^\x00-\x7F]", "")
    -- Remove common edition suffixes
    name = name:gsub("%s*[-:]%s*[Dd]efinitive%s+[Ee]dition", "")
    name = name:gsub("%s*[-:]%s*[Uu]ltimate%s+[Ee]dition", "")
    name = name:gsub("%s*[-:]%s*[Cc]omplete%s+[Ee]dition", "")
    name = name:gsub("%s*[-:]%s*GOTY%s*[Ee]?d?i?t?i?o?n?", "")
    name = name:gsub("%s*[-:]%s*[Gg]ame%s+of%s+the%s+[Yy]ear%s*[Ee]?d?i?t?i?o?n?", "")
    -- Clean up whitespace
    name = name:gsub("%s+", " ")
    name = name:match("^%s*(.-)%s*$") or name
    return name
end

return M
