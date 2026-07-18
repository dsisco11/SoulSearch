local env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('unit stats list: owns sortable records, scrolling, and declared header tooltips', function()
        local UnitStatsList = env.load_unit_stats_list(root)
        local changes = {}
        local list = UnitStatsList{subject={row={}, unit={}},
            sort={key='label', reverse=false, phase=1},
            on_sort_change=function(sort) table.insert(changes, sort) end}
        luaunit.assertIs(26, list.columns_layout.value_column_x)
        luaunit.assertIs(1, list.subviews.body.frame.t)
        luaunit.assertNil(list.subviews.columns_underline)
        list.subviews.body.start_line_num = 9
        list:reset_view_state({key='value', reverse=true, phase=1})
        luaunit.assertIs(1, list.subviews.body.start_line_num)
        list:cycle_sort('label')
        luaunit.assertIs(1, #changes)
        luaunit.assertIs('label', list:get_sort().key)
        list:set_header_height(2)
        luaunit.assertIs(2, list.subviews.columns.frame.h)
        luaunit.assertIs(2, list.subviews.body.frame.t)
        luaunit.assertIs('Sort by stat name.', list.subviews.columns.tooltip)
        luaunit.assertIs('Sort by baseline difference.', list.subviews.value_column.tooltip)
        list:update_body_tooltip(list.subviews.body, 2, 0)
        luaunit.assertIs('trait:PATIENCE', list.subviews.body.tooltip)
        list:update_body_tooltip(list.subviews.body, 99, 0)
        luaunit.assertIs(nil, list.subviews.body.tooltip)

        local underlined = UnitStatsList{subject={row={}, unit={}},
            show_header_underline=true, adaptive_columns=true}
        luaunit.assertIs(2, underlined.subviews.body.frame.t)
        luaunit.assertIs(string.char(196):rep(26),
            underlined.subviews.columns_underline.text)
        luaunit.assertIs(string.char(196):rep(7),
            underlined.subviews.value_underline.text)
    end)

return native_tests
