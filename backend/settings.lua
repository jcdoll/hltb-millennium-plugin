local json = require("json")
local logger = require("logger")
local millennium = require("millennium")

local M = {}

M.DEFAULTS = {
    showInLibrary = true,
    showInStore = true,
    showViewDetails = true,
    alignRight = true,
    alignBottom = true,
    horizontalOffset = 0,
    verticalOffset = 0,
    storePosition = "hero",
    showStoreViewDetails = true,
}

local function get_settings_path()
    return millennium.get_install_path() .. "/settings.json"
end

function M.load()
    local path = get_settings_path()
    local file = io.open(path, "r")
    if not file then
        return M.merge_defaults({})
    end

    local content = file:read("*a")
    file:close()

    local ok, parsed = pcall(json.decode, content)
    if not ok or type(parsed) ~= "table" then
        logger:info("Settings file invalid, using defaults")
        return M.merge_defaults({})
    end

    return M.merge_defaults(parsed)
end

function M.save(settings)
    local path = get_settings_path()
    local file, err = io.open(path, "w")
    if not file then
        logger:error("Failed to write settings: " .. (err or "unknown"))
        return false
    end

    file:write(json.encode(settings))
    file:close()
    return true
end

function M.merge_defaults(settings)
    local result = {}
    for k, v in pairs(M.DEFAULTS) do
        if settings[k] ~= nil then
            result[k] = settings[k]
        else
            result[k] = v
        end
    end
    return result
end

return M
