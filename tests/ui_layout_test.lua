local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local layout = soulsearch_env.load_ui_layout(repo_root)

    test.case('UI layout: baseline panel geometry is exact', function()
        test.assert_equal(110, layout.WINDOW_FRAME.w)
        test.assert_equal(45, layout.WINDOW_FRAME.h)
        test.assert_equal(90, layout.WINDOW_RESIZE_MIN.w)
        test.assert_equal(30, layout.WINDOW_RESIZE_MIN.h)
        test.assert_sequence({65}, layout.DIVIDER_XS)
        test.assert_equal(1, layout.RESULTS_LEFT)
        test.assert_equal(64, layout.RESULTS_WIDTH)
        test.assert_equal(67, layout.STATS_LEFT)
        test.assert_equal(layout.STATS_LEFT - 2, layout.DIVIDER_XS[1])
        test.assert_equal(layout.STATS_LEFT, layout.get_frame('stats_header').l)
        test.assert_equal(layout.STATS_CONTENT_TOP,
            layout.get_frame('stats_header').t)
        test.assert_equal(5, layout.get_frame('result_columns').t)
        test.assert_equal(6, layout.get_frame('result_list').t)
        test.assert_equal(1, layout.get_frame('active_filter_count').l)
        test.assert_equal(12, layout.get_frame('filters_button').l)
        test.assert_equal(35, layout.RESULT_NAME_WIDTH)
        test.assert_equal(9, layout.RESULT_UNIT_ID_WIDTH)
        test.assert_equal(18, layout.RESULT_PROFESSION_WIDTH)
        test.assert_equal('name', layout.get_result_header_column(0, 0))
        test.assert_equal('name', layout.get_result_header_column(34, 0))
        test.assert_nil(layout.get_result_header_column(35, 0))
        test.assert_equal('profession', layout.get_result_header_column(36, 0))
        test.assert_equal('profession', layout.get_result_header_column(53, 0))
        test.assert_equal('unit_id', layout.get_result_header_column(55, 0))
        test.assert_nil(layout.get_result_header_column(64, 0))
    end)

    test.case('UI layout: returned frames cannot mutate metadata', function()
        local frame = layout.get_frame('result_list')
        frame.l = 999
        test.assert_equal(1, layout.get_frame('result_list').l)
    end)

    test.case('UI layout: race control extends the filter panel in order', function()
        test.assert_equal(2, layout.get_frame('filter_panel').t)
        test.assert_equal(6, layout.get_frame('unit_scope').t)
        test.assert_equal(6, layout.get_frame('unit_scope_edit').t)
        test.assert_equal(7, layout.get_frame('unit_scope_picker').t)
        test.assert_nil(layout.get_frame('unit_scope_picker').h)
        test.assert_equal(0, layout.get_frame('unit_scope_picker_list').t)
        test.assert_equal(4, layout.UNIT_SCOPE_PICKER_VERTICAL_PADDING)
        test.assert_equal(3 + layout.UNIT_SCOPE_PICKER_VERTICAL_PADDING,
            layout.get_unit_scope_picker_frame(3).h)
        test.assert_equal(10 + layout.UNIT_SCOPE_PICKER_VERTICAL_PADDING,
            layout.get_unit_scope_picker_frame(10).h)
        test.assert_equal(3, layout.get_unit_scope_picker_list_frame(3).h)
        test.assert_nil(layout.get_unit_scope_picker_list_frame(3).b)
        test.assert_equal(0, layout.get_frame('add_filter').t)
        test.assert_equal(1, layout.get_frame('add_skill').t)
        test.assert_equal(2, layout.get_frame('add_race').t)
        test.assert_equal(3, layout.get_frame('clear_filters').t)
        test.assert_equal(4, layout.get_frame('presets').t)
        test.assert_equal(7, layout.get_frame('filter_list').t)
    end)

    test.case('UI layout: filter actions retain width and total zone', function()
        test.assert_equal(3, layout.FILTER_ACTION_WIDTH)
        test.assert_equal(15, layout.FILTER_ACTION_ZONE_WIDTH)
        test.assert_equal(5, #layout.FILTER_ACTIONS)
        for _, action in ipairs(layout.FILTER_ACTIONS) do
            test.assert_equal(3, action.width)
            test.assert_equal(3, #action.label)
        end
    end)

    test.case('UI layout: every filter action boundary maps from metadata', function()
        local expected = {'plus', 'minus', 'up', 'down', 'remove'}
        local start = layout.ACTIVE_FILTER_BUTTON_START_X
        test.assert_nil(layout.get_filter_action_at_x(start - 1))
        for index, action_id in ipairs(expected) do
            local left = start + (index - 1) * layout.FILTER_ACTION_WIDTH
            local right = left + layout.FILTER_ACTION_WIDTH - 1
            test.assert_equal(action_id, layout.get_filter_action_at_x(left).id)
            test.assert_equal(action_id, layout.get_filter_action_at_x(right).id)
        end
        test.assert_nil(layout.get_filter_action_at_x(
            start + layout.FILTER_ACTION_ZONE_WIDTH))
    end)

    test.case('UI layout: stats header boundaries are exact', function()
        test.assert_equal('label', layout.get_stats_header_column(0, 0))
        test.assert_equal('label', layout.get_stats_header_column(23, 0))
        test.assert_nil(layout.get_stats_header_column(24, 0))
        test.assert_nil(layout.get_stats_header_column(26, 0))
        test.assert_equal('value', layout.get_stats_header_column(27, 0))
        test.assert_equal('value', layout.get_stats_header_column(33, 0))
        test.assert_nil(layout.get_stats_header_column(34, 0))
        test.assert_nil(layout.get_stats_header_column(2, 1))
    end)

    test.case('UI layout: stats delta cells use the scrolling records', function()
        test.assert_true(layout.is_stats_value_cell(27, 0))
        test.assert_true(layout.is_stats_value_cell(27, 1))
        test.assert_true(layout.is_stats_value_cell(27, 2))
        test.assert_true(layout.is_stats_value_cell(33, 8))
        test.assert_false(layout.is_stats_value_cell(34, 2))
        test.assert_false(layout.is_stats_value_cell(26, 2))
    end)

    test.case('UI layout: stats labels exclude their values', function()
        test.assert_true(layout.is_stats_label_cell(2, 0))
        test.assert_true(layout.is_stats_label_cell(26, 5))
        test.assert_false(layout.is_stats_label_cell(27, 0))
    end)
end
