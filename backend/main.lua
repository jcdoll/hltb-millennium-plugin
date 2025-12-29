--[[
    HLTB for Millennium - Plugin Entry Point

    Displays How Long To Beat completion times on Steam game pages.
]]

local logger = require("logger")
local millennium = require("millennium")
local json = require("json")
local hltb = require("hltb")
local steam = require("steam")

-- Convert hours to seconds
local function hours_to_seconds(hours)
    if not hours or hours == 0 then
        return 0
    end
    return math.floor(hours * 3600)
end

-- Main function called by frontend
function GetHltbData(app_id)
    logger:info("GetHltbData called for app_id: " .. tostring(app_id))

    -- Get game name from Steam
    local game_name, name_err = steam.get_game_name(app_id)
    if not game_name then
        logger:error("Could not get game name: " .. (name_err or "unknown"))
        return json.encode({ success = false, error = "Could not get game name" })
    end

    logger:info("Got game name: " .. game_name)

    -- Sanitize for better search matching
    local search_name = steam.sanitize_game_name(game_name)
    if search_name ~= game_name then
        logger:info("Sanitized to: " .. search_name)
    end

    -- Search HLTB
    local match, search_err = hltb.search_best_match(search_name)
    if not match then
        logger:info("No HLTB results: " .. (search_err or "unknown"))
        return json.encode({ success = false, error = "No HLTB results" })
    end

    logger:info("Found match: " .. (match.game_name or "unknown"))

    return json.encode({
        success = true,
        data = {
            game_id = match.game_id,
            game_name = match.game_name,
            comp_main = hours_to_seconds(match.comp_main),
            comp_plus = hours_to_seconds(match.comp_plus),
            comp_100 = hours_to_seconds(match.comp_100),
            comp_all = hours_to_seconds(match.comp_all)
        }
    })
end

-- Plugin lifecycle
local function on_load()
    logger:info("HLTB plugin loaded, Millennium " .. millennium.version())
    millennium.ready()
end

local function on_frontend_loaded()
    logger:info("HLTB: Frontend loaded")
end

local function on_unload()
    logger:info("HLTB plugin unloaded")
end

return {
    on_load = on_load,
    on_frontend_loaded = on_frontend_loaded,
    on_unload = on_unload,
    GetHltbData = GetHltbData
}
