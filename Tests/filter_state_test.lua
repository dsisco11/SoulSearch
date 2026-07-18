local soulsearch_env = require('support.soulsearch_env')

local function ids(filters)
    local result = {}
    for _, filter in ipairs(filters) do
        table.insert(result, filter.id)
    end
    return result
end

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
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
        add_test('filter state transition: ' .. case.name, function()
            local state = filter_state.new(case.initial)
            luaunit.assertIs(case.expected_changed, case.apply(state))
            luaunit.assertEquals(case.expected_ids, ids(filter_state.get_filters(state)))
        end)
    end

    add_test('filter state add: defaults to high and duplicate is a no-op', function()
        local state = filter_state.new()
        luaunit.assertEvalToTrue(filter_state.add(state, 'skill:MINING'))
        luaunit.assertEvalToFalse(filter_state.add(state, 'skill:MINING', 'low'))
        luaunit.assertIs('high', filter_state.get_direction(state, 'skill:MINING'))
        luaunit.assertIs(1, filter_state.count(state))
    end)

    add_test('filter state add: invalid ID and direction are no-ops', function()
        local state = filter_state.new()
        luaunit.assertEvalToFalse(filter_state.add(state, 'skill:UNKNOWN', 'high'))
        luaunit.assertEvalToFalse(filter_state.add(state, 'skill:MINING', 'sideways'))
        luaunit.assertIs(0, filter_state.count(state))
    end)

    add_test('filter state direction: active changes and unchanged is a no-op', function()
        local state = filter_state.new{{id='skill:MINING', direction='high'}}
        luaunit.assertEvalToTrue(filter_state.set_direction(state, 'skill:MINING', 'low'))
        luaunit.assertIs('low', filter_state.get_direction(state, 'skill:MINING'))
        luaunit.assertEvalToFalse(filter_state.set_direction(state, 'skill:MINING', 'low'))
    end)

    add_test('filter state direction: inactive filter is added atomically', function()
        local state = filter_state.new()
        luaunit.assertEvalToTrue(filter_state.set_direction(state, 'skill:MINING', 'low'))
        local filters = filter_state.get_filters(state)
        luaunit.assertIs(1, #filters)
        luaunit.assertIs('skill:MINING', filters[1].id)
        luaunit.assertIs('low', filters[1].direction)
        luaunit.assertEvalToFalse(filter_state.set_direction(state, 'skill:UNKNOWN', 'high'))
        luaunit.assertEvalToFalse(filter_state.set_direction(state, 'skill:SWORD', 'sideways'))
    end)

    add_test('filter state move: reorders and reports the new priority', function()
        local state = filter_state.new{
            {id='skill:MINING', direction='high'},
            {id='skill:SWORD', direction='low'},
            {id='trait:PATIENCE', direction='high'},
        }
        local changed, priority = filter_state.move(state, 'trait:PATIENCE', -2)
        luaunit.assertEvalToTrue(changed)
        luaunit.assertIs(1, priority)
        luaunit.assertEquals(
            {'trait:PATIENCE', 'skill:MINING', 'skill:SWORD'},
            ids(filter_state.get_filters(state)))
    end)

    add_test('filter state move: clamps first and last boundaries', function()
        local state = filter_state.new{
            {id='skill:MINING', direction='high'},
            {id='skill:SWORD', direction='low'},
        }
        local changed, priority = filter_state.move(state, 'skill:MINING', -1)
        luaunit.assertEvalToFalse(changed)
        luaunit.assertIs(1, priority)
        changed, priority = filter_state.move(state, 'skill:SWORD', 1)
        luaunit.assertEvalToFalse(changed)
        luaunit.assertIs(2, priority)
        changed, priority = filter_state.move(state, 'skill:UNKNOWN', 1)
        luaunit.assertEvalToFalse(changed)
        luaunit.assertNil(priority)
    end)

    add_test('filter state validation: skips stale duplicate and malformed entries', function()
        local state = filter_state.new{
            false,
            {id='skill:UNKNOWN', direction='high'},
            {id='skill:MINING', direction='sideways'},
            {id='skill:MINING', direction='low'},
            {id='skill:MINING', direction='high'},
            {id='trait:PATIENCE', direction='high'},
        }
        local filters = filter_state.get_filters(state)
        luaunit.assertEquals({'skill:MINING', 'trait:PATIENCE'}, ids(filters))
        luaunit.assertIs('low', filters[1].direction)
    end)

    add_test('filter state reads do not alias live state', function()
        local state = filter_state.new{{id='skill:MINING', direction='high'}}
        local read = filter_state.get_filters(state)
        read[1].id = 'skill:SWORD'
        read[1].direction = 'low'
        table.insert(read, {id='trait:PATIENCE', direction='low'})
        local reread = filter_state.get_filters(state)
        luaunit.assertIs(1, #reread)
        luaunit.assertIs('skill:MINING', reread[1].id)
        luaunit.assertIs('high', reread[1].direction)
    end)

    add_test('filter state search serialization preserves priority order', function()
        local state = filter_state.new{
            {id='trait:PATIENCE', direction='low'},
            {id='skill:MINING', direction='high'},
        }
        local filters = filter_state.get_filters(state)
        luaunit.assertEquals({'trait:PATIENCE', 'skill:MINING'}, ids(filters))
        luaunit.assertIs('low', filters[1].direction)
        luaunit.assertIs('high', filters[2].direction)
    end)

    add_test('filter state move: candidate filters never acquire ranking priority', function()
        local state = filter_state.new{
            {id='race:group:HUMANOIDS', direction='high'},
            {id='skill:MINING', direction='high'},
        }
        local changed, priority = filter_state.move(
            state, 'race:group:HUMANOIDS', 1)
        luaunit.assertEvalToFalse(changed)
        luaunit.assertIs(1, priority)
        luaunit.assertEquals({
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

    add_test('filter state behavior projections preserve ranking order and isolation', function()
        local state = filter_state.new{
            {id='trait:PATIENCE', direction='low'},
            {id='skill:MINING', direction='high'},
        }
        luaunit.assertEquals({},
            (function()
                local result = {}
                for _, filter in ipairs(filter_state.get_candidate_filters(state)) do
                    table.insert(result, filter.id)
                end
                return result
            end)())
        local ranking = filter_state.get_ranking_filters(state)
        luaunit.assertEquals({'trait:PATIENCE', 'skill:MINING'}, ids(ranking))
        ranking[1].id = 'skill:SWORD'
        luaunit.assertEquals({'trait:PATIENCE', 'skill:MINING'},
            ids(filter_state.get_ranking_filters(state)))
    end)

    add_test('filter state replace validates and preserves preset order', function()
        local state = filter_state.new{{id='skill:MINING', direction='high'}}
        luaunit.assertEvalToTrue(filter_state.replace(state, {
            {id='trait:PATIENCE', direction='low'},
            {id='skill:SWORD', direction='high'},
            {id='skill:UNKNOWN', direction='high'},
        }))
        luaunit.assertEquals({'trait:PATIENCE', 'skill:SWORD'},
            ids(filter_state.get_filters(state)))
        luaunit.assertEvalToFalse(filter_state.replace(state, {
            {id='trait:PATIENCE', direction='low'},
            {id='skill:SWORD', direction='high'},
        }))
    end)

    add_test('filter state replace: legacy and stale race presets are cleaned', function()
        local state = filter_state.new()
        luaunit.assertEvalToTrue(filter_state.replace(state, {
            {id='skill:MINING', direction='high'},
        }))
        local filters = filter_state.get_filters(state)
        luaunit.assertIs('skill:MINING', filters[1].id)

        luaunit.assertEvalToTrue(filter_state.replace(state, {
            {id='race:raw:STALE', direction='high'},
            {id='race:group:HUMANOIDS', direction='low'},
            {id='skill:SWORD', direction='low'},
        }))
        filters = filter_state.get_filters(state)
        luaunit.assertIs('race:group:HUMANOIDS', filters[1].id)
        luaunit.assertIs('low', filters[1].direction)
        luaunit.assertIs('skill:SWORD', filters[2].id)
        luaunit.assertIs('low', filters[2].direction)
    end)

    add_test('filter state: shipped presets preserve only their ranking filters', function()
        local sources = {
            filter_defaults.get_all()[1].filters,
            role_presets.get_role_presets()[1].filters,
            role_presets.get_combat_presets()[1].filters,
        }
        for _, source in ipairs(sources) do
            local state = filter_state.new(source)
            luaunit.assertIs(0, #filter_state.get_candidate_filters(state))
            local ranking = filter_state.get_ranking_filters(state)
            local expected = {}
            for _, filter in ipairs(source) do
                if descriptors.get_catalog().by_id[filter.id] then
                    table.insert(expected, filter)
                end
            end
            luaunit.assertIs(#expected, #ranking)
            for index, filter in ipairs(expected) do
                luaunit.assertIs(filter.id, ranking[index].id)
                luaunit.assertIs(filter.direction, ranking[index].direction)
            end
        end
    end)

    add_test('filter state permits an empty candidate scope', function()
        local state = filter_state.new{{id='race:raw:UNKNOWN', direction='low'}}
        local candidates = filter_state.get_candidate_filters(state)
        luaunit.assertIs(0, #candidates)

        luaunit.assertEvalToTrue(filter_state.add(state, 'race:group:HUMANOIDS'))
        luaunit.assertEvalToTrue(filter_state.remove(state, 'race:group:HUMANOIDS'))
        luaunit.assertEvalToFalse(filter_state.clear(state))
    end)

    add_test('filter state removes humanoids when another race is included', function()
        local state = filter_state.new{
            {id='race:group:HUMANOIDS', direction='high'},
            {id='race:group:TAMEABLE_ANIMALS', direction='high'},
        }
        luaunit.assertEvalToTrue(filter_state.remove(state, 'race:group:HUMANOIDS'))
        local candidates = filter_state.get_candidate_filters(state)
        luaunit.assertIs(1, #candidates)
        luaunit.assertIs('race:group:TAMEABLE_ANIMALS', candidates[1].id)
        luaunit.assertIs('high', candidates[1].direction)
    end)

    add_test('filter state: unit-scope candidates cannot acquire ranking priority', function()
        local state = filter_state.new{
            {id='unit_scope:citizens', direction='high'},
            {id='skill:MINING', direction='high'},
        }
        local changed, priority = filter_state.move(state, 'unit_scope:citizens', 1)
        luaunit.assertEvalToFalse(changed)
        luaunit.assertIs(1, priority)
        luaunit.assertEquals({'unit_scope:citizens'},
            ids(filter_state.get_candidate_filters(state)))
        luaunit.assertEquals({'skill:MINING'},
            ids(filter_state.get_ranking_filters(state)))
    end)

    add_test('filter state: loading a scope-free preset replaces the complete filter list', function()
        local state = filter_state.new{
            {id='unit_scope:citizens', direction='high'},
            {id='race:group:HUMANOIDS', direction='high'},
            {id='skill:MINING', direction='high'},
        }
        luaunit.assertEvalToTrue(filter_state.replace(state, {
            {id='skill:SWORD', direction='low'},
        }))
        luaunit.assertEquals({'skill:SWORD'}, ids(filter_state.get_filters(state)))
        luaunit.assertIs(0, #filter_state.get_candidate_filters(state))
    end)

return native_tests
