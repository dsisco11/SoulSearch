--@ module=true

-- Providers are composed per search pass and retain no world-derived cache.

local candidate_filter_family_provider =
    reqscript('internal/soulsearch/candidate_filter_family_provider')
local race_catalog = reqscript('internal/soulsearch/race_catalog')
local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

---@param upstream SoulSearchCandidateProvider
---@param selected_filters SoulSearchSelectedFilter[]|nil
---@return SoulSearchCandidateProvider
function new(upstream, selected_filters)
    return candidate_filter_family_provider.new(upstream, selected_filters,
        filter_constants.kind.RACE, race_catalog.matches_unit)
end
