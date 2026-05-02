--[[
    HLTB API Client for Lua

    Standalone module for querying HowLongToBeat.com

    Usage:
        local hltb = require("hltb")
        local game_data = hltb.search_best_match("Dark Souls", steam_app_id)
        if game_data then
            print(game_data.game_name, game_data.comp_main)
        end
]]

local endpoints = require("hltb_endpoint_discovery")
local api = require("hltb_api")
local match = require("hltb_match")

local M = {}

-- Re-export public API
M.search = api.search
M.search_best_match = match.search_best_match
M.get_auth = api.get_auth
M.fetch_steam_import = api.fetch_steam_import
M.fetch_game_by_id = api.fetch_game_by_id

-- Clear all cached values
function M.clear_cache()
    endpoints.invalidate()
    api.clear_cache()
end

return M
