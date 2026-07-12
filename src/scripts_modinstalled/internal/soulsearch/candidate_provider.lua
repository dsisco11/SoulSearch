--@ module=true

-- This module has no world-derived cache. Lifecycle reload order is provided by
-- module_registry.lua; no reset_cache() hook is needed here.

---@class SoulSearchCandidateProvider
---@field get_units fun(): df.unit[]|nil, string|nil

---Creates a candidate provider from a single collection operation. Candidate
---providers deliberately know nothing about snapshots, filtering UI, or
---ranking; later phases can compose unit-scope and race providers here.
---@param get_units fun(): df.unit[]|nil, string|nil
---@return SoulSearchCandidateProvider
function new(get_units)
    assert(type(get_units) == 'function',
        'SoulSearch candidate provider requires get_units()')
    return {get_units=get_units}
end
