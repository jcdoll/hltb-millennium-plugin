--[[
    HLTB Matching Logic

    Finds the best matching game from HLTB search results.
    Handles name comparison, Levenshtein distance, and retry with simplified names.
]]

local logger = require("logger")
local api = require("hltb_api")
local utils = require("hltb_utils")

local M = {}

M.RETRY_DISTANCE_RATIO = 0.2  -- Retry with simplified name if distance > 20% of name length
M.RETRY_DISTANCE_MIN = 5      -- Minimum distance threshold for retry
M.MAX_STEAM_ID_CHECKS = 3     -- Max candidates to check for Steam ID match

-- Determine if the match is poor enough to warrant retrying with a simplified name.
-- Uses a dynamic threshold: 20% of name length or minimum 5 edits, whichever is greater.
-- Longer names allow more edits before triggering retry (e.g., 30-char name allows 6 edits).
-- Note: These values are initial guesses and may need tuning based on real-world results.
local function should_retry_with_simplified(distance, name_length)
    local threshold = math.max(M.RETRY_DISTANCE_MIN, math.floor(name_length * M.RETRY_DISTANCE_RATIO))
    return distance > threshold
end

-- Search and find best match for a given query
-- Returns: best_item, best_distance (or nil, nil if no results)
local function find_best_match(query, steam_app_id)
    local search_results = api.search(query)
    if not search_results or #search_results.data == 0 then
        return nil, nil
    end

    logger:info("Found " .. #search_results.data .. " search results for: " .. query)

    local sanitized_query = utils.sanitize_game_name(query):lower()

    -- Check exact name match first
    for _, item in ipairs(search_results.data) do
        if utils.sanitize_game_name(item.game_name):lower() == sanitized_query then
            logger:info("Found exact name match: " .. item.game_name)
            return item, 0
        end
    end

    -- Find closest match using Levenshtein distance
    local possible_choices = {}
    for _, item in ipairs(search_results.data) do
        local sanitized_item_name = utils.sanitize_game_name(item.game_name):lower()
        local distance = utils.levenshtein_distance(sanitized_query, sanitized_item_name)
        table.insert(possible_choices, {
            distance = distance,
            comp_all_count = item.comp_all_count,
            item = item
        })
    end

    -- Sort by distance, then by comp_all_count descending
    table.sort(possible_choices, function(a, b)
        if a.distance == b.distance then
            return a.comp_all_count > b.comp_all_count
        end
        return a.distance < b.distance
    end)

    -- Try Steam ID match on top candidates
    if steam_app_id and #possible_choices > 0 then
        for i = 1, math.min(M.MAX_STEAM_ID_CHECKS, #possible_choices) do
            local candidate = possible_choices[i]
            local game_data = api.fetch_game_data(candidate.item.game_id)
            if game_data and game_data.profile_steam == steam_app_id then
                logger:info("Found match by Steam ID: " .. candidate.item.game_name)
                return candidate.item, 0
            end
        end
    end

    -- Return best Levenshtein match
    if #possible_choices > 0 then
        local best = possible_choices[1]
        return best.item, best.distance
    end

    return nil, nil
end

-- Find most compatible game data
function M.search_best_match(app_name, steam_app_id)
    logger:info("Searching HLTB for: " .. app_name)

    -- Try with original name first
    local best_item, best_distance = find_best_match(app_name, steam_app_id)

    -- Check if we should retry with simplified name
    local simplified_name = utils.simplify_game_name(app_name)
    local should_retry = simplified_name ~= app_name and (
        best_item == nil or
        should_retry_with_simplified(best_distance, #app_name)
    )

    if should_retry then
        logger:info("Retrying search with simplified name: " .. simplified_name)
        local retry_item, retry_distance = find_best_match(simplified_name, steam_app_id)

        -- Use retry result if it's better (or if original had no results)
        if retry_item and (best_item == nil or retry_distance < best_distance) then
            best_item = retry_item
            best_distance = retry_distance
        end
    end

    if best_item then
        logger:info("Best match: " .. best_item.game_name .. " (distance: " .. (best_distance or 0) .. ")")
        return best_item
    end

    logger:info("No match found for: " .. app_name)
    return nil
end

return M
