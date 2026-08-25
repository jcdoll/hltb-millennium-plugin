--[[
    Run the plugin's endpoint discovery against HLTB and print the resulting
    API path (e.g. "search/site") to stdout. Exits non-zero on failure.

    Used by .github/workflows/hltb-api-monitor.yml so the CI monitor uses the
    same discovery logic as the plugin at runtime, eliminating drift between
    the plugin's behavior and what the monitor checks.

    HTTP requests are shelled out to `curl`, which the workflow runner has
    installed. This intentionally avoids any Lua HTTP rock so the monitor
    needs only a stock Lua interpreter.
]]

local function shell_quote(s)
    -- POSIX-safe single-quote wrapping. The plugin only ever passes well-formed
    -- HLTB URLs and ASCII headers here, but we still escape ' defensively in
    -- case HLTB ever adds one to a chunk URL.
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- http shim that mirrors what the plugin's http module returns:
--   { status = <number>, body = <string> }, nil   on success
--   nil, "<error>"                                on transport failure
package.loaded["http"] = {
    get = function(url, opts)
        opts = opts or {}
        local body_path = os.tmpname()

        local cmd = "curl -sS -o " .. shell_quote(body_path) .. " -w '%{http_code}'"
        if opts.timeout then
            cmd = cmd .. " --max-time " .. tostring(opts.timeout)
        end
        if opts.headers then
            for k, v in pairs(opts.headers) do
                cmd = cmd .. " -H " .. shell_quote(k .. ": " .. v)
            end
        end
        cmd = cmd .. " " .. shell_quote(url) .. " 2>/dev/null"

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
        if not status then
            return nil, "curl exit (status='" .. code_str .. "', ok=" .. tostring(ok) .. ")"
        end

        return { status = status, body = body }, nil
    end,
}

package.loaded["logger"] = {
    info = function(_, msg) io.stderr:write("[discover] " .. tostring(msg) .. "\n") end,
    error = function(_, msg) io.stderr:write("[discover error] " .. tostring(msg) .. "\n") end,
}

package.path = package.path .. ";backend/?.lua"

local endpoints = require("hltb_endpoint_discovery")

local search_url = endpoints.get_search_url()
if not search_url then
    io.stderr:write("Endpoint discovery returned nil\n")
    os.exit(1)
end

local api_path = search_url:match("/api/([a-zA-Z0-9_/%-]+)$")
if not api_path then
    io.stderr:write("Could not extract API path from: " .. search_url .. "\n")
    os.exit(1)
end

io.write(api_path)
