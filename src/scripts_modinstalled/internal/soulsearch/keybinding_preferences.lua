--@module=true

local MOD_ID = 'soulsearch'
local FILE_NAME = 'default-keybinding.json'
local VERSION = 1

---@class SoulSearchKeybindingPreferences
---@field read fun(): string status
---@field mark_considered fun(): boolean success, string|nil status

---@param dependencies table
---@return SoulSearchKeybindingPreferences
function new(dependencies)
    dependencies = dependencies or {}
    local json = dependencies.json
    local scriptmanager = dependencies.scriptmanager
    local filesystem = dependencies.filesystem

    local function get_path()
        if type(scriptmanager) ~= 'table' or
                type(scriptmanager.getModStatePath) ~= 'function' then
            return nil, 'unavailable'
        end
        local ok, directory = pcall(scriptmanager.getModStatePath, MOD_ID)
        if not ok or type(directory) ~= 'string' then
            return nil, 'error'
        end
        return directory .. FILE_NAME
    end

    local function read()
        if type(json) ~= 'table' or type(json.open) ~= 'function' or
                type(filesystem) ~= 'table' or
                type(filesystem.exists) ~= 'function' then
            return 'unavailable'
        end

        local path, path_status = get_path()
        if not path then return path_status end

        local ok, exists = pcall(filesystem.exists, path)
        if not ok or type(exists) ~= 'boolean' then return 'error' end
        if not exists then return 'unset' end

        local config
        ok, config = pcall(json.open, path, true)
        if not ok or type(config) ~= 'table' or type(config.data) ~= 'table' then
            return 'corrupt'
        end
        if config.data.version ~= VERSION then return 'corrupt' end
        if config.data.default_considered ~= true then return 'corrupt' end
        return 'considered'
    end

    local function mark_considered()
        if type(json) ~= 'table' or type(json.open) ~= 'function' then
            return false, 'unavailable'
        end

        local path, path_status = get_path()
        if not path then return false, path_status end

        local ok, config = pcall(json.open, path)
        if not ok or type(config) ~= 'table' or type(config.write) ~= 'function' then
            return false, 'error'
        end
        config.data = {version=VERSION, default_considered=true}
        ok = pcall(function() config:write() end)
        if not ok then return false, 'error' end
        return true
    end

    return {read=read, mark_considered=mark_considered}
end
