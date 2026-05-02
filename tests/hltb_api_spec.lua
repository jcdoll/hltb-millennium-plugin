--[[
    HLTB API Unit Tests

    Tests for Steam import and direct game fetch functionality.
    Uses mock HTTP module to test without network calls.

    Run with: busted tests/hltb_api_spec.lua
]]

package.path = package.path .. ";backend/?.lua"

local json = require("dkjson")

-- Mock dependencies before requiring hltb_api
package.loaded["json"] = json
package.loaded["http"] = {
    get = function() return nil, "No mock configured" end,
    request = function() return nil, "No mock configured" end
}
package.loaded["logger"] = {
    info = function() end,
    error = function() end
}
package.loaded["hltb_endpoint_discovery"] = {
    BASE_URL = "https://howlongtobeat.com/",
    USER_AGENT = "Mozilla/5.0 Test",
    REFERER_HEADER = "https://howlongtobeat.com/",
    TIMEOUT = 10,
    get_build_id = function() return "test-build-id" end,
    get_init_url = function() return "https://howlongtobeat.com/api/test/init" end,
    get_search_url = function() return "https://howlongtobeat.com/api/test" end,
    invalidate = function() end,
}

-- Mock HTTP factory for GET requests
local function create_mock_http_get(responses)
    return {
        get = function(url, opts)
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
        end,
        request = function() return nil, "No mock configured" end
    }
end

-- Mock HTTP factory for POST requests
local function create_mock_http_post(responses)
    return {
        get = function() return nil, "No mock configured" end,
        request = function(url, opts)
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
end

describe("hltb_api", function()
    local api

    before_each(function()
        package.loaded["hltb_api"] = nil
        api = require("hltb_api")
    end)

    describe("fetch_steam_import", function()
        it("returns nil for empty steam_user_id", function()
            local games, err = api.fetch_steam_import("")
            assert.is_nil(games)
            assert.equals("No Steam user ID provided", err)
        end)

        it("returns nil for nil steam_user_id", function()
            local games, err = api.fetch_steam_import(nil)
            assert.is_nil(games)
            assert.equals("No Steam user ID provided", err)
        end)

        it("returns games array on success", function()
            local mock_response = {
                games = {
                    { steam_id = 123, hltb_id = 456, steam_name = "Test Game" },
                    { steam_id = 789, hltb_id = 101, steam_name = "Another Game" }
                }
            }
            api._http = create_mock_http_post({
                ["https://howlongtobeat.com/api/steam/getSteamImportData"] = {
                    status = 200,
                    body = json.encode(mock_response)
                }
            })

            local games, err = api.fetch_steam_import("testuser")
            assert.is_nil(err)
            assert.equals(2, #games)
            assert.equals(123, games[1].steam_id)
            assert.equals(456, games[1].hltb_id)
        end)

        it("returns error when API returns null (private profile)", function()
            api._http = create_mock_http_post({
                ["https://howlongtobeat.com/api/steam/getSteamImportData"] = {
                    status = 200,
                    body = "null"
                }
            })

            local games, err = api.fetch_steam_import("privateuser")
            assert.is_nil(games)
            assert.equals("Invalid JSON response", err)
        end)

        it("returns error when games array is missing", function()
            api._http = create_mock_http_post({
                ["https://howlongtobeat.com/api/steam/getSteamImportData"] = {
                    status = 200,
                    body = json.encode({ someOtherField = true })
                }
            })

            local games, err = api.fetch_steam_import("testuser")
            assert.is_nil(games)
            assert.equals("No games in response (profile may be private)", err)
        end)

        it("returns error on HTTP failure", function()
            api._http = create_mock_http_post({
                ["https://howlongtobeat.com/api/steam/getSteamImportData"] = {
                    error = "Connection refused"
                }
            })

            local games, err = api.fetch_steam_import("testuser")
            assert.is_nil(games)
            assert.matches("Request failed", err)
        end)

        it("returns error on non-200 status", function()
            api._http = create_mock_http_post({
                ["https://howlongtobeat.com/api/steam/getSteamImportData"] = {
                    status = 500,
                    body = ""
                }
            })

            local games, err = api.fetch_steam_import("testuser")
            assert.is_nil(games)
            assert.equals("HTTP 500", err)
        end)

        it("returns API error message when present", function()
            api._http = create_mock_http_post({
                ["https://howlongtobeat.com/api/steam/getSteamImportData"] = {
                    status = 200,
                    body = json.encode({ error = "Rate limited" })
                }
            })

            local games, err = api.fetch_steam_import("testuser")
            assert.is_nil(games)
            assert.equals("HLTB API error: Rate limited (profile may be private)", err)
        end)
    end)

    describe("fetch_game_by_id", function()
        it("returns nil for nil game_id", function()
            local game, err = api.fetch_game_by_id(nil)
            assert.is_nil(game)
            assert.equals("No game ID provided", err)
        end)

        it("returns game data on success", function()
            local mock_response = {
                pageProps = {
                    game = {
                        data = {
                            game = {
                                {
                                    game_id = 12345,
                                    game_name = "Test Game",
                                    comp_main = 3600,
                                    comp_plus = 7200,
                                    comp_100 = 14400
                                }
                            }
                        }
                    }
                }
            }
            api._http = create_mock_http_get({
                ["https://howlongtobeat.com/_next/data/test-build-id/game/12345.json"] = {
                    status = 200,
                    body = json.encode(mock_response)
                }
            })

            local game, err = api.fetch_game_by_id(12345)
            assert.is_nil(err)
            assert.equals(12345, game.game_id)
            assert.equals("Test Game", game.game_name)
            assert.equals(3600, game.comp_main)
        end)

        it("returns error when API returns null", function()
            api._http = create_mock_http_get({
                ["https://howlongtobeat.com/_next/data/test-build-id/game/99999.json"] = {
                    status = 200,
                    body = "null"
                }
            })

            local game, err = api.fetch_game_by_id(99999)
            assert.is_nil(game)
            assert.equals("Invalid JSON response", err)
        end)

        it("returns error on unexpected response structure", function()
            api._http = create_mock_http_get({
                ["https://howlongtobeat.com/_next/data/test-build-id/game/12345.json"] = {
                    status = 200,
                    body = json.encode({ someOtherField = true })
                }
            })

            local game, err = api.fetch_game_by_id(12345)
            assert.is_nil(game)
            assert.equals("Unexpected response structure", err)
        end)

        it("returns error when game array is empty", function()
            local mock_response = {
                pageProps = {
                    game = {
                        data = {
                            game = {}
                        }
                    }
                }
            }
            api._http = create_mock_http_get({
                ["https://howlongtobeat.com/_next/data/test-build-id/game/12345.json"] = {
                    status = 200,
                    body = json.encode(mock_response)
                }
            })

            local game, err = api.fetch_game_by_id(12345)
            assert.is_nil(game)
            assert.equals("No game data found", err)
        end)

        it("returns error on HTTP failure", function()
            api._http = create_mock_http_get({
                ["https://howlongtobeat.com/_next/data/test-build-id/game/12345.json"] = {
                    error = "Timeout"
                }
            })

            local game, err = api.fetch_game_by_id(12345)
            assert.is_nil(game)
            assert.matches("Request failed", err)
        end)

        it("returns error on non-200 status", function()
            api._http = create_mock_http_get({
                ["https://howlongtobeat.com/_next/data/test-build-id/game/12345.json"] = {
                    status = 404,
                    body = ""
                }
            })

            local game, err = api.fetch_game_by_id(12345)
            assert.is_nil(game)
            assert.equals("HTTP 404", err)
        end)

        it("invalidates discovery and retries once on HTTP failure", function()
            local invalidate_called = 0
            local build_ids = { "stale-build-id", "fresh-build-id" }
            local build_idx = 0
            package.loaded["hltb_endpoint_discovery"] = {
                BASE_URL = "https://howlongtobeat.com/",
                USER_AGENT = "Mozilla/5.0 Test",
                REFERER_HEADER = "https://howlongtobeat.com/",
                TIMEOUT = 10,
                get_build_id = function()
                    build_idx = build_idx + 1
                    return build_ids[build_idx] or build_ids[#build_ids]
                end,
                get_init_url = function() return "https://howlongtobeat.com/api/test/init" end,
                get_search_url = function() return "https://howlongtobeat.com/api/test" end,
                invalidate = function() invalidate_called = invalidate_called + 1 end,
            }
            package.loaded["hltb_api"] = nil
            api = require("hltb_api")

            local valid_response = json.encode({
                pageProps = {
                    game = {
                        data = {
                            game = { { game_id = 99, game_name = "X", comp_main = 1, comp_plus = 2, comp_100 = 3 } }
                        }
                    }
                }
            })
            api._http = create_mock_http_get({
                ["https://howlongtobeat.com/_next/data/stale-build-id/game/99.json"] = { status = 404, body = "" },
                ["https://howlongtobeat.com/_next/data/fresh-build-id/game/99.json"] = { status = 200, body = valid_response },
            })

            local game, err = api.fetch_game_by_id(99)
            assert.is_nil(err)
            assert.is_not_nil(game)
            assert.equals(99, game.game_id)
            assert.equals(1, invalidate_called)
        end)
    end)
end)
