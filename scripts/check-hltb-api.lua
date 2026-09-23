--[[
    Run the plugin's actual API client against HLTB. Requires a POSIX shell,
    curl, Lua, and dkjson; used by .github/workflows/hltb-api-monitor.yml.
    Only the Millennium HTTP/logger adapters are replaced for the CLI.
]]

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function request(url, opts)
    opts = opts or {}
    local body_path = os.tmpname()
    local cmd = "curl -sS -o " .. shell_quote(body_path) .. " -w '%{http_code}'"
        .. " --max-time " .. shell_quote(opts.timeout or 60)
        .. " -X " .. shell_quote(opts.method or "GET")

    for key, value in pairs(opts.headers or {}) do
        cmd = cmd .. " -H " .. shell_quote(key .. ": " .. value)
    end
    if opts.data then
        cmd = cmd .. " --data-binary " .. shell_quote(opts.data)
    end
    cmd = cmd .. " " .. shell_quote(url)

    local pipe = io.popen(cmd, "r")
    if not pipe then
        os.remove(body_path)
        return nil, "popen failed"
    end
    local code_str = (pipe:read("*a") or ""):gsub("%s+$", "")
    local ok = pipe:close()
    local body_file = io.open(body_path, "rb")
    local body = body_file and body_file:read("*a") or ""
    if body_file then body_file:close() end
    os.remove(body_path)

    local status = tonumber(code_str)
    if not ok or not status or status < 100 or not body_file then
        return nil, "curl failed (HTTP " .. code_str .. ")"
    end
    return { status = status, body = body }, nil
end

package.loaded["http"] = { get = request, request = request }
package.loaded["json"] = require("dkjson")
package.loaded["logger"] = {
    info = function(_, msg) io.stderr:write("[hltb] " .. tostring(msg) .. "\n") end,
    error = function(_, msg) io.stderr:write("[hltb error] " .. tostring(msg) .. "\n") end,
}
package.path = package.path .. ";backend/?.lua"

local api = require("hltb_api")
local results = api.search("Dark Souls")
if not results or #results.data == 0 then
    io.stderr:write("Search failed or returned no results for 'Dark Souls'\n")
    os.exit(1)
end

-- Search ranking can change. Check the known game, not whichever result is first.
local game
for _, result in ipairs(results.data) do
    if result.game_id == 2224 then
        game = result
        break
    end
end
if not game then
    io.stderr:write("Search did not return Dark Souls (HLTB ID 2224)\n")
    os.exit(1)
end

local has_completion_time = false
for _, field in ipairs({ "comp_main", "comp_plus", "comp_100" }) do
    local value = game[field]
    -- Missing categories are valid, but supplied values must remain numeric.
    if value ~= nil and type(value) ~= "number" then
        io.stderr:write("Invalid completion time field: " .. field .. "\n")
        os.exit(1)
    end
    if value and value > 0 then has_completion_time = true end
end
if not has_completion_time then
    io.stderr:write("Dark Souls has no positive completion times\n")
    os.exit(1)
end

io.write(string.format("Search check passed: %s (ID %d), %d results; main=%s plus=%s 100=%s seconds\n",
    game.game_name, game.game_id, #results.data,
    tostring(game.comp_main), tostring(game.comp_plus), tostring(game.comp_100)))
