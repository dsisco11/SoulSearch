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

    test.case('filter state persistence does not alias live or loaded state', function()
        local state = filter_state.new{{id='skill:MINING', direction='high'}}
        filter_state.save(state)
        test.assert_true(filter_state.set_direction(state, 'skill:MINING', 'low'))
        local loaded = filter_state.load()
        test.assert_equal('high', filter_state.get_direction(loaded, 'skill:MINING'))
        test.assert_true(filter_state.add(loaded, 'skill:SWORD', 'low'))
        local reloaded = filter_state.load()
        test.assert_equal(1, filter_state.count(reloaded))
        test.assert_equal('skill:MINING', filter_state.get_filters(reloaded)[1].id)
    end)

    test.case('filter state load revalidates stale persisted IDs', function()
        local state = filter_state.new{{id='skill:MINING', direction='high'}}
        filter_state.save(state)
        local catalog = descriptors.get_catalog()
        local mining_descriptor = catalog.by_id['skill:MINING']
        catalog.by_id['skill:MINING'] = nil
        local loaded = filter_state.load()
        catalog.by_id['skill:MINING'] = mining_descriptor
        test.assert_equal(0, filter_state.count(loaded))
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
end
