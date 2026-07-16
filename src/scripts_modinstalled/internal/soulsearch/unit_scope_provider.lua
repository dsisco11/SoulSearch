--@ module=true

-- Scope providers are evaluated fresh for each request and have no
-- world-derived cache, so lifecycle.lua has no reset hook to invoke here.

---@alias SoulSearchUnitScope 'all_active'|'citizens'|'fort_residents'|'citizens_and_pets'|'visitors'

local candidate_provider =
    reqscript('internal/soulsearch/candidate_provider')
local availability = reqscript('internal/soulsearch/availability')
local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS
local UNIT_SCOPE = filter_constants.unit_scope

local DEFAULT_SCOPE = filter_constants.default_unit_scope

local SCOPE_OPTIONS = {
    {label='Citizens', value=UNIT_SCOPE.CITIZENS},
    {label='Residents', value=UNIT_SCOPE.FORT_RESIDENTS},
    {label='Citizens and pets', value=UNIT_SCOPE.CITIZENS_AND_PETS},
    {label='Visitors', value=UNIT_SCOPE.VISITORS},
    {label='All units', value=UNIT_SCOPE.ALL_ACTIVE},
}

---@param unit df.unit
---@return boolean
local function is_visitor(unit)
    return dfhack.units.isVisitor(unit) or
        dfhack.units.isMerchant(unit) or
        dfhack.units.isDiplomat(unit)
end

local PREDICATE_BY_SCOPE = {
    [UNIT_SCOPE.ALL_ACTIVE]=function() return true end,
    [UNIT_SCOPE.CITIZENS]=function(unit)
        return dfhack.units.isCitizen(unit, true)
    end,
    [UNIT_SCOPE.FORT_RESIDENTS]=function(unit)
        return dfhack.units.isResident(unit, true)
    end,
    [UNIT_SCOPE.CITIZENS_AND_PETS]=function(unit)
        return dfhack.units.isFortControlled(unit)
    end,
    [UNIT_SCOPE.VISITORS]=is_visitor,
}

---@return string|nil
local function get_unavailable_reason()
    return availability.get_unavailable_reason()
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

---@return {label: string, value: SoulSearchUnitScope}[]
function get_options()
    local options = {}
    for _, option in ipairs(SCOPE_OPTIONS) do
        table.insert(options, {label=option.label, value=option.value})
    end
    return options
end
