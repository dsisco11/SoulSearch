local soulsearch_env = require('support.soulsearch_env')

local function ids(filters)
    local result = {}
    for _, filter in ipairs(filters) do
        table.insert(result, filter.id)
    end
    return result
end

return function(test, repo_root)
    local filter_state, descriptors = soulsearch_env.load_filter_state(repo_root)
    local filter_defaults = soulsearch_env.load_filter_defaults(repo_root)
    local role_presets = soulsearch_env.load_role_presets(repo_root, descriptors)

    local transition_cases = {
        {
            name='add appends a valid filter',
            apply=function(state)
                return filter_state.add(state, 'skill:MINING', 'low')
            end,
            expected_changed=true,
            expected_ids={'skill:MINING'},
        },
        {
            name='remove deletes an active filter',
            initial={{id='skill:MINING', direction='high'}},
            apply=function(state)
                return filter_state.remove(state, 'skill:MINING')
            end,
            expected_changed=true,
            expected_ids={},
        },
        {
            name='remove ignores an inactive filter',
            apply=function(state)
                return filter_state.remove(state, 'skill:MINING')
            end,
            expected_changed=false,
            expected_ids={},
        },
        {
            name='clear removes every filter',
            initial={
                {id='skill:MINING', direction='high'},
                {id='trait:PATIENCE', direction='low'},
            },
            apply=function(state) return filter_state.clear(state) end,
            expected_changed=true,
            expected_ids={},
        },
        {
            name='clear ignores an empty state',
            apply=function(state) return filter_state.clear(state) end,
            expected_changed=false,
            expected_ids={},
        },
    }
    for _, case in ipairs(transition_cases) do
        test.case('filter state transition: ' .. case.name, function()
            local state = filter_state.new(case.initial)
            test.assert_equal(case.expected_changed, case.apply(state))
            test.assert_sequence(case.expected_ids, ids(filter_state.get_filters(state)))
        end)
    end

    test.case('filter state add: defaults to high and duplicate is a no-op', function()
        local state = filter_state.new()
        test.assert_true(filter_state.add(state, 'skill:MINING'))
        test.assert_false(filter_state.add(state, 'skill:MINING', 'low'))
        test.assert_equal('high', filter_state.get_direction(state, 'skill:MINING'))
        test.assert_equal(1, filter_state.count(state))
    end)

    test.case('filter state add: invalid ID and direction are no-ops', function()
        local state = filter_state.new()
        test.assert_false(filter_state.add(state, 'skill:UNKNOWN', 'high'))
        test.assert_false(filter_state.add(state, 'skill:MINING', 'sideways'))
        test.assert_equal(0, filter_state.count(state))
    end)

    test.case('filter state direction: active changes and unchanged is a no-op', function()
        local state = filter_state.new{{id='skill:MINING', direction='high'}}
        test.assert_true(filter_state.set_direction(state, 'skill:MINING', 'low'))
        test.assert_equal('low', filter_state.get_direction(state, 'skill:MINING'))
        test.assert_false(filter_state.set_direction(state, 'skill:MINING', 'low'))
    end)

    test.case('filter state direction: inactive filter is added atomically', function()
        local state = filter_state.new()
        test.assert_true(filter_state.set_direction(state, 'skill:MINING', 'low'))
        local filters = filter_state.get_filters(state)
        test.assert_equal(1, #filters)
        test.assert_equal('skill:MINING', filters[1].id)
        test.assert_equal('low', filters[1].direction)
        test.assert_false(filter_state.set_direction(state, 'skill:UNKNOWN', 'high'))
        test.assert_false(filter_state.set_direction(state, 'skill:SWORD', 'sideways'))
    end)

    test.case('filter state move: reorders and reports the new priority', function()
        local state = filter_state.new{
            {id='skill:MINING', direction='high'},
            {id='skill:SWORD', direction='low'},
            {id='trait:PATIENCE', direction='high'},
        }
        local changed, priority = filter_state.move(state, 'trait:PATIENCE', -2)
        test.assert_true(changed)
        test.assert_equal(1, priority)
        test.assert_sequence(
            {'trait:PATIENCE', 'skill:MINING', 'skill:SWORD'},
            ids(filter_state.get_filters(state)))
    end)

    test.case('filter state move: clamps first and last boundaries', function()
        local state = filter_state.new{
            {id='skill:MINING', direction='high'},
            {id='skill:SWORD', direction='low'},
        }
        local changed, priority = filter_state.move(state, 'skill:MINING', -1)
        test.assert_false(changed)
        test.assert_equal(1, priority)
        changed, priority = filter_state.move(state, 'skill:SWORD', 1)
        test.assert_false(changed)
        test.assert_equal(2, priority)
        changed, priority = filter_state.move(state, 'skill:UNKNOWN', 1)
        test.assert_false(changed)
        test.assert_nil(priority)
    end)

    test.case('filter state validation: skips stale duplicate and malformed entries', function()
        local state = filter_state.new{
            false,
            {id='skill:UNKNOWN', direction='high'},
            {id='skill:MINING', direction='sideways'},
            {id='skill:MINING', direction='low'},
            {id='skill:MINING', direction='high'},
            {id='trait:PATIENCE', direction='high'},
        }
        local filters = filter_state.get_filters(state)
        test.assert_sequence({'skill:MINING', 'trait:PATIENCE'}, ids(filters))
        test.assert_equal('low', filters[1].direction)
    end)

    test.case('filter state reads do not alias live state', function()
        local state = filter_state.new{{id='skill:MINING', direction='high'}}
        local read = filter_state.get_filters(state)
        read[1].id = 'skill:SWORD'
        read[1].direction = 'low'
        table.insert(read, {id='trait:PATIENCE', direction='low'})
        local reread = filter_state.get_filters(state)
        test.assert_equal(1, #reread)
        test.assert_equal('skill:MINING', reread[1].id)
        test.assert_equal('high', reread[1].direction)
    end)

    test.case('filter state search serialization preserves priority order', function()
        local state = filter_state.new{
            {id='trait:PATIENCE', direction='low'},
            {id='skill:MINING', direction='high'},
        }
        local filters = filter_state.get_filters(state)
        test.assert_sequence({'trait:PATIENCE', 'skill:MINING'}, ids(filters))
        test.assert_equal('low', filters[1].direction)
        test.assert_equal('high', filters[2].direction)
    end)

    test.case('filter state move: candidate filters never acquire ranking priority', function()
        local state = filter_state.new{
            {id='race:group:HUMANOIDS', direction='high'},
            {id='skill:MINING', direction='high'},
        }
        local changed, priority = filter_state.move(
            state, 'race:group:HUMANOIDS', 1)
        test.assert_false(changed)
        test.assert_equal(1, priority)
        test.assert_sequence({
            'race:group:HUMANOIDS',
            'skill:MINING',
        }, (function()
            local result = {}
            for _, filter in ipairs(filter_state.get_filters(state)) do
                table.insert(result, filter.id)
            end
            return result
        end)())
    end)

    test.case('filter state behavior projections preserve ranking order and isolation', function()
        local state = filter_state.new{
            {id='trait:PATIENCE', direction='low'},
            {id='skill:MINING', direction='high'},
        }
        test.assert_sequence({},
            (function()
                local result = {}
                for _, filter in ipairs(filter_state.get_candidate_filters(state)) do
                    table.insert(result, filter.id)
                end
                return result
            end)())
        local ranking = filter_state.get_ranking_filters(state)
        test.assert_sequence({'trait:PATIENCE', 'skill:MINING'}, ids(ranking))
        ranking[1].id = 'skill:SWORD'
        test.assert_sequence({'trait:PATIENCE', 'skill:MINING'},
            ids(filter_state.get_ranking_filters(state)))
    end)

    test.case('filter state replace validates and preserves preset order', function()
        local state = filter_state.new{{id='skill:MINING', direction='high'}}
        test.assert_true(filter_state.replace(state, {
            {id='trait:PATIENCE', direction='low'},
            {id='skill:SWORD', direction='high'},
            {id='skill:UNKNOWN', direction='high'},
        }))
        test.assert_sequence({'trait:PATIENCE', 'skill:SWORD'},
            ids(filter_state.get_filters(state)))
        test.assert_false(filter_state.replace(state, {
            {id='trait:PATIENCE', direction='low'},
            {id='skill:SWORD', direction='high'},
        }))
    end)

    test.case('filter state replace: legacy and stale race presets are cleaned', function()
        local state = filter_state.new()
        test.assert_true(filter_state.replace(state, {
            {id='skill:MINING', direction='high'},
        }))
        local filters = filter_state.get_filters(state)
        test.assert_equal('skill:MINING', filters[1].id)

        test.assert_true(filter_state.replace(state, {
            {id='race:raw:STALE', direction='high'},
            {id='race:group:HUMANOIDS', direction='low'},
            {id='skill:SWORD', direction='low'},
        }))
        filters = filter_state.get_filters(state)
        test.assert_equal('race:group:HUMANOIDS', filters[1].id)
        test.assert_equal('low', filters[1].direction)
        test.assert_equal('skill:SWORD', filters[2].id)
        test.assert_equal('low', filters[2].direction)
    end)

    test.case('filter state: shipped presets preserve only their ranking filters', function()
        local sources = {
            filter_defaults.get_all()[1].filters,
            role_presets.get_role_presets()[1].filters,
            role_presets.get_combat_presets()[1].filters,
        }
        for _, source in ipairs(sources) do
            local state = filter_state.new(source)
            test.assert_equal(0, #filter_state.get_candidate_filters(state))
            local ranking = filter_state.get_ranking_filters(state)
            local expected = {}
            for _, filter in ipairs(source) do
                if descriptors.get_catalog().by_id[filter.id] then
                    table.insert(expected, filter)
                end
            end
            test.assert_equal(#expected, #ranking)
            for index, filter in ipairs(expected) do
                test.assert_equal(filter.id, ranking[index].id)
                test.assert_equal(filter.direction, ranking[index].direction)
            end
        end
    end)

    test.case('filter state permits an empty candidate scope', function()
        local state = filter_state.new{{id='race:raw:UNKNOWN', direction='low'}}
        local candidates = filter_state.get_candidate_filters(state)
        test.assert_equal(0, #candidates)

        test.assert_true(filter_state.add(state, 'race:group:HUMANOIDS'))
        test.assert_true(filter_state.remove(state, 'race:group:HUMANOIDS'))
        test.assert_false(filter_state.clear(state))
    end)

    test.case('filter state removes humanoids when another race is included', function()
        local state = filter_state.new{
            {id='race:group:HUMANOIDS', direction='high'},
            {id='race:group:TAMEABLE_ANIMALS', direction='high'},
        }
        test.assert_true(filter_state.remove(state, 'race:group:HUMANOIDS'))
        local candidates = filter_state.get_candidate_filters(state)
        test.assert_equal(1, #candidates)
        test.assert_equal('race:group:TAMEABLE_ANIMALS', candidates[1].id)
        test.assert_equal('high', candidates[1].direction)
    end)
end
