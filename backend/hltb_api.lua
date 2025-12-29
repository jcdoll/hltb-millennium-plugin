--[[
    HLTB API Client

    Handles authenticated requests to HLTB's API.
    Provides search and game data fetching functionality.
]]

local http = require("http")
local json = require("json")
local logger = require("logger")
local endpoints = require("hltb_endpoint_discovery")

local M = {}

M.TOKEN_TTL = 300    -- Auth token cache duration in seconds
M.SEARCH_SIZE = 20   -- Number of results to request per search

-- Auth token cache
local cached_token = nil
local token_expires_at = 0

-- Get auth token
function M.get_auth_token(force_refresh)
    local now = os.time()

    if not force_refresh and cached_token and now < token_expires_at then
        return cached_token, nil
    end

    logger:info("Fetching auth token...")

    local timestamp_ms = math.floor(now * 1000)
    local url = endpoints.BASE_URL .. "api/search/init?t=" .. timestamp_ms

    local response, err = http.get(url, {
        headers = {
            ["User-Agent"] = endpoints.USER_AGENT,
            ["referer"] = endpoints.REFERER_HEADER
        },
        timeout = endpoints.TIMEOUT
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

    cached_token = data.token
    token_expires_at = now + M.TOKEN_TTL
    logger:info("Got auth token")

    return data.token, nil
end

-- Build search payload matching HLTB's expected API format.
-- The searchOptions structure mirrors what the HLTB website sends.
local function get_search_request_data(game_name, modifier, page)
    modifier = modifier or ""
    page = page or 1

    local search_terms = {}
    for word in game_name:gmatch("%S+") do
        table.insert(search_terms, word)
    end

    local payload = {
        searchType = "games",
        searchTerms = search_terms,
        searchPage = page,
        size = M.SEARCH_SIZE,
        searchOptions = {
            games = {
                userId = 0,
                platform = "",
                sortCategory = "popular",
                rangeCategory = "main",
                rangeTime = { min = 0, max = 0 },
                gameplay = {
                    perspective = "",
                    flow = "",
                    genre = "",
                    difficulty = ""
                },
                rangeYear = { max = "", min = "" },
                modifier = modifier
            },
            users = { sortCategory = "postcount" },
            lists = { sortCategory = "follows" },
            filter = "",
            sort = 0,
            randomizer = 0
        },
        useCache = true
    }

    return json.encode(payload)
end

-- Build search headers
local function get_search_request_headers(auth_token)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Origin"] = "https://howlongtobeat.com",
        ["Referer"] = "https://howlongtobeat.com/",
        ["Authority"] = "howlongtobeat.com",
        ["User-Agent"] = endpoints.USER_AGENT
    }

    if auth_token then
        headers["x-auth-token"] = auth_token
    end

    return headers
end

-- Search HLTB
function M.search(query, options)
    options = options or {}
    local page = options.page or 1
    local modifier = options.modifier or ""

    local auth_token = M.get_auth_token()
    if not auth_token then
        logger:info("Failed to get auth token")
        return nil
    end

    local headers = get_search_request_headers(auth_token)
    local search_url = endpoints.get_search_url()
    local payload = get_search_request_data(query, modifier, page)

    local response, err = http.request(search_url, {
        method = "POST",
        headers = headers,
        data = payload,
        timeout = endpoints.TIMEOUT
    })

    if not response then
        logger:info("Search request failed: " .. (err or "unknown"))
        return nil
    end

    if response.status ~= 200 then
        logger:info("Search returned HTTP " .. response.status)
        return nil
    end

    local success, data = pcall(json.decode, response.body)
    if not success or not data then
        logger:info("Invalid JSON response for search")
        return nil
    end

    if type(data.data) ~= "table" then
        logger:info("Unexpected JSON data for search results: data is not array")
        return nil
    end

    -- Validate each item has required fields
    for _, item in ipairs(data.data) do
        if type(item.game_id) ~= "number" then
            logger:info("Unexpected JSON data for search results: game_id is not number")
            return nil
        end
        if type(item.game_name) ~= "string" then
            logger:info("Unexpected JSON data for search results: game_name is not string")
            return nil
        end
        if type(item.comp_all_count) ~= "number" then
            logger:info("Unexpected JSON data for search results: comp_all_count is not number")
            return nil
        end
    end

    return data
end

-- Fetch game data by game ID (for Steam ID verification)
function M.fetch_game_data(game_id)
    local build_id = endpoints.get_build_id()
    if not build_id then
        return nil
    end

    local url = endpoints.BASE_URL .. "_next/data/" .. build_id .. "/game/" .. game_id .. ".json"
    logger:info("Fetching game data: " .. url)

    local headers = {
        ["User-Agent"] = endpoints.USER_AGENT,
        ["referer"] = endpoints.REFERER_HEADER
    }

    local response, err = http.get(url, {
        headers = headers,
        timeout = endpoints.TIMEOUT
    })

    if not response then
        logger:info("Game data request failed: " .. (err or "unknown"))
        return nil
    end

    if response.status ~= 200 then
        logger:info("Game data request returned HTTP " .. response.status)
        return nil
    end

    local success, data = pcall(json.decode, response.body)
    if not success or not data then
        logger:info("Invalid JSON response for game data")
        return nil
    end

    -- Validate structure: pageProps.game.data.game must be array
    if type(data.pageProps) ~= "table" then
        logger:info("Unexpected JSON data for game page: no pageProps")
        return nil
    end

    if type(data.pageProps.game) ~= "table" then
        logger:info("Unexpected JSON data for game page: no game")
        return nil
    end

    if type(data.pageProps.game.data) ~= "table" then
        logger:info("Unexpected JSON data for game page: no data")
        return nil
    end

    local game_array = data.pageProps.game.data.game
    if type(game_array) ~= "table" then
        logger:info("Unexpected JSON data for game page: game is not array")
        return nil
    end

    if #game_array ~= 1 then
        logger:info("Unexpected JSON data for game page: game array length is " .. #game_array)
        return nil
    end

    local game_data = game_array[1]

    -- Only validate profile_steam since that's all we use from this endpoint
    if type(game_data.profile_steam) ~= "number" then
        logger:info("Unexpected JSON data: profile_steam has wrong type")
        return nil
    end

    return game_data
end

-- Clear cached auth token
function M.clear_cache()
    cached_token = nil
    token_expires_at = 0
end

return M
