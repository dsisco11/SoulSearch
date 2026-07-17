--@ module=true

---@class SoulSearchUnitScopeDescriptor
---@field id string
---@field kind 'unit_scope'
---@field behavior 'candidate'
---@field key string
---@field label string

local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS
local UNIT_SCOPE = filter_constants.unit_scope

---@param unit df.unit
---@return boolean
local function is_visitor(unit)
    return dfhack.units.isVisitor(unit) or
        dfhack.units.isMerchant(unit) or
        dfhack.units.isDiplomat(unit)
end

---@param unit df.unit
---@return boolean
local function is_livestock(unit)
    local caste = dfhack.units.getCasteRaw(unit)
    local flags = caste and caste.flags
    return dfhack.units.isFortControlled(unit) and flags and
        (flags.PET or flags.PET_EXOTIC) or false
end

local DEFINITIONS = {
    {key=UNIT_SCOPE.CITIZENS, label='Citizens', matches=function(unit)
        return dfhack.units.isCitizen(unit, true)
    end},
    {key=UNIT_SCOPE.FORT_RESIDENTS, label='Residents', matches=function(unit)
        return dfhack.units.isResident(unit, true)
    end},
    {key=UNIT_SCOPE.CITIZENS_AND_PETS, label='Citizens and pets', matches=function(unit)
        return dfhack.units.isFortControlled(unit)
    end},
    {key=UNIT_SCOPE.LIVESTOCK, label='Livestock', matches=is_livestock},
    {key=UNIT_SCOPE.PETS, label='Pets', matches=function(unit)
        return dfhack.units.isPet(unit)
    end},
    {key=UNIT_SCOPE.VISITORS, label='Visitors', matches=is_visitor},
    {key=UNIT_SCOPE.WILDLIFE, label='Wildlife', matches=function(unit)
        return dfhack.units.isWildlife(unit)
    end},
}

local descriptors_by_id = {}
for _, definition in ipairs(DEFINITIONS) do
    local descriptor = {
        id=UNIT_SCOPE.id_prefix .. definition.key,
        kind=filter_constants.kind.UNIT_SCOPE,
        behavior=filter_constants.behavior.CANDIDATE,
        key=definition.key,
        label=definition.label,
    }
    definition.descriptor = descriptor
    descriptors_by_id[descriptor.id] = definition
end

---@return SoulSearchUnitScopeDescriptor[]
function get_descriptors()
    local result = {}
    for _, definition in ipairs(DEFINITIONS) do
        table.insert(result, definition.descriptor)
    end
    return result
end

---@param descriptor SoulSearchUnitScopeDescriptor|nil
---@param unit df.unit
---@return boolean
function matches_unit(descriptor, unit)
    local definition = descriptor and descriptors_by_id[descriptor.id]
    return definition ~= nil and definition.matches(unit) or false
end
