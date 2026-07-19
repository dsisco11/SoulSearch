local soulsearch_env = require('support.soulsearch_env')

local function ids(filters)
    local result = {}
    for _, filter in ipairs(filters) do
        table.insert(result, filter.id)
    end
    return result
end

local repo_root = require('support.repo_root')

describe('filter state', function()

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
        it('filter state transition: ' .. case.name, function()
            local state = filter_state.new(case.initial)
            assert.are.equal(case.expected_changed, case.apply(state))
            assert.are.same(case.expected_ids, ids(filter_state.get_filters(state)))
        end)
    end

    it('filter state add: defaults to high and duplicate is a no-op', function()
        local state = filter_state.new()
        assert.is_truthy(filter_state.add(state, 'skill:MINING'))
        assert.is_falsy(filter_state.add(state, 'skill:MINING', 'low'))
        assert.are.equal('high', filter_state.get_direction(state, 'skill:MINING'))
        assert.are.equal(1, filter_state.count(state))
    end)

    it('filter state add: invalid ID and direction are no-ops', function()
        local state = filter_state.new()
        assert.is_falsy(filter_state.add(state, 'skill:UNKNOWN', 'high'))
        assert.is_falsy(filter_state.add(state, 'skill:MINING', 'sideways'))
        assert.are.equal(0, filter_state.count(state))
    end)

    it('filter state direction: active changes and unchanged is a no-op', function()
        local state = filter_state.new{{id='skill:MINING', direction='high'}}
        assert.is_truthy(filter_state.set_direction(state, 'skill:MINING', 'low'))
        assert.are.equal('low', filter_state.get_direction(state, 'skill:MINING'))
        assert.is_falsy(filter_state.set_direction(state, 'skill:MINING', 'low'))
    end)

    it('filter state direction: inactive filter is added atomically', function()
        local state = filter_state.new()
        assert.is_truthy(filter_state.set_direction(state, 'skill:MINING', 'low'))
        local filters = filter_state.get_filters(state)
        assert.are.equal(1, #filters)
        assert.are.equal('skill:MINING', filters[1].id)
        assert.are.equal('low', filters[1].direction)
        assert.is_falsy(filter_state.set_direction(state, 'skill:UNKNOWN', 'high'))
        assert.is_falsy(filter_state.set_direction(state, 'skill:SWORD', 'sideways'))
    end)

    it('filter state move: reorders and reports the new priority', function()
        local state = filter_state.new{
            {id='skill:MINING', direction='high'},
            {id='skill:SWORD', direction='low'},
            {id='trait:PATIENCE', direction='high'},
        }
        local changed, priority = filter_state.move(state, 'trait:PATIENCE', -2)
        assert.is_truthy(changed)
        assert.are.equal(1, priority)
        assert.are.same(
            {'trait:PATIENCE', 'skill:MINING', 'skill:SWORD'},
            ids(filter_state.get_filters(state)))
    end)

    it('filter state move: clamps first and last boundaries', function()
        local state = filter_state.new{
            {id='skill:MINING', direction='high'},
            {id='skill:SWORD', direction='low'},
        }
        local changed, priority = filter_state.move(state, 'skill:MINING', -1)
        assert.is_falsy(changed)
        assert.are.equal(1, priority)
        changed, priority = filter_state.move(state, 'skill:SWORD', 1)
        assert.is_falsy(changed)
        assert.are.equal(2, priority)
        changed, priority = filter_state.move(state, 'skill:UNKNOWN', 1)
        assert.is_falsy(changed)
        assert.is_nil(priority)
    end)

    it('filter state validation: skips stale duplicate and malformed entries', function()
        local state = filter_state.new{
            false,
            {id='skill:UNKNOWN', direction='high'},
            {id='skill:MINING', direction='sideways'},
            {id='skill:MINING', direction='low'},
            {id='skill:MINING', direction='high'},
            {id='trait:PATIENCE', direction='high'},
        }
        local filters = filter_state.get_filters(state)
        assert.are.same({'skill:MINING', 'trait:PATIENCE'}, ids(filters))
        assert.are.equal('low', filters[1].direction)
    end)

    it('filter state reads do not alias live state', function()
        local state = filter_state.new{{id='skill:MINING', direction='high'}}
        local read = filter_state.get_filters(state)
        read[1].id = 'skill:SWORD'
        read[1].direction = 'low'
        table.insert(read, {id='trait:PATIENCE', direction='low'})
        local reread = filter_state.get_filters(state)
        assert.are.equal(1, #reread)
        assert.are.equal('skill:MINING', reread[1].id)
        assert.are.equal('high', reread[1].direction)
    end)

    it('filter state search serialization preserves priority order', function()
        local state = filter_state.new{
            {id='trait:PATIENCE', direction='low'},
            {id='skill:MINING', direction='high'},
        }
        local filters = filter_state.get_filters(state)
        assert.are.same({'trait:PATIENCE', 'skill:MINING'}, ids(filters))
        assert.are.equal('low', filters[1].direction)
        assert.are.equal('high', filters[2].direction)
    end)

    it('filter state move: candidate filters never acquire ranking priority', function()
        local state = filter_state.new{
            {id='race:group:HUMANOIDS', direction='high'},
            {id='skill:MINING', direction='high'},
        }
        local changed, priority = filter_state.move(
            state, 'race:group:HUMANOIDS', 1)
        assert.is_falsy(changed)
        assert.are.equal(1, priority)
        assert.are.same({
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

    it('filter state behavior projections preserve ranking order and isolation', function()
        local state = filter_state.new{
            {id='trait:PATIENCE', direction='low'},
            {id='skill:MINING', direction='high'},
        }
        assert.are.same({},
            (function()
                local result = {}
                for _, filter in ipairs(filter_state.get_candidate_filters(state)) do
                    table.insert(result, filter.id)
                end
                return result
            end)())
        local ranking = filter_state.get_ranking_filters(state)
        assert.are.same({'trait:PATIENCE', 'skill:MINING'}, ids(ranking))
        ranking[1].id = 'skill:SWORD'
        assert.are.same({'trait:PATIENCE', 'skill:MINING'},
            ids(filter_state.get_ranking_filters(state)))
    end)

    it('filter state replace validates and preserves preset order', function()
        local state = filter_state.new{{id='skill:MINING', direction='high'}}
        assert.is_truthy(filter_state.replace(state, {
            {id='trait:PATIENCE', direction='low'},
            {id='skill:SWORD', direction='high'},
            {id='skill:UNKNOWN', direction='high'},
        }))
        assert.are.same({'trait:PATIENCE', 'skill:SWORD'},
            ids(filter_state.get_filters(state)))
        assert.is_falsy(filter_state.replace(state, {
            {id='trait:PATIENCE', direction='low'},
            {id='skill:SWORD', direction='high'},
        }))
    end)

    it('filter state replace: legacy and stale race presets are cleaned', function()
        local state = filter_state.new()
        assert.is_truthy(filter_state.replace(state, {
            {id='skill:MINING', direction='high'},
        }))
        local filters = filter_state.get_filters(state)
        assert.are.equal('skill:MINING', filters[1].id)

        assert.is_truthy(filter_state.replace(state, {
            {id='race:raw:STALE', direction='high'},
            {id='race:group:HUMANOIDS', direction='low'},
            {id='skill:SWORD', direction='low'},
        }))
        filters = filter_state.get_filters(state)
        assert.are.equal('race:group:HUMANOIDS', filters[1].id)
        assert.are.equal('low', filters[1].direction)
        assert.are.equal('skill:SWORD', filters[2].id)
        assert.are.equal('low', filters[2].direction)
    end)

    it('filter state: shipped presets preserve only their ranking filters', function()
        local sources = {
            filter_defaults.get_all()[1].filters,
            role_presets.get_role_presets()[1].filters,
            role_presets.get_combat_presets()[1].filters,
        }
        for _, source in ipairs(sources) do
            local state = filter_state.new(source)
            assert.are.equal(0, #filter_state.get_candidate_filters(state))
            local ranking = filter_state.get_ranking_filters(state)
            local expected = {}
            for _, filter in ipairs(source) do
                if descriptors.get_catalog().by_id[filter.id] then
                    table.insert(expected, filter)
                end
            end
            assert.are.equal(#expected, #ranking)
            for index, filter in ipairs(expected) do
                assert.are.equal(filter.id, ranking[index].id)
                assert.are.equal(filter.direction, ranking[index].direction)
            end
        end
    end)

    it('filter state permits an empty candidate scope', function()
        local state = filter_state.new{{id='race:raw:UNKNOWN', direction='low'}}
        local candidates = filter_state.get_candidate_filters(state)
        assert.are.equal(0, #candidates)

        assert.is_truthy(filter_state.add(state, 'race:group:HUMANOIDS'))
        assert.is_truthy(filter_state.remove(state, 'race:group:HUMANOIDS'))
        assert.is_falsy(filter_state.clear(state))
    end)

    it('filter state removes humanoids when another race is included', function()
        local state = filter_state.new{
            {id='race:group:HUMANOIDS', direction='high'},
            {id='race:group:TAMEABLE_ANIMALS', direction='high'},
        }
        assert.is_truthy(filter_state.remove(state, 'race:group:HUMANOIDS'))
        local candidates = filter_state.get_candidate_filters(state)
        assert.are.equal(1, #candidates)
        assert.are.equal('race:group:TAMEABLE_ANIMALS', candidates[1].id)
        assert.are.equal('high', candidates[1].direction)
    end)

    it('filter state: unit-scope candidates cannot acquire ranking priority', function()
        local state = filter_state.new{
            {id='unit_scope:citizens', direction='high'},
            {id='skill:MINING', direction='high'},
        }
        local changed, priority = filter_state.move(state, 'unit_scope:citizens', 1)
        assert.is_falsy(changed)
        assert.are.equal(1, priority)
        assert.are.same({'unit_scope:citizens'},
            ids(filter_state.get_candidate_filters(state)))
        assert.are.same({'skill:MINING'},
            ids(filter_state.get_ranking_filters(state)))
    end)

    it('filter state: loading a scope-free preset replaces the complete filter list', function()
        local state = filter_state.new{
            {id='unit_scope:citizens', direction='high'},
            {id='race:group:HUMANOIDS', direction='high'},
            {id='skill:MINING', direction='high'},
        }
        assert.is_truthy(filter_state.replace(state, {
            {id='skill:SWORD', direction='low'},
        }))
        assert.are.same({'skill:SWORD'}, ids(filter_state.get_filters(state)))
        assert.are.equal(0, #filter_state.get_candidate_filters(state))
    end)

end)
