--[[
    HLTB Endpoint Discovery Unit Tests

    Verifies manifest-first discovery, chunk fallback, multi-segment API paths,
    route-pair selection, and cache invalidation without network calls.

    Run with: busted tests/hltb_endpoint_discovery_spec.lua
]]

package.path = package.path .. ";backend/?.lua"

local BASE_URL = "https://howlongtobeat.com/"

local function load_discovery(responses)
    local requests = {}

    package.loaded["http"] = {
        get = function(url, opts)
            table.insert(requests, { url = url, opts = opts })

            local mock = responses[url]
            if not mock then
                return nil, "No mock for URL: " .. url
            end
            if mock.error then
                return nil, mock.error
            end

            return {
                status = mock.status or 200,
                body = mock.body
            }
        end
    }
    package.loaded["logger"] = {
        info = function() end,
        error = function() end
    }
    package.loaded["hltb_endpoint_discovery"] = nil

    return require("hltb_endpoint_discovery"), requests
end

describe("hltb_endpoint_discovery", function()
    it("discovers a multi-segment search path from the build manifest", function()
        local homepage = [[
            <script src="/_next/static/chunks/search.js"></script>
            <script src="/_next/static/build-123/_buildManifest.js"></script>
        ]]
        local manifest = [[
            self.__BUILD_MANIFEST={sortedPages:[
                "/api/error",
                "/api/search/site/init",
                "/api/search/site"
            ]};
        ]]
        local discovery, requests = load_discovery({
            [BASE_URL] = { body = homepage },
            [BASE_URL .. "_next/static/build-123/_buildManifest.js"] = { body = manifest }
        })

        assert.equals(BASE_URL .. "api/search/site", discovery.get_search_url())
        assert.equals(BASE_URL .. "api/search/site/init", discovery.get_init_url())
        assert.equals(2, #requests)
        assert.equals(BASE_URL .. "_next/static/build-123/_buildManifest.js", requests[2].url)
        assert.equals(discovery.USER_AGENT, requests[1].opts.headers["User-Agent"])
        assert.equals(discovery.REFERER_HEADER, requests[1].opts.headers["referer"])
    end)

    it("continues to support legacy single-segment search paths", function()
        local homepage = [[<script src="/_next/static/old/_buildManifest.js"></script>]]
        local manifest = [["/api/bleed/init","/api/bleed"]]
        local discovery = load_discovery({
            [BASE_URL] = { body = homepage },
            [BASE_URL .. "_next/static/old/_buildManifest.js"] = { body = manifest }
        })

        assert.equals(BASE_URL .. "api/bleed", discovery.get_search_url())
    end)

    it("selects deterministically when more than one route pair is present", function()
        local homepage = [[<script src="/_next/static/current/_buildManifest.js"></script>]]
        local manifest = [[
            "/api/zeta/init","/api/zeta",
            "/api/alpha/search/init","/api/alpha/search"
        ]]
        local discovery = load_discovery({
            [BASE_URL] = { body = homepage },
            [BASE_URL .. "_next/static/current/_buildManifest.js"] = { body = manifest }
        })

        assert.equals(BASE_URL .. "api/alpha/search", discovery.get_search_url())
    end)

    it("falls back to API path pairs accumulated across chunk scripts", function()
        local homepage = [[
            <script src="/_next/static/chunks/b.js"></script>
            <script src="/_next/static/chunks/a.js"></script>
            <script src="/_next/static/missing/_buildManifest.js"></script>
        ]]
        local first_chunk = [[
            fetch("/api/game/",{method:"POST"});
            fetch("/api/search/site",{method:"POST"});
        ]]
        local second_chunk = [[
            fetch(`/api/search/site/init?t=${Date.now()}`);
            fetch("/api/error",{method:"POST"});
        ]]
        local discovery = load_discovery({
            [BASE_URL] = { body = homepage },
            [BASE_URL .. "_next/static/missing/_buildManifest.js"] = {
                body = [["/api/error","/api/user"]]
            },
            [BASE_URL .. "_next/static/chunks/a.js"] = { body = first_chunk },
            [BASE_URL .. "_next/static/chunks/b.js"] = { body = second_chunk }
        })

        assert.equals(BASE_URL .. "api/search/site", discovery.get_search_url())
    end)

    it("ignores unrelated and unpaired API paths", function()
        local homepage = [[<script src="/_next/static/chunks/app.js"></script>]]
        local chunk = [[
            fetch("/api/game/",{method:"POST"});
            fetch("/api/error",{method:"POST"});
            fetch("/api/search/site",{method:"POST"});
        ]]
        local discovery = load_discovery({
            [BASE_URL] = { body = homepage },
            [BASE_URL .. "_next/static/chunks/app.js"] = { body = chunk }
        })

        assert.is_nil(discovery.get_search_url())
    end)

    it("caches discovery until invalidated", function()
        local homepage = [[<script src="/_next/static/current/_buildManifest.js"></script>]]
        local manifest = [["/api/search/site","/api/search/site/init"]]
        local discovery, requests = load_discovery({
            [BASE_URL] = { body = homepage },
            [BASE_URL .. "_next/static/current/_buildManifest.js"] = { body = manifest }
        })

        assert.equals(BASE_URL .. "api/search/site", discovery.get_search_url())
        assert.equals(BASE_URL .. "api/search/site", discovery.get_search_url())
        assert.equals(2, #requests)

        discovery.invalidate()

        assert.equals(BASE_URL .. "api/search/site", discovery.get_search_url())
        assert.equals(4, #requests)
    end)

    it("keeps build ID discovery compatible with the cached homepage", function()
        local homepage = [[
            <script src="/_next/static/build-456/_buildManifest.js"></script>
            <script src="/_next/static/build-456/_ssgManifest.js"></script>
        ]]
        local discovery, requests = load_discovery({
            [BASE_URL] = { body = homepage }
        })

        assert.equals("build-456", discovery.get_build_id())
        assert.equals("build-456", discovery.get_build_id())
        assert.equals(1, #requests)
    end)
end)
