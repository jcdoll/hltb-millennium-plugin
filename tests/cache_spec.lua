--[[
    Cache Unit Tests

    Tests for the unified backend cache (result cache + ID cache).
    Uses mock io/millennium modules to test without filesystem access.

    Run with: busted tests/cache_spec.lua
]]

package.path = package.path .. ";backend/?.lua"

local json = require("dkjson")

-- Mock dependencies
package.loaded["json"] = json
package.loaded["logger"] = {
    info = function() end,
    error = function() end,
}
package.loaded["millennium"] = {
    get_install_path = function() return "/mock/path" end,
}

describe("cache", function()
    local cache
    local original_io_open
    local original_os_time
    local original_os_remove
    local mock_time

    before_each(function()
        original_io_open = io.open
        original_os_time = os.time
        original_os_remove = os.remove
        mock_time = 1000000
        os.time = function() return mock_time end
        os.remove = function() end
        package.loaded["cache"] = nil
        cache = require("cache")
        -- Mock io.open AFTER require so luarocks can load the module
        io.open = function() return nil end
    end)

    after_each(function()
        io.open = original_io_open
        os.time = original_os_time
        os.remove = original_os_remove
    end)

    describe("result cache", function()
        it("returns nil for cache miss", function()
            local entry = cache.get(12345)
            assert.is_nil(entry)
        end)

        it("returns entry for cache hit", function()
            local data = { game_id = 1, game_name = "Test Game" }
            cache.set(12345, data)

            local entry, is_stale = cache.get(12345)
            assert.is_not_nil(entry)
            assert.equals(1, entry.data.game_id)
            assert.equals("Test Game", entry.data.game_name)
            assert.is_false(is_stale)
        end)

        it("marks entries as stale after 12 hours", function()
            cache.set(12345, { game_id = 1 })

            -- Advance time by 12 hours + 1 second
            mock_time = mock_time + 12 * 60 * 60 + 1

            local entry, is_stale = cache.get(12345)
            assert.is_not_nil(entry)
            assert.is_true(is_stale)
        end)

        it("returns fresh for entries within 12 hours", function()
            cache.set(12345, { game_id = 1 })

            -- Advance time by 11 hours
            mock_time = mock_time + 11 * 60 * 60

            local entry, is_stale = cache.get(12345)
            assert.is_not_nil(entry)
            assert.is_false(is_stale)
        end)

        it("expires entries after 90 days", function()
            cache.set(12345, { game_id = 1 })

            -- Advance time by 90 days + 1 second
            mock_time = mock_time + 90 * 24 * 60 * 60 + 1

            local entry = cache.get(12345)
            assert.is_nil(entry)
        end)

        it("clears all entries", function()
            cache.set(111, { game_id = 1 })
            cache.set(222, { game_id = 2 })

            cache.clear()

            assert.is_nil(cache.get(111))
            assert.is_nil(cache.get(222))
        end)

        it("returns correct stats", function()
            local stats = cache.stats()
            assert.equals(0, stats.count)
            assert.is_nil(stats.oldestTimestamp)

            cache.set(111, { game_id = 1 })
            mock_time = mock_time + 100
            cache.set(222, { game_id = 2 })

            stats = cache.stats()
            assert.equals(2, stats.count)
            assert.equals(1000000, stats.oldestTimestamp)
        end)

        it("handles nil data (not found)", function()
            cache.set(12345, nil)

            local entry, is_stale = cache.get(12345)
            assert.is_not_nil(entry)
            assert.is_true(entry.notFound)
            assert.is_false(is_stale)
        end)

        it("preserves existing times when new data is empty search miss", function()
            cache.set(12345, {
                searched_name = "Dark Souls",
                game_id = 2224,
                game_name = "Dark Souls",
                comp_main = 41.7,
                comp_plus = 60.1,
                comp_100 = 104.9,
            })

            -- Simulate a search miss after HLTB endpoint rotation
            cache.set(12345, { searched_name = "Dark Souls" })

            local entry = cache.get(12345)
            assert.equals(2224, entry.data.game_id)
            assert.equals("Dark Souls", entry.data.game_name)
            assert.equals(41.7, entry.data.comp_main)
            assert.equals(60.1, entry.data.comp_plus)
            assert.equals(104.9, entry.data.comp_100)
        end)

        it("preserves missing fields when new data has only some times", function()
            cache.set(12345, {
                searched_name = "X",
                game_id = 1,
                game_name = "X",
                comp_main = 10,
                comp_plus = 20,
                comp_100 = 30,
            })

            -- HLTB transiently drops comp_100 in this fetch
            cache.set(12345, {
                searched_name = "X",
                game_id = 1,
                game_name = "X",
                comp_main = 11,
                comp_plus = 21,
                comp_100 = nil,
            })

            local entry = cache.get(12345)
            assert.equals(11, entry.data.comp_main)
            assert.equals(21, entry.data.comp_plus)
            assert.equals(30, entry.data.comp_100)
        end)

        it("treats zero as missing when merging times", function()
            cache.set(12345, { game_id = 1, comp_main = 10, comp_plus = 20, comp_100 = 30 })
            cache.set(12345, { game_id = 1, comp_main = 11, comp_plus = 0, comp_100 = 0 })

            local entry = cache.get(12345)
            assert.equals(11, entry.data.comp_main)
            assert.equals(20, entry.data.comp_plus)
            assert.equals(30, entry.data.comp_100)
        end)

        it("uses new data when existing has fewer fields", function()
            cache.set(12345, { game_id = 1, comp_main = 10 })
            cache.set(12345, { game_id = 1, comp_main = 11, comp_plus = 21, comp_100 = 31 })

            local entry = cache.get(12345)
            assert.equals(11, entry.data.comp_main)
            assert.equals(21, entry.data.comp_plus)
            assert.equals(31, entry.data.comp_100)
        end)

        it("preserves game_id when new data is search miss only", function()
            cache.set(12345, { game_id = 99, game_name = "Found Game", comp_main = 5 })
            cache.set(12345, { searched_name = "Found Game" })

            local entry = cache.get(12345)
            assert.equals(99, entry.data.game_id)
            assert.equals("Found Game", entry.data.game_name)
            assert.equals(5, entry.data.comp_main)
        end)
    end)

    describe("id cache", function()
        it("returns nil for missing mapping", function()
            local hltb_id = cache.get_hltb_id(12345)
            assert.is_nil(hltb_id)
        end)

        it("returns mapping after bulk set", function()
            cache.set_id_mappings({
                { steam_id = 100, hltb_id = 200 },
                { steam_id = 300, hltb_id = 400 },
            }, "user123")

            assert.equals(200, cache.get_hltb_id(100))
            assert.equals(400, cache.get_hltb_id(300))
            assert.is_nil(cache.get_hltb_id(999))
        end)

        it("filters out zero hltb_id entries", function()
            cache.set_id_mappings({
                { steam_id = 100, hltb_id = 200 },
                { steam_id = 300, hltb_id = 0 },
            }, "user123")

            assert.equals(200, cache.get_hltb_id(100))
            assert.is_nil(cache.get_hltb_id(300))
        end)

        it("clears id cache", function()
            cache.set_id_mappings({
                { steam_id = 100, hltb_id = 200 },
            }, "user123")

            cache.clear_id_cache()
            assert.is_nil(cache.get_hltb_id(100))
        end)

        it("returns correct id cache stats", function()
            local stats = cache.id_cache_stats()
            assert.equals(0, stats.count)
            assert.is_nil(stats.ageSeconds)

            cache.set_id_mappings({
                { steam_id = 100, hltb_id = 200 },
                { steam_id = 300, hltb_id = 400 },
            }, "user123")

            mock_time = mock_time + 3600

            stats = cache.id_cache_stats()
            assert.equals(2, stats.count)
            assert.equals("user123", stats.steamUserId)
            assert.equals(3600, stats.ageSeconds)
        end)

        it("validates cache for correct user", function()
            cache.set_id_mappings({
                { steam_id = 100, hltb_id = 200 },
            }, "user123")

            assert.is_true(cache.is_id_cache_valid("user123"))
            assert.is_false(cache.is_id_cache_valid("other_user"))
        end)

        it("reports invalid when empty", function()
            assert.is_false(cache.is_id_cache_valid("user123"))
        end)
    end)

    describe("persistence", function()
        it("loads result cache from disk", function()
            local cache_data = {
                ["12345"] = { data = { game_id = 1, game_name = "Test" }, timestamp = mock_time, notFound = false },
            }
            local mock_file = {
                read = function() return json.encode(cache_data) end,
                close = function() end,
            }

            io.open = function(path)
                if path == "/mock/path/cache.json" then return mock_file end
                return nil
            end

            cache.load()

            local entry = cache.get(12345)
            assert.is_not_nil(entry)
            assert.equals(1, entry.data.game_id)
        end)

        it("loads id cache from disk", function()
            local id_data = {
                mappings = { ["100"] = 200, ["300"] = 400 },
                metadata = { timestamp = mock_time, steamUserId = "user123" },
            }
            local mock_file = {
                read = function() return json.encode(id_data) end,
                close = function() end,
            }

            io.open = function(path)
                if path == "/mock/path/id_cache.json" then return mock_file end
                return nil
            end

            cache.load()

            assert.equals(200, cache.get_hltb_id(100))
            assert.equals(400, cache.get_hltb_id(300))
            assert.is_true(cache.is_id_cache_valid("user123"))
        end)

        it("handles missing cache files gracefully", function()
            io.open = function() return nil end

            -- Should not error
            cache.load()

            assert.is_nil(cache.get(12345))
            assert.is_nil(cache.get_hltb_id(100))
        end)

        it("handles corrupt cache files gracefully", function()
            local mock_file = {
                read = function() return "not valid json{{{" end,
                close = function() end,
            }

            io.open = function() return mock_file end

            -- Should not error
            cache.load()

            assert.is_nil(cache.get(12345))
        end)
    end)
end)
