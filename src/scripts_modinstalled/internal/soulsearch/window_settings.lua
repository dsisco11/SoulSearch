--@ module=true

---Session-only settings snapshots keyed by a stable window identity. This
---module deliberately has no filesystem or DFHack dependencies.

local DEFAULT_ID = 'default'

---@type table<string, table>
local snapshots = {}

---@param value any
---@return any
local function copy_value(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do
        result[copy_value(key)] = copy_value(child)
    end
    return result
end

---@param settings_id any
---@return string
function normalize_settings_id(settings_id)
    if settings_id == nil or settings_id == '' then return DEFAULT_ID end
    assert(type(settings_id) == 'string',
        'SoulSearch settings ID must be a string.')
    return settings_id
end

---@param settings_id any
---@return table|nil
function load(settings_id)
    local snapshot = snapshots[normalize_settings_id(settings_id)]
    return snapshot and copy_value(snapshot) or nil
end

---@param settings_id any
---@param changes table
---@return table updated
function update(settings_id, changes)
    assert(type(changes) == 'table',
        'SoulSearch settings changes must be a table.')
    local id = normalize_settings_id(settings_id)
    local updated = copy_value(snapshots[id] or {})
    for _, key in ipairs{
        'filters',
        'result_sort',
        'stats_sort',
        'frame',
    } do
        if changes[key] ~= nil then
            updated[key] = copy_value(changes[key])
        end
    end
    snapshots[id] = updated
    return copy_value(updated)
end

---Clears all session settings. Intended for isolated tests and module reload.
function clear()
    snapshots = {}
end
