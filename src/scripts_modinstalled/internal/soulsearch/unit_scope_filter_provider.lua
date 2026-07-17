--@ module=true

local candidate_filter_family_provider =
    reqscript('internal/soulsearch/candidate_filter_family_provider')
local unit_scope_catalog =
    reqscript('internal/soulsearch/unit_scope_catalog')
local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

---@param upstream SoulSearchCandidateProvider
---@param selected_filters SoulSearchSelectedFilter[]|nil
---@return SoulSearchCandidateProvider
function new(upstream, selected_filters)
    return candidate_filter_family_provider.new(upstream, selected_filters,
        filter_constants.kind.UNIT_SCOPE, unit_scope_catalog.matches_unit)
end
