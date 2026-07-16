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
    local ui, new_window, state, main_window, main_screen =
        soulsearch_env.load_ui_characterization(repo_root)

    test.case('UI characterization: root and recursive child order is exact', function()
        local window = new_window()
        test.assert_sequence({
            'results_panel',
            'filters_button',
            'active_filter_count',
            'stats_panel',
            'results_stats_divider',
            'close_button',
            'filter_panel_window',
        }, ids(window.subviews))
        test.assert_sequence({
            'results_panel',
            'search_field',
            'result_header',
            'result_header_underline',
            'result_columns',
            'result_profession_column',
            'result_unit_id_column',
            'result_list',
            'filters_button',
            'active_filter_count',
            'stats_panel',
            'results_stats_divider',
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

        panel:open()
        panel:toggle_picker('attribute')
        test.assert_true(window.subviews.available_filter_window.visible)
        test.assert_false(window.subviews.filter_list.visible())
        panel:toggle_picker('skill')
        test.assert_true(window.subviews.available_skill_window.visible)
        test.assert_false(window.subviews.available_filter_window.visible)
        panel:toggle_picker('scope')
        test.assert_true(window.subviews.unit_scope_picker_window.visible)
        test.assert_false(window.subviews.filter_list.visible())
    end)

    test.case('UI characterization: picker transitions close competing state', function()
        local window = new_window()
        local panel = window.subviews.filter_panel_window

        window:toggle_add_filter_dropdown()
        test.assert_true(panel:is_picker_open('attribute'))

        window:toggle_add_skill_dropdown()
        test.assert_true(panel:is_picker_open('skill'))

        window:toggle_unit_scope_picker()
        test.assert_true(panel:is_picker_open('scope'))

        window:toggle_preset_picker()
        test.assert_true(panel:is_picker_open('preset'))
        test.assert_true(window:close_preset_picker())
        test.assert_false(panel:has_open_picker())

        panel:open()
        panel:toggle_picker('race')
        test.assert_true(window:close_filter_panel_state())
        test.assert_false(panel:is_open())
        test.assert_false(panel:has_open_picker())
    end)

    test.case('UI characterization: adding a filter keeps its picker open', function()
        local close_calls, state_changes = 0, {}
        local window = setmetatable({
            session={
                active=false,
                contains_filter=function(self) return self.active end,
                add_filter=function(self, id)
                    if id ~= 'skill:MINING' or self.active then return false end
                    self.active = true
                    return true
                end,
                remove_filter=function(self, id)
                    if id ~= 'skill:MINING' or not self.active then return false end
                    self.active = false
                    return true
                end,
                get_filter_priority=function() return 2 end,
                filter_count=function() return 0 end,
            },
            subviews={filter_panel_window={
                close_picker=function() close_calls = close_calls + 1 end,
            }},
            get_filter_choice_index=function(_, id)
                test.assert_equal('skill:MINING', id)
                return 2
            end,
            on_filter_state_changed=function(_, index)
                table.insert(state_changes, index)
            end,
        }, {__index=main_window.SoulSearchWindow})

        test.assert_true(window:toggle_filter('skill:MINING'))
        test.assert_true(window:toggle_filter('skill:MINING'))
        test.assert_equal(0, close_calls)
        test.assert_sequence({2, 1}, state_changes)
    end)

    test.case('UI characterization: Main Window delegates through component APIs', function()
        local window = new_window()
        local calls = {}
        window.subviews.filter_panel_window = {
            set_active_filter_choices=function(_, choices, selected)
                calls.active = {choices=choices, selected=selected}
            end,
            set_picker_choices=function(_, kind, choices, selected)
                calls.picker = {kind=kind, choices=choices, selected=selected}
            end,
            set_unit_scope_choices=function(_, choices, selected, label)
                calls.scope = {choices=choices, selected=selected, label=label}
            end,
        }
        window.subviews.active_filter_count = {
            setText=function(_, text) calls.filter_count = text end,
        }

        window:refresh_active_filter_choices()
        test.assert_equal('Filters: 1', calls.filter_count)
    test.assert_equal('Use Add attribute, Add skill, or Add race.',
        calls.active.choices[1].text)
        window:update_available_filter_choices()
        test.assert_equal('attribute', calls.picker.kind)
        test.assert_equal('No matching attributes.', calls.picker.choices[1].text)
        window:update_unit_scope_picker()
        test.assert_equal('Residents', calls.scope.label)

        local result_calls = {}
        window.subviews.results_panel = {
            get_selected_index=function() return 1 end,
            get_selected_result=function() return nil end,
            set_header_text=function(_, title, underline, columns)
                result_calls.header = {title, underline, columns}
            end,
            set_choices=function(_, choices, selected)
                result_calls.choices = {choices=choices, selected=selected}
            end,
        }
        state.results = {{unit_id=1, name='Urist', profession='Miner'}}
        window:recompute_results()
        test.assert_equal('Results (1)', result_calls.header[1])
        test.assert_equal(1, result_calls.choices.selected)

        window.subviews.stats_panel = {
            set_subject=function(_, subject) calls.stats_subject = subject end,
        }
        local result = {unit_id=1}
        window:refresh_stats(result)
        test.assert_true(calls.stats_subject == result)
    end)

    test.case('UI characterization: filter button owns its static tooltip', function()
        local window = new_window()
        test.assert_equal('Edit the current filters.',
            window.subviews.filters_button.tooltip)
        test.assert_equal('Close', window.subviews.close_button.tooltip)
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
        window.subviews.result_columns.on_change()
        test.assert_equal('name', window.session:get_result_sort().key)
        test.assert_false(window.session:get_result_sort().reverse)
        test.assert_equal(1, window.session:get_result_sort().phase)
        window:cycle_result_sort('name')
        test.assert_true(window.session:get_result_sort().reverse)
        window:cycle_result_sort('name')
        test.assert_nil(window.session:get_result_sort().key)
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
