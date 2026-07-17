local soulsearch_env = require('support.soulsearch_env')

local function ids(units)
    local result = {}
    for _, unit in ipairs(units or {}) do table.insert(result, unit.id) end
    return result
end

return function(test, repo_root)
    test.case('active unit provider: preserves source order and removes duplicates and inactive units', function()
        local first, second, inactive = {id=2}, {id=1}, {id=3}
        local df = {global={world={units={active={first, second, first, inactive}}}}}
        local dfhack = {isMapLoaded=function() return true end,
            world={isFortressMode=function() return true end},
            units={isActive=function(unit) return unit ~= inactive end}}
        local units, err = soulsearch_env.load_active_unit_provider(repo_root, df, dfhack)
            .new().get_units()
        test.assert_nil(err)
        test.assert_sequence({2, 1}, ids(units))
    end)

    test.case('active unit provider: returns no partial candidates when unavailable', function()
        local df = {global={world={units={active={}}}}}
        local dfhack = {isMapLoaded=function() return false end,
            world={isFortressMode=function() return true end},
            units={isActive=function() error('unexpected active check') end}}
        local units, err = soulsearch_env.load_active_unit_provider(repo_root, df, dfhack)
            .new().get_units()
        test.assert_nil(units)
        test.assert_equal('SoulSearch requires a loaded fortress map.', err)
    end)
end
