--[[
    HLTB API Client for Lua

    Standalone module for querying HowLongToBeat.com
    Requires: http, json modules

    Usage:
        local hltb = require("hltb")
        local results, err = hltb.search("Dark Souls")
        if results then
            print(results[1].game_name, results[1].comp_main)
        end
]]

local http = require("http")
local json = require("json")

local M = {}

M.BASE_URL = "https://howlongtobeat.com/"
M.TIMEOUT = 10

-- Get fresh auth token from HLTB
function M.get_auth_token()
    local timestamp_ms = os.time() * 1000
    local url = M.BASE_URL .. "api/search/init?t=" .. timestamp_ms

    local response, err = http.get(url, {
        headers = {
            ["Referer"] = M.BASE_URL
        },
        timeout = M.TIMEOUT
    })

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

    if not data.token then
        return nil, "No token in response"
    end

    return data.token, nil
end

-- Search HLTB for games matching the query
-- Returns array of results or nil, error
function M.search(query, options)
    options = options or {}
    local page = options.page or 1
    local size = options.size or 20

    -- Get fresh auth token
    local token, token_err = M.get_auth_token()
    if not token then
        return nil, "Auth failed: " .. (token_err or "unknown")
    end

    -- Split query into search terms
    local search_terms = {}
    for word in query:gmatch("%S+") do
        table.insert(search_terms, word)
    end

    local payload = json.encode({
        searchType = "games",
        searchTerms = search_terms,
        searchPage = page,
        size = size,
        searchOptions = {
            games = {
                userId = 0,
                platform = "",
                sortCategory = "popular",
                rangeCategory = "main",
                modifier = ""
            },
            filter = "",
            sort = 0,
            randomizer = 0
        },
        useCache = true
    })

    local response, err = http.request(M.BASE_URL .. "api/search", {
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Referer"] = M.BASE_URL,
            ["x-auth-token"] = token
        },
        data = payload,
        timeout = M.TIMEOUT
    })

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

    if not data.data then
        return {}, nil -- Empty results
    end

    return data.data, nil
end

-- Search and return best match only
-- Returns single result or nil, error
function M.search_best_match(query, options)
    local results, err = M.search(query, options)
    if not results then
        return nil, err
    end
    if #results == 0 then
        return nil, "No results found"
    end
    return results[1], nil
end

return M
