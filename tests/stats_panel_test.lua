local env = require('support.soulsearch_env')
return function(test, root)
    test.case('stats panel: host API, ownership, layout, and tooltips are isolated', function()
        local Panel = env.load_stats_panel(root)
        local changes = {}
        local incoming = {key='label', reverse=false, phase=1}
        local panel = Panel{subject={row={}, unit={}}, sort=incoming,
            on_sort_change=function(sort) table.insert(changes, sort) end}
        incoming.key='value'
        test.assert_equal('label', panel:get_sort().key)
        local read = panel:get_sort(); read.key='value'
        test.assert_equal('label', panel:get_sort().key)
        panel:set_sort({key='value', phase=1})
        test.assert_equal(0, #changes)
        panel.subviews.body.start_line_num=9
        panel:reset_view_state({key='label', phase=1})
        test.assert_equal(1, panel.subviews.body.start_line_num)
        test.assert_equal(0, #changes)
        panel:cycle_sort('value')
        test.assert_equal(1, #changes)
        changes[1].key='label'
        test.assert_equal('value', panel:get_sort().key)
        panel:on_layout({height=12})
        test.assert_equal(2, panel.subviews.header.frame.t)
        panel.subviews.columns.mouse_x, panel.subviews.columns.mouse_y=0,0
        test.assert_equal('Sort by stat name.', panel:get_tooltip_text())
        panel.subviews.columns.mouse_x=nil
        panel.subviews.body.mouse_x, panel.subviews.body.mouse_y=2,0
        test.assert_equal('trait:PATIENCE', panel:get_tooltip_text())
    end)
end
