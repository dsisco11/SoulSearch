local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('UI layout', function()

    local layout = soulsearch_env.load_ui_layout(repo_root)
    local stats_layout = soulsearch_env.load_stats_layout(repo_root)

    it('UI layout: baseline panel geometry is exact', function()
        assert.are.equal(110, layout.WINDOW_FRAME.w)
        assert.are.equal(45, layout.WINDOW_FRAME.h)
        assert.are.equal(90, layout.WINDOW_RESIZE_MIN.w)
        assert.are.equal(30, layout.WINDOW_RESIZE_MIN.h)
        assert.are.same({65}, layout.DIVIDER_XS)
        assert.are.equal(1, layout.RESULTS_LEFT)
        assert.are.equal(64, layout.RESULTS_WIDTH)
        assert.are.equal(67, layout.STATS_LEFT)
        assert.are.equal(layout.STATS_LEFT - 2, layout.DIVIDER_XS[1])
        assert.are.equal(5, layout.get_frame('result_columns').t)
        assert.are.equal(6, layout.get_frame('result_list').t)
        assert.are.equal(1, layout.get_frame('active_filter_count').l)
        assert.are.equal(12, layout.get_frame('filters_button').l)
        assert.are.equal(35, layout.RESULT_NAME_WIDTH)
        assert.are.equal(9, layout.RESULT_UNIT_ID_WIDTH)
        assert.are.equal(18, layout.RESULT_PROFESSION_WIDTH)
        assert.are.equal('name', layout.get_result_header_column(0, 0))
        assert.are.equal('name', layout.get_result_header_column(34, 0))
        assert.is_nil(layout.get_result_header_column(35, 0))
        assert.are.equal('profession', layout.get_result_header_column(36, 0))
        assert.are.equal('profession', layout.get_result_header_column(53, 0))
        assert.are.equal('unit_id', layout.get_result_header_column(55, 0))
        assert.is_nil(layout.get_result_header_column(64, 0))
    end)

    it('UI layout: returned frames cannot mutate metadata', function()
        local frame = layout.get_frame('result_list')
        frame.l = 999
        assert.are.equal(1, layout.get_frame('result_list').l)
    end)

    it('UI layout: candidate filter controls extend the filter panel in order', function()
        assert.are.equal(2, layout.get_frame('filter_panel').t)
        assert.are.equal(0, layout.get_frame('add_filter').t)
        assert.are.equal(1, layout.get_frame('add_skill').t)
        assert.are.equal(2, layout.get_frame('add_race').t)
        assert.are.equal(3, layout.get_frame('clear_filters').t)
        assert.are.equal(layout.get_frame('add_filter').w,
            layout.get_frame('clear_filters').w)
        assert.are.equal(4, layout.get_frame('presets').t)
        assert.are.equal(5, layout.get_frame('add_unit_scope').t)
        assert.are.equal(layout.get_frame('add_filter').w,
            layout.get_frame('add_unit_scope').w)
        assert.are.equal(7, layout.get_frame('filter_list').t)
    end)

    it('UI layout: filter actions retain width and total zone', function()
        assert.are.equal(3, layout.FILTER_ACTION_WIDTH)
        assert.are.equal(15, layout.FILTER_ACTION_ZONE_WIDTH)
        assert.are.equal(5, #layout.FILTER_ACTIONS)
        for _, action in ipairs(layout.FILTER_ACTIONS) do
            assert.are.equal(3, action.width)
            assert.are.equal(3, #action.label)
        end
        assert.are.same({
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

    it('UI layout: every filter action boundary maps from metadata', function()
        local expected = {'plus', 'minus', 'up', 'down', 'remove'}
        local start = layout.ACTIVE_FILTER_BUTTON_START_X
        assert.is_nil(layout.get_filter_action_at_x(start - 1))
        for index, action_id in ipairs(expected) do
            local left = start + (index - 1) * layout.FILTER_ACTION_WIDTH
            local right = left + layout.FILTER_ACTION_WIDTH - 1
            assert.are.equal(action_id, layout.get_filter_action_at_x(left).id)
            assert.are.equal(action_id, layout.get_filter_action_at_x(right).id)
        end
        assert.is_nil(layout.get_filter_action_at_x(
            start + layout.FILTER_ACTION_ZONE_WIDTH))
    end)

    it('UI layout: stats header boundaries are exact', function()
        assert.are.equal('label', stats_layout.get_header_column(0, 0))
        assert.are.equal('label', stats_layout.get_header_column(22, 0))
        assert.is_nil(stats_layout.get_header_column(23, 0))
        assert.is_nil(stats_layout.get_header_column(25, 0))
        assert.are.equal('value', stats_layout.get_header_column(26, 0))
        assert.are.equal('value', stats_layout.get_header_column(32, 0))
        assert.is_nil(stats_layout.get_header_column(33, 0))
        assert.is_nil(stats_layout.get_header_column(2, 1))
    end)

    it('UI layout: stats delta cells use the scrolling records', function()
        assert.is_truthy(stats_layout.is_value_cell(26, 0))
        assert.is_truthy(stats_layout.is_value_cell(26, 1))
        assert.is_truthy(stats_layout.is_value_cell(26, 2))
        assert.is_truthy(stats_layout.is_value_cell(32, 8))
        assert.is_falsy(stats_layout.is_value_cell(33, 2))
        assert.is_falsy(stats_layout.is_value_cell(25, 2))
    end)

    it('UI layout: stats labels exclude their values', function()
        assert.is_truthy(stats_layout.is_label_cell(2, 0))
        assert.is_truthy(stats_layout.is_label_cell(25, 5))
        assert.is_falsy(stats_layout.is_label_cell(26, 0))
    end)

end)