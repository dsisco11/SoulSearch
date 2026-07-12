--@ module=true

-- Scope providers are evaluated fresh for each request and have no
-- world-derived cache, so lifecycle.lua has no reset hook to invoke here.

---@alias SoulSearchUnitScope 'all_active'|'fort_residents'|'citizens_and_pets'

local candidate_provider =
    reqscript('internal/soulsearch/candidate_provider')

local DEFAULT_SCOPE = 'citizens_and_pets'

local PREDICATE_BY_SCOPE = {
    all_active=function() return true end,
    fort_residents=function(unit)
        return dfhack.units.isResident(unit, true)
    end,
    citizens_and_pets=function(unit)
        return dfhack.units.isFortControlled(unit)
    end,
}

---@return string|nil
local function get_unavailable_reason()
    if not dfhack.isMapLoaded() then
        return 'SoulSearch requires a loaded fortress map.'
    end
    if not dfhack.world.isFortressMode() then
        return 'SoulSearch only works in fortress mode.'
    end
    return nil
end

---@param unit df.unit
---@return integer|df.unit
local function get_unit_key(unit)
    return unit.id ~= nil and unit.id or unit
end

---@param scope SoulSearchUnitScope|nil
---@return SoulSearchCandidateProvider
function new(scope)
    scope = scope or DEFAULT_SCOPE
    local matches_scope = PREDICATE_BY_SCOPE[scope]
    assert(matches_scope,
        'Unknown SoulSearch unit scope: ' .. tostring(scope))

    return candidate_provider.new(function()
        local reason = get_unavailable_reason()
        if reason then return nil, reason end

        local units = {}
        local seen = {}
        for _, unit in ipairs(df.global.world.units.active) do
            local key = get_unit_key(unit)
            if not seen[key] and dfhack.units.isActive(unit) and
                    matches_scope(unit) then
                seen[key] = true
                table.insert(units, unit)
            end
        end
        return units
    end)
end

---@return SoulSearchUnitScope
function get_default_scope()
    return DEFAULT_SCOPE
end
