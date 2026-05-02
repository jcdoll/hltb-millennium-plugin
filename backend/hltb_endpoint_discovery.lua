--[[
    HLTB Endpoint Discovery

    Scrapes HLTB's NextJS website to find dynamic API endpoints.
    Handles homepage caching, search URL extraction, and build ID extraction.

    HLTB's API is undocumented and the search endpoint path has changed in the past
    (search -> finder -> find -> bleed -> ...). Dynamic detection lets the plugin
    follow rotations without code changes. There is no static fallback: if discovery
    fails, callers should treat it as an error and let the user retry.

    Callers in hltb_api.lua invoke M.invalidate() and retry once when a request
    fails, which lets us recover from a mid-session rotation without restarting Steam.
]]

local http = require("http")
local logger = require("logger")

local M = {}

M.BASE_URL = "https://howlongtobeat.com/"
M.REFERER_HEADER = M.BASE_URL
M.TIMEOUT = 60                        -- HTTP request timeout in seconds
M.USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

-- Known non-search API endpoints to skip
local SKIP_ENDPOINTS = {
    finder = true,
    error = true,
    user = true,
    logout = true
}

-- Cache
local cached_homepage = nil
local cached_search_url = nil
local cached_build_id = nil

-- Fetch and cache the HLTB homepage
local function get_homepage()
    if cached_homepage then
        return cached_homepage
    end

    logger:info("Fetching HLTB homepage...")

    local headers = {
        ["User-Agent"] = M.USER_AGENT,
        ["referer"] = M.REFERER_HEADER
    }

    local response, err = http.get(M.BASE_URL, {
        headers = headers,
        timeout = M.TIMEOUT
    })

    if not response or response.status ~= 200 then
        logger:info("Failed to fetch homepage")
        return nil
    end

    cached_homepage = response.body
    return cached_homepage
end

-- Extract search endpoint from website JavaScript
-- Searches all NextJS chunk scripts for fetch POST calls to /api/*
local function extract_search_url()
    logger:info("Extracting search endpoint from website...")

    local homepage = get_homepage()
    if not homepage then
        return nil
    end

    local headers = {
        ["User-Agent"] = M.USER_AGENT,
        ["referer"] = M.REFERER_HEADER
    }

    -- Find all chunk scripts: _next/static/chunks/*.js
    local script_urls = {}
    for src in homepage:gmatch('["\'](/_next/static/chunks/[^"\']+%.js)["\']') do
        table.insert(script_urls, src)
    end

    logger:info("Found " .. #script_urls .. " chunk script(s)")

    -- Check each script for POST fetch to /api/*
    local endpoints_found = {}
    for _, script_src in ipairs(script_urls) do
        local script_url = M.BASE_URL .. script_src:sub(2) -- remove leading /

        local script_resp = http.get(script_url, {
            headers = headers,
            timeout = M.TIMEOUT
        })

        if script_resp and script_resp.status == 200 and script_resp.body then
            local content = script_resp.body

            -- Look for API paths like "/api/xxx" and verify they're used with POST
            -- Pattern matches: fetch("/api/xxx", { ... method: "POST" ... })
            for api_path in content:gmatch('["\'](/api/[a-zA-Z0-9_]+)["\']') do
                local endpoint = api_path:match('/api/([a-zA-Z0-9_]+)')

                if endpoint and not endpoints_found[endpoint] then
                    endpoints_found[endpoint] = true

                    if SKIP_ENDPOINTS[endpoint] then
                        logger:info("Skipping endpoint: /api/" .. endpoint)
                    else
                        -- Verify it's used with POST method
                        local pattern = 'fetch%s*%(%s*["\']' .. api_path:gsub('/', '%%/') .. '["\']%s*,%s*{[^}]-method%s*:%s*["\']POST["\']'
                        if content:find(pattern) then
                            logger:info("Found search endpoint: /api/" .. endpoint)
                            return "api/" .. endpoint
                        else
                            logger:info("Endpoint /api/" .. endpoint .. " not used with POST")
                        end
                    end
                end
            end
        end
    end

    logger:info("No valid search endpoint found in " .. #script_urls .. " scripts")
    return nil
end

-- Get search URL by scraping HLTB's JS bundles.
-- Returns nil if discovery fails; callers should surface the error so
-- the user can retry rather than silently using a stale endpoint.
function M.get_search_url()
    if cached_search_url then
        return cached_search_url
    end

    local search_url = extract_search_url()
    if not search_url then
        logger:info("Endpoint discovery failed")
        return nil
    end

    cached_search_url = M.BASE_URL .. search_url
    logger:info("Search URL: " .. cached_search_url)
    return cached_search_url
end

-- Get auth token init URL, derived from the search URL.
--
-- Currently assumes the init endpoint is at {search_url}/init, which has
-- held true across endpoint rotations (api/search/init, api/finder/init,
-- api/find/init, api/bleed/init). If this assumption breaks, we should
-- discover the init URL dynamically from the JS bundles the same way we
-- discover the search URL.
function M.get_init_url()
    local search_url = M.get_search_url()
    if not search_url then return nil end
    return search_url .. "/init"
end

-- Extract NextJS build ID from homepage (for game data requests)
function M.get_build_id()
    if cached_build_id then
        return cached_build_id
    end

    logger:info("Extracting NextJS build ID...")

    local homepage = get_homepage()
    if not homepage then
        return nil
    end

    -- Look for /_next/static/{buildId}/_ssgManifest.js or _buildManifest.js
    local build_id = homepage:match('/_next/static/([^/]+)/_ssgManifest%.js')
    if not build_id then
        build_id = homepage:match('/_next/static/([^/]+)/_buildManifest%.js')
    end

    if build_id then
        logger:info("Found NextJS build ID: " .. build_id)
        cached_build_id = build_id
        return build_id
    end

    logger:info("Could not find NextJS build ID")
    return nil
end

-- Clear cached homepage, search URL, and build ID. Called by the API client
-- when a request fails so the next call re-scrapes HLTB and picks up any
-- endpoint rotation without requiring a Steam restart.
function M.invalidate()
    if cached_search_url or cached_build_id or cached_homepage then
        logger:info("Invalidating endpoint discovery cache")
    end
    cached_homepage = nil
    cached_search_url = nil
    cached_build_id = nil
end

return M
