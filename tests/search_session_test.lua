local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local session_module = soulsearch_env.load_search_session(repo_root)
    local QUERY_KIND = session_module.SEARCH_QUERY_KIND
    local function new(filters)
        return session_module.new({filters=filters or {},
            result_sort={key=nil, reverse=false, phase=0}})
    end

    add_test('Search session: filters, queries, and sort are isolated', function()
        local session = new()
        luaunit.assertEvalToTrue(session:add_filter('skill:MINING'))
        luaunit.assertEvalToFalse(session:add_filter('skill:MINING'))
        local filters = session:get_filters()
        filters[#filters].id = 'broken'
        luaunit.assertEvalToTrue(session:contains_filter('skill:MINING'))
        luaunit.assertEvalToTrue(session:set_query(QUERY_KIND.ATTRIBUTE, 'strength'))
        luaunit.assertEvalToFalse(session:set_query(QUERY_KIND.ATTRIBUTE, 'strength'))
        luaunit.assertEvalToFalse(session:set_query('not_a_query_kind', 'invalid kind'))
        luaunit.assertEvalToTrue(session:set_query(QUERY_KIND.UNIT_SCOPE, 'visitors'))
        luaunit.assertEvalToFalse(session:set_query(QUERY_KIND.UNIT_SCOPE, 'visitors'))
        luaunit.assertIs('name', session:cycle_sort('name').key)
        luaunit.assertEvalToTrue(session:cycle_sort('name').reverse)
        luaunit.assertNil(session:cycle_sort('name').key)
    end)

    add_test('Search session: rows recompute and retain selected unit identity', function()
        local session = new()
        session:replace_rows({
            {unit_id=2, name='B', profession='Miner'},
            {unit_id=1, name='A', profession='Carpenter'},
        })
        session:set_selected_result({unit_id=2}, 1)
        local results, selected = session:recompute_results()
        luaunit.assertIs(2, results[selected].unit_id)
        session:cycle_sort('name')
        results, selected = session:recompute_results()
        luaunit.assertIs(2, results[selected].unit_id)
    end)

    add_test('Search session: filter transitions preserve validated snapshots', function()
        local session = new()
        luaunit.assertEvalToFalse(session:remove_filter('skill:MINING'))
        luaunit.assertEvalToTrue(session:set_filter_direction('skill:MINING', 'low'))
        luaunit.assertIs('low', session:get_filter_direction('skill:MINING'))
        luaunit.assertEvalToTrue(session:replace_filters({
            {id='skill:MINING', direction='high'},
            {id='skill:CARPENTRY', direction='low'},
        }))
        local filters = session:get_filters()
        filters[1].direction = 'broken'
        luaunit.assertIs('high', session:get_filter_direction('skill:MINING'))
        luaunit.assertEvalToTrue(session:clear_filters())
        luaunit.assertEvalToFalse(session:clear_filters())
    end)

    add_test('Search session: multiple unit scopes remain candidate filters', function()
        local session = new()
        luaunit.assertEvalToTrue(session:add_filter('unit_scope:citizens'))
        luaunit.assertEvalToTrue(session:add_filter('unit_scope:visitors'))
        luaunit.assertEvalToTrue(session:add_filter('race:group:HUMANOIDS'))
        luaunit.assertEvalToTrue(session:add_filter('skill:MINING'))
        local candidates = session:get_candidate_filters()
        luaunit.assertEquals({'unit_scope:citizens', 'unit_scope:visitors',
            'race:group:HUMANOIDS'}, (function()
                local ids = {}
                for _, filter in ipairs(candidates) do table.insert(ids, filter.id) end
                return ids
            end)())
        luaunit.assertEquals({'skill:MINING'}, (function()
            local ids = {}
            for _, filter in ipairs(session:get_ranking_filters()) do table.insert(ids, filter.id) end
            return ids
        end)())
    end)

    add_test('Search session: candidate rows do not alias caller snapshots', function()
        local session = new()
        local rows = {{unit_id=1, name='Urist', profession='Miner'}}
        session:replace_rows(rows)
        rows[1].name = 'Changed outside the session'
        local results = session:recompute_results()
        luaunit.assertIs('Urist', results[1].name)
    end)

return native_tests
