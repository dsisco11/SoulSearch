local soulsearch_env = require('support.soulsearch_env')

local function raw(id, flags)
    return {creature_id=id, name={[0]=id:lower()}, caste={[0]={flags=flags}}}
end

local function make_df()
    local df = soulsearch_env.make_df_stub()
    df.global.world.raws.creatures.all = {
        raw('DWARF', {CAN_LEARN=true, CAN_SPEAK=true}),
        raw('DOG', {PET=true, TRAINABLE_HUNTING=true}),
        raw('ELF', {CAN_LEARN=true, CAN_SPEAK=true}),
        raw('CAT', {PET=true}),
    }
    return df
end

local function ids(units)
    local result = {}
    for _, unit in ipairs(units or {}) do table.insert(result, unit.id) end
    return result
end

local function filter(id, direction)
    return {id=id, direction=direction or 'high'}
end

return function(test, repo_root)
    test.case('race provider: positives union and negatives subtract in source order', function()
        local upstream_calls = 0
        local source = {
            {id=1, race=1, caste=0},
            {id=2, race=2, caste=0},
            {id=3, race=3, caste=0},
            {id=2, race=2, caste=0},
        }
        local upstream = soulsearch_env.load_candidate_provider(repo_root).new(function()
            upstream_calls = upstream_calls + 1
            return source
        end)
        local provider = soulsearch_env.load_race_filter_provider(repo_root, make_df()).new(
            upstream, {
                filter('race:group:HUMANOIDS'),
                filter('race:group:WORK_ANIMALS'),
                filter('race:raw:DWARF', 'low'),
            })
        local units, err = provider.get_units()
        test.assert_nil(err)
        test.assert_equal(1, upstream_calls)
        test.assert_sequence({2, 3}, ids(units))
    end)

    test.case('race provider: negative-only input defaults to humanoids', function()
        local upstream = soulsearch_env.load_candidate_provider(repo_root).new(function()
            return {
                {id=1, race=1, caste=0},
                {id=2, race=2, caste=0},
                {id=3, race=3, caste=0},
            }
        end)
        local provider = soulsearch_env.load_race_filter_provider(repo_root, make_df()).new(
            upstream, {filter('race:raw:DWARF', 'low')})
        test.assert_sequence({3}, ids(provider.get_units()))
    end)

    test.case('race provider: exclusions support humanoids except dwarves and animals except dogs', function()
        local upstream = soulsearch_env.load_candidate_provider(repo_root).new(function()
            return {
                {id=1, race=1, caste=0},
                {id=2, race=2, caste=0},
                {id=3, race=3, caste=0},
                {id=4, race=4, caste=0},
            }
        end)
        local provider = soulsearch_env.load_race_filter_provider(repo_root, make_df()).new(
            upstream, {
                filter('race:group:HUMANOIDS'),
                filter('race:raw:DWARF', 'low'),
            })
        test.assert_sequence({3}, ids(provider.get_units()))

        provider = soulsearch_env.load_race_filter_provider(repo_root, make_df()).new(
            upstream, {
                filter('race:group:TAMEABLE_ANIMALS'),
                filter('race:raw:DOG', 'low'),
            })
        test.assert_sequence({4}, ids(provider.get_units()))
    end)

    test.case('race provider: upstream errors propagate without a partial set', function()
        local upstream = soulsearch_env.load_candidate_provider(repo_root).new(function()
            return nil, 'scope unavailable'
        end)
        local provider = soulsearch_env.load_race_filter_provider(repo_root, make_df()).new(
            upstream, {filter('race:group:HUMANOIDS')})
        local units, err = provider.get_units()
        test.assert_nil(units)
        test.assert_equal('scope unavailable', err)
    end)

    test.case('race provider: invalid upstream providers fail at construction', function()
        local provider = soulsearch_env.load_race_filter_provider(repo_root, make_df())
        local ok, err = pcall(provider.new, {})
        test.assert_false(ok)
        test.assert_true(tostring(err):find('requires an upstream candidate provider', 1, true) ~= nil)
    end)
end
