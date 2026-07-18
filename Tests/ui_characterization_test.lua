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

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local ui, new_window, state, main_window, main_screen =
        soulsearch_env.load_ui_characterization(repo_root)

    add_test('UI characterization: root and recursive child order is exact', function()
        local window = new_window()
        luaunit.assertEquals({
            'results_panel',
            'filters_button',
            'active_filter_count',
            'stats_panel',
            'results_stats_divider',
            'view_in_creatures_button',
            'close_button',
            'filter_panel_window',
        }, ids(window.subviews))
        luaunit.assertEquals({
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
            'view_in_creatures_button',
            'close_button',
            'filter_panel_window',
            'close_filter_panel_button',
            'add_filter_button',
            'add_skill_button',
            'add_race_button',
            'clear_filters_button',
            'preset_button',
            'add_unit_scope_button',
            'filter_list',
            'available_filter_window',
            'close_filter_picker_button',
            'attribute_search_field',
            'available_filter_list',
            'available_race_window',
            'close_race_picker_button',
            'race_search_field',
            'available_race_list',
            'available_unit_scope_window',
            'close_unit_scope_picker_button',
            'unit_scope_search_field',
            'available_unit_scope_list',
            'available_skill_window',
            'close_skill_picker_button',
            'skill_search_field',
            'available_skill_list',
            'preset_picker_window',
            'close_preset_picker_button',
            'save_preset_button',
            'preset_search_field',
            'preset_list',
        }, recursive_ids(window))
    end)

    add_test('UI characterization: every descendant ID is exposed at the root', function()
        local window = new_window()
        for _, id in ipairs(recursive_ids(window)) do
            luaunit.assertEvalToTrue(window.subviews[id] ~= nil, 'missing descendant: ' .. id)
            luaunit.assertIs(id, window.subviews[id].view_id)
        end
        luaunit.assertEvalToTrue(window.subviews.available_filter_list.parent_view ==
            window.subviews.available_filter_window)
        luaunit.assertEvalToTrue(window.subviews.filter_list.parent_view ==
            window.subviews.filter_panel_window)
        luaunit.assertEvalToTrue(window.subviews.result_list.parent_view ==
            window.subviews.results_panel)
    end)

    add_test('UI characterization: query focus position and cursor shortcuts are stable', function()
        local window = new_window()
        luaunit.assertIs('results_panel', window.subviews[1].view_id)
        luaunit.assertIs('search_field', window.subviews.results_panel.subviews[1].view_id)
        luaunit.assertEvalToTrue(window.subviews.search_field.modal)
        luaunit.assertIs('CUSTOM_F', window.subviews.search_field.key)

        local expected = {
            {keys={KEYBOARD_CURSOR_UP=true}, delta=-1},
            {keys={KEYBOARD_CURSOR_DOWN=true}, delta=1},
            {keys={KEYBOARD_CURSOR_UP_FAST=true}, delta=-10},
            {keys={KEYBOARD_CURSOR_DOWN_FAST=true}, delta=10},
        }
        for _, item in ipairs(expected) do
            window.subviews.result_list.cursor_delta = nil
            luaunit.assertEvalToTrue(window:onInput(item.keys))
            luaunit.assertIs(item.delta, window.subviews.result_list.cursor_delta)
        end
    end)

    add_test('UI characterization: picker visibility is exclusive and unit-scope picker paints before presets', function()
        local window = new_window()
        local panel = window.subviews.filter_panel_window
        luaunit.assertIs('preset_picker_window',
            panel.subviews[#panel.subviews].view_id)

        panel:open()
        panel:toggle_picker('attribute')
        luaunit.assertEvalToTrue(window.subviews.available_filter_window.visible)
        luaunit.assertEvalToFalse(window.subviews.filter_list.visible())
        panel:toggle_picker('skill')
        luaunit.assertEvalToTrue(window.subviews.available_skill_window.visible)
        luaunit.assertEvalToFalse(window.subviews.available_filter_window.visible)
        panel:toggle_picker('unit_scope')
        luaunit.assertEvalToTrue(window.subviews.available_unit_scope_window.visible)
        luaunit.assertEvalToFalse(window.subviews.filter_list.visible())
    end)

    add_test('UI characterization: picker transitions close competing state', function()
        local window = new_window()
        local panel = window.subviews.filter_panel_window

        window:toggle_add_filter_dropdown()
        luaunit.assertEvalToTrue(panel:is_picker_open('attribute'))

        window:toggle_add_skill_dropdown()
        luaunit.assertEvalToTrue(panel:is_picker_open('skill'))

        window:toggle_add_unit_scope_dropdown()
        luaunit.assertEvalToTrue(panel:is_picker_open('unit_scope'))

        window:toggle_preset_picker()
        luaunit.assertEvalToTrue(panel:is_picker_open('preset'))
        luaunit.assertEvalToTrue(window:close_preset_picker())
        luaunit.assertEvalToFalse(panel:has_open_picker())

        panel:open()
        panel:toggle_picker('race')
        luaunit.assertEvalToTrue(window:close_filter_panel_state())
        luaunit.assertEvalToFalse(panel:is_open())
        luaunit.assertEvalToFalse(panel:has_open_picker())
    end)

    add_test('UI characterization: adding a filter keeps its picker open', function()
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
                luaunit.assertIs('skill:MINING', id)
                return 2
            end,
            on_filter_state_changed=function(_, index)
                table.insert(state_changes, index)
            end,
        }, {__index=main_window.SoulSearchWindow})

        luaunit.assertEvalToTrue(window:toggle_filter('skill:MINING'))
        luaunit.assertEvalToTrue(window:toggle_filter('skill:MINING'))
        luaunit.assertIs(0, close_calls)
        luaunit.assertEquals({2, 1}, state_changes)
    end)

    add_test('UI characterization: opening filter defaults are captured by value', function()
        local settings = {
            settings_id='creatures:visitors', explicit={},
            frame={l=1, t=2, w=110, h=45},
            filters={{id='unit_scope:visitors', direction='high'}},
            result_sort={key=nil, reverse=false, phase=0}, stats_sort={},
        }
        local window = new_window(settings)
        settings.filters[1].id = 'skill:MINING'
        window.session:replace_filters({
            {id='race:group:HUMANOIDS', direction='low'},
        })

        luaunit.assertEvalToTrue(window:clear_filters())
        local restored = window.session:get_filters()
        luaunit.assertIs(1, #restored)
        luaunit.assertIs('unit_scope:visitors', restored[1].id)
        luaunit.assertIs('high', restored[1].direction)
    end)

    add_test('UI characterization: clear restores opening defaults and presets refresh unified state once', function()
        local requests, picker_closes = {}, 0
        local session = {
            filters={{id='skill:MINING', direction='high'}},
            replace_filters=function(self, filters)
                if self.filters[1] and filters[1] and
                        self.filters[1].id == filters[1].id and
                        self.filters[1].direction == filters[1].direction then
                    return false
                end
                self.filters = filters
                return true
            end,
            get_filters=function(self) return self.filters end,
        }
        local window = setmetatable({
            session=session,
            default_filters={{id='unit_scope:citizens', direction='high'}},
            subviews={filter_panel_window={close_picker=function()
                picker_closes = picker_closes + 1
            end}},
            update_session_settings=function(_, settings)
                luaunit.assertEvalToTrue(settings.filters == session.filters)
            end,
            refresh_views=function(_, request)
                table.insert(requests, request)
            end,
        }, {__index=main_window.SoulSearchWindow})
        luaunit.assertEvalToTrue(window:clear_filters())
        luaunit.assertIs(1, picker_closes)
        luaunit.assertIs(1, #requests)
        luaunit.assertIs('unit_scope:citizens', session.filters[1].id)
        luaunit.assertIs('high', session.filters[1].direction)
        luaunit.assertEvalToTrue(requests[1].active_filters)
        luaunit.assertEvalToTrue(requests[1].pickers)
        luaunit.assertEvalToTrue(requests[1].candidates)
        luaunit.assertEvalToTrue(requests[1].results)
        luaunit.assertEvalToTrue(window:apply_loaded_filter_preset({
            {id='skill:MINING', direction='high'},
        }) == nil)
        luaunit.assertIs(2, picker_closes)
        luaunit.assertIs(2, #requests)
        luaunit.assertIs('skill:MINING', session.filters[1].id)
        luaunit.assertEvalToTrue(requests[2].active_filters)
        luaunit.assertEvalToTrue(requests[2].pickers)
        luaunit.assertEvalToTrue(requests[2].candidates)
        luaunit.assertEvalToTrue(requests[2].results)
    end)

    add_test('UI characterization: Main Window delegates through component APIs', function()
        local window = new_window()
        local calls = {}
        window.subviews.filter_panel_window = {
            set_active_filter_choices=function(_, choices, selected)
                calls.active = {choices=choices, selected=selected}
            end,
            set_picker_choices=function(_, kind, choices, selected)
                calls.picker = {kind=kind, choices=choices, selected=selected}
            end,
        }
        window.subviews.active_filter_count = {
            setText=function(_, text) calls.filter_count = text end,
        }

        window:refresh_active_filter_choices()
        luaunit.assertIs('Filters: 0', calls.filter_count)
    luaunit.assertIs('Use Add attribute, Add skill, or Add race.',
        calls.active.choices[1].text)
        window:update_available_filter_choices()
        luaunit.assertIs('attribute', calls.picker.kind)
        luaunit.assertIs('No matching attributes.', calls.picker.choices[1].text)
        window:update_available_unit_scope_choices()
        luaunit.assertIs('unit_scope', calls.picker.kind)

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
        luaunit.assertIs('Results (1)', result_calls.header[1])
        luaunit.assertIs(1, result_calls.choices.selected)

        window.subviews.stats_panel = {
            set_subject=function(_, subject) calls.stats_subject = subject end,
        }
        local result = {unit_id=1}
        window:refresh_stats(result)
        luaunit.assertEvalToTrue(calls.stats_subject == result)
    end)

    add_test('UI characterization: filter button owns its static tooltip', function()
        local window = new_window()
        luaunit.assertIs('Edit the current filters.',
            window.subviews.filters_button.tooltip)
        luaunit.assertIs('Close', window.subviews.close_button.tooltip)
        luaunit.assertIs('View the selected unit in the native Creatures panel.',
            window.subviews.view_in_creatures_button.tooltip)
    end)

    add_test('UI characterization: Creatures button dismisses then navigates by unit ID', function()
        local window = new_window()
        local log_start = #state.creatures_navigation_logs
        local events = {}
        window.parent_view = {dismiss=function()
            table.insert(events, 'dismiss')
        end}
        window.subviews.result_list:setChoices({
            {result={unit_id=42, name='Urist'}},
        }, 1)

        window.subviews.view_in_creatures_button.on_activate()
        table.insert(events, 'navigate:' .. state.creatures_navigation[1])
        luaunit.assertEquals({'dismiss', 'navigate:42'}, events)
        luaunit.assertIs(
            'View in Creatures TextButton activated',
            state.creatures_navigation_logs[log_start + 1])
        luaunit.assertIs(
            'view_selected_unit_in_creatures entered',
            state.creatures_navigation_logs[log_start + 2])
        luaunit.assertIs(
            'selected result resolved to unit 42',
            state.creatures_navigation_logs[log_start + 3])
    end)

    add_test('UI characterization: recompute retains selection by unit ID', function()
        local window = new_window()
        window.subviews.result_list:setChoices({
            {result={unit_id=20, name='Old selection'}},
        }, 1)
        state.results = {
            {unit_id=10, name='First', profession='Miner'},
            {unit_id=20, name='Retained', profession='Carpenter'},
        }
        local selected = window:recompute_results()
        luaunit.assertIs(20, selected.unit_id)
        luaunit.assertIs(2, window.subviews.result_list.selected)
        luaunit.assertIs('Results (2)', window.subviews.result_header.text)
        luaunit.assertEvalToTrue(state.last_sort.results == state.results)
    end)

    add_test('UI characterization: result callbacks submit and sort exact payloads', function()
        local window = new_window()
        local result = {unit_id=42, name='Urist', unit={position={x=1, y=2, z=3}}}
        window.subviews.result_list.on_submit(1, {result=result})
        luaunit.assertEquals({1, 2, 3}, {
            state.revealed[1].x, state.revealed[1].y, state.revealed[1].z,
        })

        local requests = {}
        window.refresh_views=function(_, request) table.insert(requests, request) end
        window.subviews.result_list.on_select(1, {result=result})
        luaunit.assertEvalToTrue(requests[1].stats)
        luaunit.assertEvalToTrue(requests[1].result == result)
        window.subviews.result_columns.on_change()
        luaunit.assertIs('name', window.session:get_result_sort().key)
        luaunit.assertEvalToFalse(window.session:get_result_sort().reverse)
        luaunit.assertIs(1, window.session:get_result_sort().phase)
        window:cycle_result_sort('name')
        luaunit.assertEvalToTrue(window.session:get_result_sort().reverse)
        window:cycle_result_sort('name')
        luaunit.assertNil(window.session:get_result_sort().key)
        luaunit.assertIs(4, #requests)
    end)

    add_test('UI characterization: drag persistence is isolated by settings ID', function()
        local first = new_window({
            settings_id='first', explicit={}, frame={l=1, t=2, w=100, h=40},
            filters={},
            result_sort={key=nil, reverse=false, phase=0}, stats_sort={},
        })
        local second = new_window({
            settings_id='second', explicit={}, frame={l=3, t=4, w=90, h=35},
            filters={},
            result_sort={key=nil, reverse=false, phase=0}, stats_sort={},
        })
        state.settings_updates = {}
        first.frame_rect = {x1=11, y1=12, width=101, height=41}
        first:onDragBegin()
        luaunit.assertEquals({11, 12, 101, 41},
            {first.frame.l, first.frame.t, first.frame.w, first.frame.h})
        luaunit.assertEvalToTrue(first:persist_frame_if_needed())
        luaunit.assertEvalToFalse(second:persist_frame_if_needed())
        second.frame.w = 91
        luaunit.assertEvalToTrue(second:persist_frame_if_needed())
        luaunit.assertIs('first', state.settings_updates[1].id)
        luaunit.assertIs('second', state.settings_updates[2].id)
    end)

    add_test('UI characterization: screen registration and cleanup are idempotent', function()
        local registry = state.screen_registry
        registry.clear()
        luaunit.assertIs('soulsearch', main_screen.SoulSearchScreen.attrs.focus_path)
        local persists = 0
        local screen = {window={persist_frame_if_needed=function()
            persists = persists + 1
        end}}
        setmetatable(screen, {__index=main_screen.SoulSearchScreen})
        screen:onShow()
        luaunit.assertIs(1, registry.count())
        luaunit.assertEvalToTrue(screen:cleanup())
        luaunit.assertEvalToFalse(screen:cleanup())
        screen:onDismiss()
        screen:onDestroy()
        luaunit.assertIs(1, persists)
        luaunit.assertIs(0, registry.count())
    end)

return native_tests
