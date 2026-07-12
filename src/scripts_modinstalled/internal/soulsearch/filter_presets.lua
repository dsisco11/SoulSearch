--@ module=true

---@class SoulSearchFilterPreset
---@field version integer
---@field filters SoulSearchSelectedFilter[]

local json = require('json')
local scriptmanager = require('script-manager')

local MOD_ID = 'soulsearch'
local PRESETS_DIR = 'presets/'
local FILE_SUFFIX = '.json'
local PRESET_VERSION = 1

---@param name any
---@return string|nil
local function normalize_name(name)
    if type(name) ~= 'string' then return nil end
    name = name:match('^%s*(.-)%s*$')
    if name == '' or #name > 48 or not name:match('^[%w _%-]+$') then
        return nil
    end
    return name
end

---@param name string
---@return string
local function get_path(name)
    return scriptmanager.getModStatePath(MOD_ID) .. PRESETS_DIR .. name .. FILE_SUFFIX
end

---@return string
local function get_directory()
    return scriptmanager.getModStatePath(MOD_ID) .. PRESETS_DIR
end

---@param filters SoulSearchSelectedFilter[]
---@return SoulSearchSelectedFilter[]
local function copy_filters(filters)
    local copy = {}
    for _, filter in ipairs(type(filters) == 'table' and filters or {}) do
        if type(filter) == 'table' then
            table.insert(copy, {id=filter.id, direction=filter.direction})
        end
    end
    return copy
end

---@return string[]
function list()
    local names = {}
    -- Some DFHack versions return nil rather than an empty table when the
    -- directory has not yet been created. That is the normal first-run case.
    for _, filename in ipairs(dfhack.filesystem.listdir(get_directory()) or {}) do
        local name = filename:match('^(.*)%.json$')
        if name and normalize_name(name) == name then
            table.insert(names, name)
        end
    end
    table.sort(names, function(left, right) return left:lower() < right:lower() end)
    return names
end

---@param name string
---@param filters SoulSearchSelectedFilter[]
---@return boolean success
---@return string|nil error
function save(name, filters)
    name = normalize_name(name)
    if not name then
        return false, 'Preset names may use letters, numbers, spaces, hyphens, and underscores.'
    end

    if not dfhack.filesystem.mkdir_recursive(get_directory()) then
        return false, 'Could not create the SoulSearch preset directory.'
    end
    local ok, config = pcall(json.open, get_path(name))
    if not ok or type(config) ~= 'table' then
        return false, 'Could not open preset "' .. name .. '" for writing.'
    end
    config.data = {
        version=PRESET_VERSION,
        filters=copy_filters(filters),
    }
    ok = pcall(function() config:write() end)
    if not ok then
        return false, 'Could not write preset "' .. name .. '".'
    end
    return true
end

---@param name string
---@return SoulSearchSelectedFilter[]|nil filters
---@return string|nil error
function load(name)
    name = normalize_name(name)
    if not name then return nil, 'Invalid preset name.' end

    local ok, config = pcall(json.open, get_path(name))
    if not ok or type(config) ~= 'table' or type(config.data) ~= 'table' then
        return nil, 'Could not read preset "' .. name .. '".'
    end
    if config.data.version ~= PRESET_VERSION or type(config.data.filters) ~= 'table' then
        return nil, 'Preset "' .. name .. '" has an unsupported format.'
    end
    return copy_filters(config.data.filters)
end
