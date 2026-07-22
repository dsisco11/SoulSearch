local M = {}

---@param unit any
---@return boolean valid
local function is_valid_unit(unit)
    if unit == nil then return false end
    local ok, unit_id = pcall(function() return unit.id end)
    return ok and type(unit_id) == 'number' and unit_id >= 0
end

---@param units any
---@return df.unit|nil unit
local function first_valid_unit(units)
    for _, unit in pairs(units or {}) do
        if is_valid_unit(unit) then return unit end
    end
    return nil
end

---Selects a live unit using read-only DFHack APIs.
---@param options table|nil Injectable `dfhack` and `df` dependencies.
---@return df.unit|nil unit
---@return string source_or_error
function M.find(options)
    options = options or {}
    local host = options.dfhack or dfhack
    local df_api = options.df or df

    if host.isMapLoaded and not host.isMapLoaded() then
        return nil, 'a map must be loaded'
    end

    if host.units and host.units.getCitizens then
        local ok, citizens = pcall(host.units.getCitizens, false, true)
        local citizen = ok and first_valid_unit(citizens) or nil
        if citizen then return citizen, 'citizens' end
    end

    local active = df_api and df_api.global and df_api.global.world
        and df_api.global.world.units and df_api.global.world.units.active
    local unit = first_valid_unit(active)
    if unit then return unit, 'active units' end
    return nil, 'no valid live unit is available'
end

return M
