local env = require('support.soulsearch_env')

local root = require('support.repo_root')

describe('unit stats list', function()

    it('unit stats list: owns sortable records, scrolling, and declared header tooltips', function()
        local UnitStatsList = env.load_unit_stats_list(root)
        local changes = {}
        local list = UnitStatsList{subject={row={}, unit={}},
            sort={key='label', reverse=false, phase=1},
            on_sort_change=function(sort) table.insert(changes, sort) end}
        assert.are.equal(26, list.columns_layout.value_column_x)
        assert.are.equal(1, list.subviews.body.frame.t)
        assert.is_nil(list.subviews.columns_underline)
        list.subviews.body.start_line_num = 9
        list:reset_view_state({key='value', reverse=true, phase=1})
        assert.are.equal(1, list.subviews.body.start_line_num)
        list:cycle_sort('label')
        assert.are.equal(1, #changes)
        assert.are.equal('label', list:get_sort().key)
        list:set_header_height(2)
        assert.are.equal(2, list.subviews.columns.frame.h)
        assert.are.equal(2, list.subviews.body.frame.t)
        assert.are.equal('Sort by stat name.', list.subviews.columns.tooltip)
        assert.are.equal('Sort by baseline difference.', list.subviews.value_column.tooltip)
        list:update_body_tooltip(list.subviews.body, 2, 0)
        assert.are.equal('trait:PATIENCE', list.subviews.body.tooltip)
        list:update_body_tooltip(list.subviews.body, 99, 0)
        assert.are.equal(nil, list.subviews.body.tooltip)

        local underlined = UnitStatsList{subject={row={}, unit={}},
            show_header_underline=true, adaptive_columns=true}
        assert.are.equal(2, underlined.subviews.body.frame.t)
        assert.are.equal(string.char(196):rep(26),
            underlined.subviews.columns_underline.text)
        assert.are.equal(string.char(196):rep(7),
            underlined.subviews.value_underline.text)
    end)

end)
