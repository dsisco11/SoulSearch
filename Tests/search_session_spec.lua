local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('search session', function()

    local session_module = soulsearch_env.load_search_session(repo_root)
    local QUERY_KIND = session_module.SEARCH_QUERY_KIND
    local function new(filters)
        return session_module.new({filters=filters or {},
            result_sort={key=nil, reverse=false, phase=0}})
    end

    it('Search session: filters, queries, and sort are isolated', function()
        local session = new()
        assert.is_truthy(session:add_filter('skill:MINING'))
        assert.is_falsy(session:add_filter('skill:MINING'))
        local filters = session:get_filters()
        filters[#filters].id = 'broken'
        assert.is_truthy(session:contains_filter('skill:MINING'))
        assert.is_truthy(session:set_query(QUERY_KIND.ATTRIBUTE, 'strength'))
        assert.is_falsy(session:set_query(QUERY_KIND.ATTRIBUTE, 'strength'))
        assert.is_falsy(session:set_query('not_a_query_kind', 'invalid kind'))
        assert.is_truthy(session:set_query(QUERY_KIND.UNIT_SCOPE, 'visitors'))
        assert.is_falsy(session:set_query(QUERY_KIND.UNIT_SCOPE, 'visitors'))
        assert.are.equal('name', session:cycle_sort('name').key)
        assert.is_truthy(session:cycle_sort('name').reverse)
        assert.is_nil(session:cycle_sort('name').key)
    end)

    it('Search session: rows recompute and retain selected unit identity', function()
        local session = new()
        session:replace_rows({
            {unit_id=2, name='B', profession='Miner'},
            {unit_id=1, name='A', profession='Carpenter'},
        })
        session:set_selected_result({unit_id=2}, 1)
        local results, selected = session:recompute_results()
        assert.are.equal(2, results[selected].unit_id)
        session:cycle_sort('name')
        results, selected = session:recompute_results()
        assert.are.equal(2, results[selected].unit_id)
    end)

    it('Search session: filter transitions preserve validated snapshots', function()
        local session = new()
        assert.is_falsy(session:remove_filter('skill:MINING'))
        assert.is_truthy(session:set_filter_direction('skill:MINING', 'low'))
        assert.are.equal('low', session:get_filter_direction('skill:MINING'))
        assert.is_truthy(session:replace_filters({
            {id='skill:MINING', direction='high'},
            {id='skill:CARPENTRY', direction='low'},
        }))
        local filters = session:get_filters()
        filters[1].direction = 'broken'
        assert.are.equal('high', session:get_filter_direction('skill:MINING'))
        assert.is_truthy(session:clear_filters())
        assert.is_falsy(session:clear_filters())
    end)

    it('Search session: multiple unit scopes remain candidate filters', function()
        local session = new()
        assert.is_truthy(session:add_filter('unit_scope:citizens'))
        assert.is_truthy(session:add_filter('unit_scope:visitors'))
        assert.is_truthy(session:add_filter('race:group:HUMANOIDS'))
        assert.is_truthy(session:add_filter('skill:MINING'))
        local candidates = session:get_candidate_filters()
        assert.are.same({'unit_scope:citizens', 'unit_scope:visitors',
            'race:group:HUMANOIDS'}, (function()
                local ids = {}
                for _, filter in ipairs(candidates) do table.insert(ids, filter.id) end
                return ids
            end)())
        assert.are.same({'skill:MINING'}, (function()
            local ids = {}
            for _, filter in ipairs(session:get_ranking_filters()) do table.insert(ids, filter.id) end
            return ids
        end)())
    end)

    it('Search session: candidate rows do not alias caller snapshots', function()
        local session = new()
        local rows = {{unit_id=1, name='Urist', profession='Miner'}}
        session:replace_rows(rows)
        rows[1].name = 'Changed outside the session'
        local results = session:recompute_results()
        assert.are.equal('Urist', results[1].name)
    end)

end)