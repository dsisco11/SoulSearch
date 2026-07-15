local soulsearch_env = require('support.soulsearch_env')

local function ids(views)
    local result = {}
    for _, view in ipairs(views or {}) do table.insert(result, view.view_id) end
    return result
end

return function(test, repo_root)
    local module = soulsearch_env.load_results_panel(repo_root)

    local function make_panel(calls)
        return module.ResultsPanel{view_id='results_panel', frame={l=0,t=0,r=0,b=0},
            inputs={
                on_query=function(text) calls.query = text end,
                on_select=function(result) calls.selected = result end,
                on_submit=function(result) calls.submitted = result end,
                on_sort=function(column) calls.sorted = column end,
            }}
    end

    test.case('results panel: owns the stable result view hierarchy', function()
        local panel = make_panel({})
        test.assert_equal('Panel', panel.widget_kind)
        test.assert_sequence({'search_field', 'result_header',
            'result_header_underline', 'result_columns', 'result_list'},
            ids(panel.subviews))
        test.assert_equal('CUSTOM_F', panel.subviews.search_field.key)
        test.assert_true(panel.subviews.search_field.modal)
    end)

    test.case('results panel: preserves query, selection, submission, and sort callbacks', function()
        local calls = {}
        local panel = make_panel(calls)
        local result = {unit_id=42}
        panel.subviews.search_field.on_change('miner')
        panel.subviews.result_list.on_select(1, {result=result})
        panel.subviews.result_list.on_submit(1, {result=result})
        panel.subviews.result_columns.getMousePos=function() return 0, 0 end
        test.assert_true(panel.subviews.result_columns:onInput{_MOUSE_L=true})
        test.assert_equal('miner', calls.query)
        test.assert_true(calls.selected == result)
        test.assert_true(calls.submitted == result)
        test.assert_equal('name', calls.sorted)
    end)

    test.case('results panel: exposes narrow update, navigation, and tooltip APIs', function()
        local panel = make_panel({})
        local result = {unit_id=7}
        panel:set_query_text('smith')
        panel:set_header_text('Results (1)', '-----------', 'columns')
        panel:set_choices({{result=result}}, 1)
        panel:move_cursor(-10)
        panel.subviews.result_columns.getMousePos=function() return 55, 0 end
        test.assert_equal('smith', panel.subviews.search_field.text)
        test.assert_equal('Results (1)', panel.subviews.result_header.text)
        test.assert_equal(1, panel:get_selected_index())
        test.assert_true(panel:get_selected_result() == result)
        test.assert_equal(-10, panel.subviews.result_list.cursor_delta)
        test.assert_equal('Sort by unit ID.', panel:get_header_tooltip())
    end)
end
