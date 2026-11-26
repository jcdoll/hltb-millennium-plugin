--[[
    Settings Unit Tests

    Tests for settings load, save, and merge_defaults.
    Uses mock io/millennium modules to test without filesystem access.

    Run with: busted tests/settings_spec.lua
]]

package.path = package.path .. ";backend/?.lua"

local json = require("dkjson")

-- Mock logger
package.loaded["logger"] = {
    info = function() end,
    error = function() end,
}

-- Mock millennium
package.loaded["millennium"] = {
    get_install_path = function() return "/mock/path" end,
}

-- Pre-load json
package.loaded["json"] = json

-- Mock file object factory
local function create_mock_file(content)
    return {
        _content = content,
        _written = nil,
        read = function(self, _mode)
            return self._content
        end,
        write = function(self, data)
            self._written = data
        end,
        close = function() end,
    }
end

describe("settings", function()
    local settings
    local original_io_open

    before_each(function()
        original_io_open = io.open
        package.loaded["settings"] = nil
        settings = require("settings")
    end)

    after_each(function()
        io.open = original_io_open
    end)

    describe("merge_defaults", function()
        it("returns all defaults for empty table", function()
            local result = settings.merge_defaults({})
            assert.equals(true, result.showInLibrary)
            assert.equals(true, result.showInStore)
            assert.equals(true, result.showViewDetails)
            assert.equals(true, result.alignRight)
            assert.equals(true, result.alignBottom)
            assert.equals(0, result.horizontalOffset)
            assert.equals(0, result.verticalOffset)
            assert.equals("hero", result.storePosition)
            assert.equals(true, result.showStoreViewDetails)
        end)

        it("preserves provided values", function()
            local result = settings.merge_defaults({
                showInLibrary = false,
                horizontalOffset = 42,
            })
            assert.equals(false, result.showInLibrary)
            assert.equals(42, result.horizontalOffset)
        end)

        it("fills missing keys with defaults", function()
            local result = settings.merge_defaults({ showInLibrary = false })
            assert.equals(true, result.showInStore)
            assert.equals(true, result.showViewDetails)
            assert.equals(0, result.verticalOffset)
        end)

        it("ignores unknown keys", function()
            local result = settings.merge_defaults({ unknownKey = "hello" })
            assert.is_nil(result.unknownKey)
        end)

        it("preserves string setting values", function()
            local result = settings.merge_defaults({ storePosition = "top" })
            assert.equals("top", result.storePosition)
        end)

        it("preserves false boolean values", function()
            local result = settings.merge_defaults({
                showInLibrary = false,
                showInStore = false,
                showViewDetails = false,
                alignRight = false,
                alignBottom = false,
            })
            assert.equals(false, result.showInLibrary)
            assert.equals(false, result.showInStore)
            assert.equals(false, result.showViewDetails)
            assert.equals(false, result.alignRight)
            assert.equals(false, result.alignBottom)
        end)
    end)

    describe("load", function()
        it("returns defaults when file does not exist", function()
            io.open = function() return nil end

            local result = settings.load()
            assert.equals(true, result.showInLibrary)
            assert.equals(true, result.showInStore)
            assert.equals(0, result.horizontalOffset)
        end)

        it("parses valid settings file", function()
            local saved = json.encode({
                showInLibrary = false,
                horizontalOffset = 10,
            })
            io.open = function() return create_mock_file(saved) end

            local result = settings.load()
            assert.equals(false, result.showInLibrary)
            assert.equals(10, result.horizontalOffset)
            assert.equals(true, result.showInStore) -- default filled in
        end)

        it("returns defaults for invalid JSON", function()
            io.open = function() return create_mock_file("not valid json{{{") end

            local result = settings.load()
            assert.equals(true, result.showInLibrary)
            assert.equals(0, result.horizontalOffset)
        end)

        it("returns defaults for non-table JSON", function()
            io.open = function() return create_mock_file('"just a string"') end

            local result = settings.load()
            assert.equals(true, result.showInLibrary)
        end)

        it("merges partial settings with defaults", function()
            local saved = json.encode({ showInStore = false })
            io.open = function() return create_mock_file(saved) end

            local result = settings.load()
            assert.equals(false, result.showInStore)
            assert.equals(true, result.showInLibrary)
            assert.equals(true, result.alignRight)
        end)
    end)

    describe("save", function()
        it("writes JSON and returns true", function()
            local mock_file = create_mock_file(nil)
            io.open = function() return mock_file end

            local ok = settings.save({ showInLibrary = false, showInStore = true })
            assert.is_true(ok)
            assert.is_not_nil(mock_file._written)

            local decoded = json.decode(mock_file._written)
            assert.equals(false, decoded.showInLibrary)
            assert.equals(true, decoded.showInStore)
        end)

        it("returns false when file cannot be opened", function()
            io.open = function() return nil, "Permission denied" end

            local ok = settings.save({ showInLibrary = true })
            assert.is_false(ok)
        end)
    end)
end)
