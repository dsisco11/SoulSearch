local soulsearch_env = require('support.soulsearch_env')

local function ids(views)
    local result = {}
    for _, view in ipairs(views or {}) do
        table.insert(result, view.view_id)
    end
    return result
end

local function recursive_ids(view, result)
    result = result or {}
    for _, child in ipairs(view.subviews or {}) do
        table.insert(result, child.view_id)
        recursive_ids(child, result)
    end
    return result
end

return function(test, repo_root)
    local ui, new_window, state, _, main_screen =
        soulsearch_env.load_ui_characterization(repo_root)

    test.case('UI characterization: root and recursive child order is exact', function()
        local window = new_window()
        test.assert_sequence({
            'results_panel',
            'filters_button',
            'active_filter_count',
            'stats_panel',
            'close_button',
            'filter_panel_window',
        }, ids(window.subviews))
        test.assert_sequence({
            'results_panel',
            'search_field',
            'result_header',
            'result_header_underline',
            'result_columns',
            'result_list',
            'filters_button',
            'active_filter_count',
            'stats_panel',
            'close_button',
            'filter_panel_window',
            'close_filter_panel_button',
            'unit_scope_label',
            'unit_scope_edit',
            'add_filter_button',
            'add_skill_button',
            'add_race_button',
            'clear_filters_button',
            'preset_button',
            'filter_list',
            'available_filter_window',
            'close_filter_picker_button',
            'attribute_search_field',
            'available_filter_list',
            'available_race_window',
            'close_race_picker_button',
            'race_search_field',
            'available_race_list',
            'available_skill_window',
            'close_skill_picker_button',
            'skill_search_field',
            'available_skill_list',
            'preset_picker_window',
            'close_preset_picker_button',
            'save_preset_button',
            'preset_search_field',
            'preset_list',
            'unit_scope_picker_window',
            'unit_scope_picker_list',
        }, recursive_ids(window))
    end)

    test.case('UI characterization: every descendant ID is exposed at the root', function()
        local window = new_window()
        for _, id in ipairs(recursive_ids(window)) do
            test.assert_true(window.subviews[id] ~= nil, 'missing descendant: ' .. id)
            test.assert_equal(id, window.subviews[id].view_id)
        end
        test.assert_true(window.subviews.available_filter_list.parent_view ==
            window.subviews.available_filter_window)
        test.assert_true(window.subviews.filter_list.parent_view ==
            window.subviews.filter_panel_window)
        test.assert_true(window.subviews.result_list.parent_view ==
            window.subviews.results_panel)
    end)

    test.case('UI characterization: query focus position and cursor shortcuts are stable', function()
        local window = new_window()
        test.assert_equal('results_panel', window.subviews[1].view_id)
        test.assert_equal('search_field', window.subviews.results_panel.subviews[1].view_id)
        test.assert_true(window.subviews.search_field.modal)
        test.assert_equal('CUSTOM_F', window.subviews.search_field.key)

        local expected = {
            {keys={KEYBOARD_CURSOR_UP=true}, delta=-1},
            {keys={KEYBOARD_CURSOR_DOWN=true}, delta=1},
            {keys={KEYBOARD_CURSOR_UP_FAST=true}, delta=-10},
            {keys={KEYBOARD_CURSOR_DOWN_FAST=true}, delta=10},
        }
        for _, item in ipairs(expected) do
            window.subviews.result_list.cursor_delta = nil
            test.assert_true(window:onInput(item.keys))
            test.assert_equal(item.delta, window.subviews.result_list.cursor_delta)
        end
    end)

    test.case('UI characterization: picker visibility is exclusive and scope paints last', function()
        local window = new_window()
        local panel = window.subviews.filter_panel_window
        test.assert_equal('unit_scope_picker_window',
            panel.subviews[#panel.subviews].view_id)

        window.filter_panel_open = true
        window.add_filter_open = true
        test.assert_true(window.subviews.available_filter_window.visible())
        test.assert_false(window.subviews.filter_list.visible())
        window.add_filter_open = false
        window.add_skill_open = true
        test.assert_true(window.subviews.available_skill_window.visible())
        test.assert_false(window.subviews.available_filter_window.visible())
        window.add_skill_open = false
        window.unit_scope_picker_open = true
        test.assert_true(window.subviews.unit_scope_picker_window.visible())
        test.assert_false(window.subviews.filter_list.visible())
    end)

    test.case('UI characterization: tooltip precedence and exact copy are stable', function()
        local window = new_window()
        local filters_button = window.subviews.filters_button
        filters_button.frame_body = {
            inClipGlobalXY=function() return true end,
        }
        state.mouse_x, state.mouse_y = 1, 1
        test.assert_equal('Edit the current filters.', window:get_tooltip_text())

        filters_button.frame_body = nil
        window.get_filter_action_tooltip=function() return 'filter action' end
        window.get_result_header_tooltip=function() return 'result header' end
        window.subviews.stats_panel.tooltip_text = 'stats'
        window.get_filter_descriptor_tooltip=function() return 'descriptor' end
        test.assert_equal('filter action', window:get_tooltip_text())
        window.get_filter_action_tooltip=function() return nil end
        test.assert_equal('result header', window:get_tooltip_text())
        window.get_result_header_tooltip=function() return nil end
        test.assert_equal('stats', window:get_tooltip_text())
        window.subviews.stats_panel.tooltip_text = nil
        test.assert_equal('descriptor', window:get_tooltip_text())
    end)

    test.case('UI characterization: recompute retains selection by unit ID', function()
        local window = new_window()
        window.subviews.result_list:setChoices({
            {result={unit_id=20, name='Old selection'}},
        }, 1)
        state.results = {
            {unit_id=10, name='First', profession='Miner'},
            {unit_id=20, name='Retained', profession='Carpenter'},
        }
        local selected = window:recompute_results()
        test.assert_equal(20, selected.unit_id)
        test.assert_equal(2, window.subviews.result_list.selected)
        test.assert_equal('Results (2)', window.subviews.result_header.text)
        test.assert_true(state.last_sort.results == state.results)
    end)

    test.case('UI characterization: result callbacks submit and sort exact payloads', function()
        local window = new_window()
        local result = {unit_id=42, name='Urist', unit={position={x=1, y=2, z=3}}}
        window.subviews.result_list.on_submit(1, {result=result})
        test.assert_sequence({1, 2, 3}, {
            state.revealed[1].x, state.revealed[1].y, state.revealed[1].z,
        })

        local requests = {}
        window.refresh_views=function(_, request) table.insert(requests, request) end
        window.subviews.result_list.on_select(1, {result=result})
        test.assert_true(requests[1].stats)
        test.assert_true(requests[1].result == result)
        window.subviews.result_columns.mouse_x = 0
        window.subviews.result_columns.mouse_y = 0
        test.assert_true(window.subviews.result_columns:onInput{_MOUSE_L=true})
        test.assert_equal('name', window.result_sort_key)
        test.assert_false(window.result_sort_reverse)
        test.assert_equal(1, window.result_sort_phase)
        window:cycle_result_sort('name')
        test.assert_true(window.result_sort_reverse)
        window:cycle_result_sort('name')
        test.assert_nil(window.result_sort_key)
        test.assert_equal(4, #requests)
    end)

    test.case('UI characterization: drag persistence is isolated by settings ID', function()
        local first = new_window({
            settings_id='first', explicit={}, frame={l=1, t=2, w=100, h=40},
            filters={}, unit_scope='fort_residents',
            result_sort={key=nil, reverse=false, phase=0}, stats_sort={},
        })
        local second = new_window({
            settings_id='second', explicit={}, frame={l=3, t=4, w=90, h=35},
            filters={}, unit_scope='fort_residents',
            result_sort={key=nil, reverse=false, phase=0}, stats_sort={},
        })
        state.settings_updates = {}
        first.frame_rect = {x1=11, y1=12, width=101, height=41}
        first:onDragBegin()
        test.assert_sequence({11, 12, 101, 41},
            {first.frame.l, first.frame.t, first.frame.w, first.frame.h})
        test.assert_true(first:persist_frame_if_needed())
        test.assert_false(second:persist_frame_if_needed())
        second.frame.w = 91
        test.assert_true(second:persist_frame_if_needed())
        test.assert_equal('first', state.settings_updates[1].id)
        test.assert_equal('second', state.settings_updates[2].id)
    end)

    test.case('UI characterization: screen registration and cleanup are idempotent', function()
        local registry = state.screen_registry
        registry.clear()
        test.assert_equal('soulsearch', main_screen.SoulSearchScreen.attrs.focus_path)
        local persists = 0
        local screen = {window={persist_frame_if_needed=function()
            persists = persists + 1
        end}}
        setmetatable(screen, {__index=main_screen.SoulSearchScreen})
        screen:onShow()
        test.assert_equal(1, registry.count())
        test.assert_true(screen:cleanup())
        test.assert_false(screen:cleanup())
        screen:onDismiss()
        screen:onDestroy()
        test.assert_equal(1, persists)
        test.assert_equal(0, registry.count())
    end)
end
