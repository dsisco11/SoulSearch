local soulsearch_env = require('support.soulsearch_env')

local function make_unit(id)
    return {id=id}
end

local function make_environment(overrides)
    overrides = overrides or {}
    local citizen = make_unit(1)
    local pet = make_unit(2)
    local resident = make_unit(3)
    local visitor = make_unit(4)
    local wildlife = make_unit(5)
    local inactive = make_unit(6)
    local units = {citizen, pet, resident, visitor, wildlife, inactive, citizen}
    local active = {[1]=true, [2]=true, [3]=true, [4]=true, [5]=true}
    local citizen_calls = {}
    local resident_calls = {}
    local dfhack = {
        isMapLoaded=overrides.is_map_loaded or function() return true end,
        world={isFortressMode=overrides.is_fortress_mode or function() return true end},
        units={
            isActive=function(unit) return active[unit.id] or false end,
            isCitizen=function(unit, include_insane)
                table.insert(citizen_calls, {id=unit.id, include_insane=include_insane})
                return unit == citizen
            end,
            isResident=function(unit, include_insane)
                table.insert(resident_calls, {id=unit.id, include_insane=include_insane})
                return unit == citizen or unit == resident
            end,
            isFortControlled=function(unit)
                return unit == citizen or unit == pet
            end,
            isVisitor=function(unit) return unit == visitor end,
            isMerchant=function() return false end,
            isDiplomat=function() return false end,
        },
    }
    return {
        df={global={world={units={active=units}}}},
        dfhack=dfhack,
        units=units,
        resident_calls=resident_calls,
        citizen_calls=citizen_calls,
    }
end

local function unit_ids(units)
    local ids = {}
    for _, unit in ipairs(units or {}) do table.insert(ids, unit.id) end
    return ids
end

return function(test, repo_root)
    test.case('unit scopes: select active units in source order without duplicates', function()
        local env = make_environment()
        local provider = soulsearch_env.load_unit_scope_provider(
            repo_root, env.df, env.dfhack).new('all_active')
        local units, err = provider.get_units()
        test.assert_nil(err)
        test.assert_sequence({1, 2, 3, 4, 5}, unit_ids(units))
    end)

    test.case('unit scopes: residents include insane residents and exclude others', function()
        local env = make_environment()
        local provider = soulsearch_env.load_unit_scope_provider(
            repo_root, env.df, env.dfhack).new('fort_residents')
        local units = provider.get_units()
        test.assert_sequence({1, 3}, unit_ids(units))
        for _, call in ipairs(env.resident_calls) do
            test.assert_true(call.include_insane)
        end
    end)

    test.case('unit scopes: citizens include insane citizens and exclude residents', function()
        local env = make_environment()
        local provider = soulsearch_env.load_unit_scope_provider(
            repo_root, env.df, env.dfhack).new('citizens')
        local units = provider.get_units()
        test.assert_sequence({1}, unit_ids(units))
        for _, call in ipairs(env.citizen_calls) do
            test.assert_true(call.include_insane)
        end
    end)

    test.case('unit scopes: default is citizens', function()
        local env = make_environment()
        local provider = soulsearch_env.load_unit_scope_provider(
            repo_root, env.df, env.dfhack).new()
        test.assert_equal('citizens',
            soulsearch_env.load_unit_scope_provider(repo_root, env.df, env.dfhack)
                .get_default_scope())
        local units = provider.get_units()
        test.assert_sequence({1}, unit_ids(units))
    end)

    test.case('unit scopes: visitors include regular visitors', function()
        local env = make_environment()
        local provider = soulsearch_env.load_unit_scope_provider(
            repo_root, env.df, env.dfhack).new('visitors')
        test.assert_sequence({4}, unit_ids(provider.get_units()))
    end)

    test.case('unit scopes: dropdown options are isolated and player-facing', function()
        local env = make_environment()
        local scopes = soulsearch_env.load_unit_scope_provider(
            repo_root, env.df, env.dfhack)
        local options = scopes.get_options()
        test.assert_sequence({'Citizens', 'Residents', 'Citizens and pets', 'Visitors', 'All units'},
            {options[1].label, options[2].label, options[3].label, options[4].label,
                options[5].label})
        options[1].label = 'Changed'
        test.assert_equal('Citizens', scopes.get_options()[1].label)
    end)

    test.case('unit scopes: unavailable contexts return no partial candidates', function()
        local map_env = make_environment{is_map_loaded=function() return false end}
        local provider = soulsearch_env.load_unit_scope_provider(
            repo_root, map_env.df, map_env.dfhack).new('all_active')
        local units, err = provider.get_units()
        test.assert_nil(units)
        test.assert_equal('SoulSearch requires a loaded fortress map.', err)

        local fort_env = make_environment{is_fortress_mode=function() return false end}
        provider = soulsearch_env.load_unit_scope_provider(
            repo_root, fort_env.df, fort_env.dfhack).new('all_active')
        units, err = provider.get_units()
        test.assert_nil(units)
        test.assert_equal('SoulSearch only works in fortress mode.', err)
    end)

    test.case('unit scopes: unknown scopes fail at construction', function()
        local env = make_environment()
        local scopes = soulsearch_env.load_unit_scope_provider(
            repo_root, env.df, env.dfhack)
        local ok, err = pcall(scopes.new, 'unknown')
        test.assert_false(ok)
        test.assert_true(tostring(err):find('Unknown SoulSearch unit scope', 1, true) ~= nil)
    end)
end
