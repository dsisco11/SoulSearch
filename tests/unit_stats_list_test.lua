local env = require('support.soulsearch_env')

return function(test, root)
    test.case('unit stats list: owns sortable records, scrolling, and declared header tooltips', function()
        local UnitStatsList = env.load_unit_stats_list(root)
        local changes = {}
        local list = UnitStatsList{subject={row={}, unit={}},
            sort={key='label', reverse=false, phase=1},
            on_sort_change=function(sort) table.insert(changes, sort) end}
        list.subviews.body.start_line_num = 9
        list:reset_view_state({key='value', reverse=true, phase=1})
        test.assert_equal(1, list.subviews.body.start_line_num)
        list:cycle_sort('label')
        test.assert_equal(1, #changes)
        test.assert_equal('label', list:get_sort().key)
        list:set_header_height(2)
        test.assert_equal(2, list.subviews.columns.frame.h)
        test.assert_equal(2, list.subviews.body.frame.t)
        test.assert_equal('Sort by stat name.', list.subviews.columns.tooltip)
        test.assert_equal('Sort by baseline difference.', list.subviews.value_column.tooltip)
        list.subviews.body.mouse_x, list.subviews.body.mouse_y = 2, 0
        test.assert_equal('trait:PATIENCE', list:get_tooltip_text())
    end)
end
