--[[
    HLTB Endpoint Discovery

    Scrapes HLTB's NextJS website to find dynamic API endpoints.
    Handles homepage caching, search URL extraction, and build ID extraction.

    HLTB's API is undocumented and the search endpoint path has changed in the past
    (search -> finder -> find -> bleed -> search/site -> ...). Dynamic detection lets
    the plugin follow rotations without code changes. There is no static fallback: if
    discovery fails, callers should treat it as an error and let the user retry.

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

-- Cache
local cached_homepage = nil
local cached_search_url = nil
local cached_build_id = nil

local function request_headers()
    return {
        ["User-Agent"] = M.USER_AGENT,
        ["referer"] = M.REFERER_HEADER
    }
end

-- Fetch and cache the HLTB homepage
local function get_homepage()
    if cached_homepage then
        return cached_homepage
    end

    logger:info("Fetching HLTB homepage...")

    local response, err = http.get(M.BASE_URL, {
        headers = request_headers(),
        timeout = M.TIMEOUT
    })

    if not response or response.status ~= 200 then
        logger:info("Failed to fetch homepage")
        return nil
    end

    cached_homepage = response.body
    return cached_homepage
end

-- Collect quoted API path literals from a manifest or JavaScript bundle.
--
-- Do not require a closing quote: HLTB writes the init URL as a template literal
-- followed by a cache-busting query. Paths may contain multiple segments, as in
-- the current "search/site" endpoint.
local function collect_api_paths(content, paths)
    paths = paths or {}

    for api_path in content:gmatch('["\'`](/api/[a-zA-Z0-9_/%-]+)') do
        paths[api_path] = true
    end

    return paths
end

-- The search endpoint is the API path that has a matching /init handshake route.
-- This pair is a stronger signal than looking for the first POST request because
-- HLTB bundles contain unrelated game, error, and user API calls.
local function find_search_path(paths)
    local candidates = {}

    for api_path in pairs(paths) do
        if api_path:sub(-5) ~= "/init" and paths[api_path .. "/init"] then
            table.insert(candidates, api_path)
        end
    end

    table.sort(candidates)
    return candidates[1]
end

local function fetch_script(script_src)
    local script_url = M.BASE_URL .. script_src:sub(2) -- remove leading /
    return http.get(script_url, {
        headers = request_headers(),
        timeout = M.TIMEOUT
    })
end

-- Extract the search path from HLTB's NextJS build manifest when available.
-- The manifest enumerates API routes directly, avoiding a scan of every chunk.
local function extract_search_path_from_manifest(homepage)
    local manifest_src = homepage:match('["\'](/_next/static/[^"\']+/_buildManifest%.js)["\']')
    if not manifest_src then
        logger:info("No NextJS build manifest found on homepage")
        return nil
    end

    local manifest_resp = fetch_script(manifest_src)
    if not manifest_resp or manifest_resp.status ~= 200 or not manifest_resp.body then
        logger:info("Failed to fetch NextJS build manifest")
        return nil
    end

    local search_path = find_search_path(collect_api_paths(manifest_resp.body))
    if search_path then
        logger:info("Found search endpoint in build manifest: " .. search_path)
        return search_path
    end

    logger:info("No search endpoint pair found in build manifest")
    return nil
end

-- Fallback discovery for sites whose build manifest does not enumerate API routes.
-- Accumulates paths across all chunks before looking for the base + /init pair.
local function extract_search_path_from_chunks(homepage)
    local script_urls = {}
    local seen_scripts = {}
    for src in homepage:gmatch('["\'](/_next/static/chunks/[^"\']+%.js)["\']') do
        if not seen_scripts[src] then
            seen_scripts[src] = true
            table.insert(script_urls, src)
        end
    end
    table.sort(script_urls)

    logger:info("Found " .. #script_urls .. " chunk script(s)")

    local api_paths = {}
    for _, script_src in ipairs(script_urls) do
        local script_resp = fetch_script(script_src)
        if script_resp and script_resp.status == 200 and script_resp.body then
            collect_api_paths(script_resp.body, api_paths)
        end
    end

    local search_path = find_search_path(api_paths)
    if search_path then
        logger:info("Found search endpoint in chunk scripts: " .. search_path)
        return search_path
    end

    logger:info("No valid search endpoint found in " .. #script_urls .. " scripts")
    return nil
end

-- Extract the current search path from the build manifest, falling back to chunks.
local function extract_search_path()
    logger:info("Extracting search endpoint from website...")

    local homepage = get_homepage()
    if not homepage then
        return nil
    end

    return extract_search_path_from_manifest(homepage)
        or extract_search_path_from_chunks(homepage)
end

-- Get the search URL from HLTB's build manifest or JavaScript bundles.
-- Returns nil if discovery fails; callers should surface the error so
-- the user can retry rather than silently using a stale endpoint.
function M.get_search_url()
    if cached_search_url then
        return cached_search_url
    end

    local search_path = extract_search_path()
    if not search_path then
        logger:info("Endpoint discovery failed")
        return nil
    end

    cached_search_url = M.BASE_URL .. search_path:sub(2)
    logger:info("Search URL: " .. cached_search_url)
    return cached_search_url
end

-- Get auth token init URL, derived from the search URL.
--
-- Discovery already verifies the corresponding {search_url}/init route exists.
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
