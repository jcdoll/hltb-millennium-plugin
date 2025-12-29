--[[
    HLTB Endpoint Discovery

    Scrapes HLTB's NextJS website to find dynamic API endpoints.
    Handles homepage caching, search URL extraction, and build ID extraction.

    HLTB's API is undocumented and the search endpoint path has changed in the past.
    Dynamic endpoint detection (used by other HLTB client projects) allows the plugin
    to adapt to API changes without code updates. Falls back to "api/search" if
    discovery fails.
]]

local http = require("http")
local logger = require("logger")

local M = {}

M.BASE_URL = "https://howlongtobeat.com/"
M.REFERER_HEADER = M.BASE_URL
M.TIMEOUT = 60                        -- HTTP request timeout in seconds
M.USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
M.SEARCH_URL_FALLBACK = M.BASE_URL .. "api/search"  -- Used when dynamic endpoint discovery fails

-- Known non-search API endpoints to skip
local SKIP_ENDPOINTS = {
    find = true,
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

-- Get search URL with fallback logic
function M.get_search_url()
    if cached_search_url then
        return cached_search_url
    end

    local search_url = extract_search_url()

    if search_url then
        cached_search_url = M.BASE_URL .. search_url
        logger:info("Search URL: " .. cached_search_url)
    else
        cached_search_url = M.SEARCH_URL_FALLBACK
        logger:info("Using fallback search URL: " .. cached_search_url)
    end

    return cached_search_url
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

-- Clear cached homepage, search URL, and build ID
function M.clear_cache()
    cached_homepage = nil
    cached_search_url = nil
    cached_build_id = nil
end

return M
