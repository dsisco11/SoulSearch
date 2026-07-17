local soulsearch_env = require('support.soulsearch_env')

local function ids(units)
    local result = {}
    for _, unit in ipairs(units or {}) do table.insert(result, unit.id) end
    return result
end

return function(test, repo_root)
    test.case('unit scope filter provider: applies the shared include and exclude algebra', function()
        local citizen, resident, visitor = {id=1}, {id=2}, {id=3}
        local dfhack = {units={
            isCitizen=function(unit) return unit == citizen end,
            isResident=function(unit) return unit == citizen or unit == resident end,
            isFortControlled=function() return false end,
            isVisitor=function(unit) return unit == visitor end,
            isMerchant=function() return false end, isDiplomat=function() return false end,
        }}
        local candidates = soulsearch_env.load_candidate_provider(repo_root)
        local upstream = candidates.new(function() return {citizen, resident, visitor} end)
        local provider = soulsearch_env.load_unit_scope_filter_provider(repo_root, dfhack).new(
            upstream, {
                {id='unit_scope:fort_residents', direction='high'},
                {id='unit_scope:citizens', direction='low'},
            })
        test.assert_sequence({2}, ids(provider.get_units()))
    end)
end
