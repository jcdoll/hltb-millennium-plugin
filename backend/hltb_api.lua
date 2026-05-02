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

-- Exposed for testing; defaults to real http module
M._http = http

-- Auth struct cache: { token, key, value }
local cached_auth = nil
local auth_expires_at = 0

-- Single attempt at fetching the auth token. Used by get_auth, which retries
-- once with an invalidated endpoint cache if the first attempt fails.
local function fetch_auth_once()
    local init_url = endpoints.get_init_url()
    if not init_url then
        return nil, "endpoint discovery failed"
    end

    local timestamp_ms = math.floor(os.time() * 1000)
    local url = init_url .. "?t=" .. timestamp_ms
    logger:info("Fetching auth token...")

    local response, err = M._http.get(url, {
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

    return {
        token = data.token,
        key = data.hpKey,
        value = data.hpVal
    }, nil
end

-- Get auth struct (token + key/value pair).
-- On the first failure we invalidate the endpoint discovery cache and retry
-- once, in case HLTB rotated the API endpoint name mid-session.
function M.get_auth(force_refresh)
    local now = os.time()

    if not force_refresh and cached_auth and now < auth_expires_at then
        return cached_auth, nil
    end

    local auth, err = fetch_auth_once()
    if not auth then
        logger:info("Auth fetch failed (" .. err .. "), re-detecting endpoint and retrying")
        endpoints.invalidate()
        auth, err = fetch_auth_once()
        if not auth then
            return nil, err
        end
    end

    cached_auth = auth
    auth_expires_at = now + M.TOKEN_TTL
    logger:info("Got auth token" .. (auth.key and " with key/value" or ""))

    return cached_auth, nil
end

-- Build search payload matching HLTB's expected API format.
-- The searchOptions structure mirrors what the HLTB website sends.
local function get_search_request_data(game_name, modifier, page, auth)
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

    -- Include auth key/value in the payload body
    if auth and auth.key and auth.value then
        payload[tostring(auth.key)] = auth.value
    end

    return json.encode(payload)
end

-- Build search headers
local function get_search_request_headers(auth)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Origin"] = "https://howlongtobeat.com",
        ["Referer"] = "https://howlongtobeat.com/",
        ["Authority"] = "howlongtobeat.com",
        ["User-Agent"] = endpoints.USER_AGENT
    }

    if auth then
        headers["x-auth-token"] = auth.token
        if auth.key then
            headers["x-hp-key"] = tostring(auth.key)
        end
        if auth.value then
            headers["x-hp-val"] = tostring(auth.value)
        end
    end

    return headers
end

-- Single attempt at a search request. Returns response, err.
local function search_once(query, options)
    local auth, auth_err = M.get_auth()
    if not auth then
        return nil, "auth: " .. (auth_err or "unknown")
    end

    local search_url = endpoints.get_search_url()
    if not search_url then
        return nil, "endpoint discovery failed"
    end

    local headers = get_search_request_headers(auth)
    local payload = get_search_request_data(query, options.modifier or "", options.page or 1, auth)

    return M._http.request(search_url, {
        method = "POST",
        headers = headers,
        data = payload,
        timeout = endpoints.TIMEOUT
    })
end

-- Search HLTB.
-- Failure handling has two retry triggers:
--   1) HTTP 403 -> token expired server-side, refresh auth and retry once.
--   2) Any other failure (transport error, non-200) -> assume HLTB rotated
--      the endpoint, invalidate discovery, and retry once.
function M.search(query, options)
    options = options or {}

    local response, err = search_once(query, options)

    if response and response.status == 403 then
        logger:info("Search returned 403, refreshing auth and retrying")
        M.clear_cache()
        response, err = search_once(query, options)
    elseif (not response) or response.status ~= 200 then
        local desc = response and ("HTTP " .. response.status) or (err or "unknown")
        logger:info("Search failed (" .. desc .. "), re-detecting endpoint and retrying")
        endpoints.invalidate()
        M.clear_cache()
        response, err = search_once(query, options)
    end

    if not response then
        logger:info("Search retry failed: " .. (err or "unknown"))
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

-- Fetch game data by game ID (for Steam ID verification).
-- Same retry-on-failure semantics as fetch_game_by_id: invalidate the
-- discovery cache (which holds the build ID) and retry once.
local function fetch_game_data_once(game_id)
    local build_id = endpoints.get_build_id()
    if not build_id then
        return nil, "no build_id"
    end

    local url = endpoints.BASE_URL .. "_next/data/" .. build_id .. "/game/" .. game_id .. ".json"
    logger:info("Fetching game data: " .. url)

    return M._http.get(url, {
        headers = {
            ["User-Agent"] = endpoints.USER_AGENT,
            ["referer"] = endpoints.REFERER_HEADER
        },
        timeout = endpoints.TIMEOUT
    })
end

function M.fetch_game_data(game_id)
    local response, err = fetch_game_data_once(game_id)
    if (not response) or response.status ~= 200 then
        local desc = response and ("HTTP " .. response.status) or (err or "unknown")
        logger:info("Game data fetch failed (" .. desc .. "), re-detecting build ID and retrying")
        endpoints.invalidate()
        response, err = fetch_game_data_once(game_id)
    end

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

-- Fetch Steam import data from HLTB's Steam integration API.
--
-- HLTB provides an endpoint that returns all games in a user's Steam library
-- along with their corresponding HLTB game IDs. This gives us a reliable
-- mapping without needing to do fuzzy name matching.
--
-- Requires the user's Steam profile to be public. Returns nil if the profile
-- is private or the request fails.
--
-- API endpoint: POST https://howlongtobeat.com/api/steam/getSteamImportData
-- Returns: Array of game objects with steam_id, hltb_id, and other metadata.
function M.fetch_steam_import(steam_user_id)
    if not steam_user_id or steam_user_id == "" then
        return nil, "No Steam user ID provided"
    end

    logger:info("Fetching Steam import for user: " .. steam_user_id)

    local url = endpoints.BASE_URL .. "api/steam/getSteamImportData"

    local payload = json.encode({
        steamUserId = steam_user_id,
        steamOmitData = 0
    })

    local headers = {
        ["Content-Type"] = "application/json",
        ["User-Agent"] = endpoints.USER_AGENT,
        ["Referer"] = endpoints.REFERER_HEADER
    }

    local response, err = M._http.request(url, {
        method = "POST",
        headers = headers,
        data = payload,
        timeout = endpoints.TIMEOUT
    })

    if not response then
        return nil, "Request failed: " .. (err or "unknown")
    end

    if response.status ~= 200 then
        return nil, "HTTP " .. response.status
    end

    local success, data = pcall(json.decode, response.body)
    if not success or type(data) ~= "table" then
        return nil, "Invalid JSON response"
    end

    if data.error then
        return nil, "HLTB API error: " .. data.error .. " (profile may be private)"
    end

    if type(data.games) ~= "table" then
        return nil, "No games in response (profile may be private)"
    end

    logger:info("Steam import returned " .. #data.games .. " games")
    return data.games, nil
end

-- Single attempt at fetching game data by HLTB ID.
local function fetch_game_by_id_once(game_id)
    local build_id = endpoints.get_build_id()
    if not build_id then
        return nil, "Could not get build ID"
    end

    local url = endpoints.BASE_URL .. "_next/data/" .. build_id .. "/game/" .. game_id .. ".json"

    return M._http.get(url, {
        headers = {
            ["User-Agent"] = endpoints.USER_AGENT,
            ["referer"] = endpoints.REFERER_HEADER
        },
        timeout = endpoints.TIMEOUT
    })
end

-- Fetch game completion times directly by HLTB game ID.
--
-- Uses HLTB's NextJS data endpoint to get full game details including
-- completion times (main, main+extras, completionist).
--
-- This is faster and more reliable than name-based search when we already
-- know the HLTB game ID (e.g., from the Steam import cache).
--
-- API endpoint: GET https://howlongtobeat.com/_next/data/{buildId}/game/{gameId}.json
-- Returns: Normalized game data with game_id, game_name, comp_main, comp_plus, comp_100.
--
-- On failure we invalidate the endpoint discovery cache (which includes the
-- NextJS build ID) and retry once, since HLTB rotates the build ID on each
-- deploy.
function M.fetch_game_by_id(game_id)
    if not game_id then
        return nil, "No game ID provided"
    end

    logger:info("Fetching game data for HLTB ID: " .. tostring(game_id))

    local response, err = fetch_game_by_id_once(game_id)
    if (not response) or response.status ~= 200 then
        local desc = response and ("HTTP " .. response.status) or (err or "unknown")
        logger:info("Game data fetch failed (" .. desc .. "), re-detecting build ID and retrying")
        endpoints.invalidate()
        response, err = fetch_game_by_id_once(game_id)
    end

    if not response then
        return nil, "Request failed: " .. (err or "unknown")
    end

    if response.status ~= 200 then
        return nil, "HTTP " .. response.status
    end

    local success, data = pcall(json.decode, response.body)
    if not success or type(data) ~= "table" then
        return nil, "Invalid JSON response"
    end

    -- Navigate to the game data
    if type(data.pageProps) ~= "table" or
       type(data.pageProps.game) ~= "table" or
       type(data.pageProps.game.data) ~= "table" then
        return nil, "Unexpected response structure"
    end

    local game_array = data.pageProps.game.data.game
    if type(game_array) ~= "table" or #game_array == 0 then
        return nil, "No game data found"
    end

    local game = game_array[1]

    -- Return normalized game data matching search result format
    return {
        game_id = game.game_id,
        game_name = game.game_name,
        comp_main = game.comp_main,
        comp_plus = game.comp_plus,
        comp_100 = game.comp_100
    }, nil
end

-- Clear cached auth
function M.clear_cache()
    cached_auth = nil
    auth_expires_at = 0
end

return M
