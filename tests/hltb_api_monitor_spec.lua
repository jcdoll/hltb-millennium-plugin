-- Run the CLI in an isolated environment; network calls are covered by the live monitor.
local function run_monitor(results)
    local output = {}
    local exit_code = 0
    local env = setmetatable({
        package = { loaded = {}, path = package.path },
        io = {
            write = function(message) table.insert(output, message) end,
            stderr = { write = function(_, message) table.insert(output, message) end },
        },
        os = {
            exit = function(code)
                exit_code = code
                error("monitor exit", 0)
            end,
        },
        require = function(name)
            if name == "dkjson" then return require("dkjson") end
            assert.equals("hltb_api", name)
            return { search = function(query)
                assert.equals("Dark Souls", query)
                return results
            end }
        end,
    }, { __index = _G })
    local chunk = assert(loadfile("scripts/check-hltb-api.lua", "t", env))
    local ok, err = pcall(chunk)
    if not ok and err ~= "monitor exit" then error(err) end
    return exit_code, table.concat(output), env
end

local function game(id, main, plus, completionist)
    return {
        game_id = id, game_name = "Dark Souls", comp_all_count = 100,
        comp_main = main, comp_plus = plus, comp_100 = completionist,
    }
end

describe("HLTB API monitor", function()
    it("accepts completion times when the known game is not first", function()
        local code, output = run_monitor({ data = { game(26803, 0), game(2224, 150028) } })
        assert.equals(0, code)
        assert.matches("Search check passed", output)
    end)

    it("accepts missing categories when another category has a positive time", function()
        assert.equals(0, run_monitor({ data = { game(2224, nil, nil, 377020) } }))
    end)

    it("rejects failed searches", function()
        assert.equals(1, run_monitor(nil))
    end)

    it("rejects empty results", function()
        assert.equals(1, run_monitor({ data = {} }))
    end)

    it("rejects results that omit the known game", function()
        assert.equals(1, run_monitor({ data = { game(26803, 150028) } }))
    end)

    it("rejects zero or missing completion times", function()
        assert.equals(1, run_monitor({ data = { game(2224, 0, 0, 0) } }))
        assert.equals(1, run_monitor({ data = { game(2224) } }))
    end)

    it("rejects nonnumeric times even when another category is valid", function()
        local code, output = run_monitor({ data = { game(2224, "invalid", 150028) } })
        assert.equals(1, code)
        assert.matches("Invalid completion time field: comp_main", output)
    end)

    it("rejects incomplete curl transfers even with an HTTP 200 status", function()
        local _, _, env = run_monitor({ data = { game(2224, 150028) } })
        local removed
        env.os.tmpname = function() return "/tmp/monitor-test" end
        env.os.remove = function(path) removed = path end
        env.io.popen = function()
            return { read = function() return "200" end, close = function() return nil, "exit", 28 end }
        end
        env.io.open = function()
            return { read = function() return "partial response" end, close = function() end }
        end
        local response, err = env.package.loaded.http.get("https://howlongtobeat.com/")
        assert.is_nil(response)
        assert.matches("curl failed", err)
        assert.equals("/tmp/monitor-test", removed)
    end)
end)
