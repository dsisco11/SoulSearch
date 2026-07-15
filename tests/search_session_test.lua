local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local session_module = soulsearch_env.load_search_session(repo_root)
    local QUERY_KIND = session_module.SEARCH_QUERY_KIND
    local function new(filters)
        return session_module.new({filters=filters or {}, unit_scope='fort_residents',
            result_sort={key=nil, reverse=false, phase=0}})
    end

    test.case('Search session: filters, queries, scope, and sort are isolated', function()
        local session = new()
        test.assert_true(session:add_filter('skill:MINING'))
        test.assert_false(session:add_filter('skill:MINING'))
        local filters = session:get_filters()
        filters[#filters].id = 'broken'
        test.assert_true(session:contains_filter('skill:MINING'))
        test.assert_true(session:set_query(QUERY_KIND.ATTRIBUTE, 'strength'))
        test.assert_false(session:set_query(QUERY_KIND.ATTRIBUTE, 'strength'))
        test.assert_false(session:set_query('not_a_query_kind', 'invalid kind'))
        test.assert_true(session:set_unit_scope('visitors'))
        test.assert_false(session:set_unit_scope('visitors'))
        test.assert_equal('name', session:cycle_sort('name').key)
        test.assert_true(session:cycle_sort('name').reverse)
        test.assert_nil(session:cycle_sort('name').key)
    end)

    test.case('Search session: rows recompute and retain selected unit identity', function()
        local session = new()
        session:replace_rows({
            {unit_id=2, name='B', profession='Miner'},
            {unit_id=1, name='A', profession='Carpenter'},
        })
        session:set_selected_result({unit_id=2}, 1)
        local results, selected = session:recompute_results()
        test.assert_equal(2, results[selected].unit_id)
        session:cycle_sort('name')
        results, selected = session:recompute_results()
        test.assert_equal(2, results[selected].unit_id)
    end)

    test.case('Search session: filter transitions preserve validated snapshots', function()
        local session = new()
        test.assert_false(session:remove_filter('skill:MINING'))
        test.assert_true(session:set_filter_direction('skill:MINING', 'low'))
        test.assert_equal('low', session:get_filter_direction('skill:MINING'))
        test.assert_true(session:replace_filters({
            {id='skill:MINING', direction='high'},
            {id='skill:CARPENTRY', direction='low'},
        }))
        local filters = session:get_filters()
        filters[1].direction = 'broken'
        test.assert_equal('high', session:get_filter_direction('skill:MINING'))
        test.assert_true(session:clear_filters())
        test.assert_false(session:clear_filters())
    end)

    test.case('Search session: candidate rows do not alias caller snapshots', function()
        local session = new()
        local rows = {{unit_id=1, name='Urist', profession='Miner'}}
        session:replace_rows(rows)
        rows[1].name = 'Changed outside the session'
        local results = session:recompute_results()
        test.assert_equal('Urist', results[1].name)
    end)
end
