local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local layout = soulsearch_env.load_ui_layout(repo_root)
    local stats_layout = soulsearch_env.load_stats_layout(repo_root)

    add_test('UI layout: baseline panel geometry is exact', function()
        luaunit.assertIs(110, layout.WINDOW_FRAME.w)
        luaunit.assertIs(45, layout.WINDOW_FRAME.h)
        luaunit.assertIs(90, layout.WINDOW_RESIZE_MIN.w)
        luaunit.assertIs(30, layout.WINDOW_RESIZE_MIN.h)
        luaunit.assertEquals({65}, layout.DIVIDER_XS)
        luaunit.assertIs(1, layout.RESULTS_LEFT)
        luaunit.assertIs(64, layout.RESULTS_WIDTH)
        luaunit.assertIs(67, layout.STATS_LEFT)
        luaunit.assertIs(layout.STATS_LEFT - 2, layout.DIVIDER_XS[1])
        luaunit.assertIs(5, layout.get_frame('result_columns').t)
        luaunit.assertIs(6, layout.get_frame('result_list').t)
        luaunit.assertIs(1, layout.get_frame('active_filter_count').l)
        luaunit.assertIs(12, layout.get_frame('filters_button').l)
        luaunit.assertIs(35, layout.RESULT_NAME_WIDTH)
        luaunit.assertIs(9, layout.RESULT_UNIT_ID_WIDTH)
        luaunit.assertIs(18, layout.RESULT_PROFESSION_WIDTH)
        luaunit.assertIs('name', layout.get_result_header_column(0, 0))
        luaunit.assertIs('name', layout.get_result_header_column(34, 0))
        luaunit.assertNil(layout.get_result_header_column(35, 0))
        luaunit.assertIs('profession', layout.get_result_header_column(36, 0))
        luaunit.assertIs('profession', layout.get_result_header_column(53, 0))
        luaunit.assertIs('unit_id', layout.get_result_header_column(55, 0))
        luaunit.assertNil(layout.get_result_header_column(64, 0))
    end)

    add_test('UI layout: returned frames cannot mutate metadata', function()
        local frame = layout.get_frame('result_list')
        frame.l = 999
        luaunit.assertIs(1, layout.get_frame('result_list').l)
    end)

    add_test('UI layout: candidate filter controls extend the filter panel in order', function()
        luaunit.assertIs(2, layout.get_frame('filter_panel').t)
        luaunit.assertIs(0, layout.get_frame('add_filter').t)
        luaunit.assertIs(1, layout.get_frame('add_skill').t)
        luaunit.assertIs(2, layout.get_frame('add_race').t)
        luaunit.assertIs(3, layout.get_frame('clear_filters').t)
        luaunit.assertIs(layout.get_frame('add_filter').w,
            layout.get_frame('clear_filters').w)
        luaunit.assertIs(4, layout.get_frame('presets').t)
        luaunit.assertIs(5, layout.get_frame('add_unit_scope').t)
        luaunit.assertIs(layout.get_frame('add_filter').w,
            layout.get_frame('add_unit_scope').w)
        luaunit.assertIs(7, layout.get_frame('filter_list').t)
    end)

    add_test('UI layout: filter actions retain width and total zone', function()
        luaunit.assertIs(3, layout.FILTER_ACTION_WIDTH)
        luaunit.assertIs(15, layout.FILTER_ACTION_ZONE_WIDTH)
        luaunit.assertIs(5, #layout.FILTER_ACTIONS)
        for _, action in ipairs(layout.FILTER_ACTIONS) do
            luaunit.assertIs(3, action.width)
            luaunit.assertIs(3, #action.label)
        end
        luaunit.assertEquals({
            layout.FILTER_ACTION.SET_HIGH,
            layout.FILTER_ACTION.SET_LOW,
            layout.FILTER_ACTION.MOVE_UP,
            layout.FILTER_ACTION.MOVE_DOWN,
            layout.FILTER_ACTION.REMOVE,
        }, (function()
            local callbacks = {}
            for _, action in ipairs(layout.FILTER_ACTIONS) do
                table.insert(callbacks, action.callback)
            end
            return callbacks
        end)())
    end)

    add_test('UI layout: every filter action boundary maps from metadata', function()
        local expected = {'plus', 'minus', 'up', 'down', 'remove'}
        local start = layout.ACTIVE_FILTER_BUTTON_START_X
        luaunit.assertNil(layout.get_filter_action_at_x(start - 1))
        for index, action_id in ipairs(expected) do
            local left = start + (index - 1) * layout.FILTER_ACTION_WIDTH
            local right = left + layout.FILTER_ACTION_WIDTH - 1
            luaunit.assertIs(action_id, layout.get_filter_action_at_x(left).id)
            luaunit.assertIs(action_id, layout.get_filter_action_at_x(right).id)
        end
        luaunit.assertNil(layout.get_filter_action_at_x(
            start + layout.FILTER_ACTION_ZONE_WIDTH))
    end)

    add_test('UI layout: stats header boundaries are exact', function()
        luaunit.assertIs('label', stats_layout.get_header_column(0, 0))
        luaunit.assertIs('label', stats_layout.get_header_column(22, 0))
        luaunit.assertNil(stats_layout.get_header_column(23, 0))
        luaunit.assertNil(stats_layout.get_header_column(25, 0))
        luaunit.assertIs('value', stats_layout.get_header_column(26, 0))
        luaunit.assertIs('value', stats_layout.get_header_column(32, 0))
        luaunit.assertNil(stats_layout.get_header_column(33, 0))
        luaunit.assertNil(stats_layout.get_header_column(2, 1))
    end)

    add_test('UI layout: stats delta cells use the scrolling records', function()
        luaunit.assertEvalToTrue(stats_layout.is_value_cell(26, 0))
        luaunit.assertEvalToTrue(stats_layout.is_value_cell(26, 1))
        luaunit.assertEvalToTrue(stats_layout.is_value_cell(26, 2))
        luaunit.assertEvalToTrue(stats_layout.is_value_cell(32, 8))
        luaunit.assertEvalToFalse(stats_layout.is_value_cell(33, 2))
        luaunit.assertEvalToFalse(stats_layout.is_value_cell(25, 2))
    end)

    add_test('UI layout: stats labels exclude their values', function()
        luaunit.assertEvalToTrue(stats_layout.is_label_cell(2, 0))
        luaunit.assertEvalToTrue(stats_layout.is_label_cell(25, 5))
        luaunit.assertEvalToFalse(stats_layout.is_label_cell(26, 0))
    end)

return native_tests
