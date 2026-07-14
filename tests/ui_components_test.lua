local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local components = soulsearch_env.load_ui_components(repo_root)
    local layout = soulsearch_env.load_ui_layout(repo_root)
    local noop = function() end
    local function by_id(views, id)
        for _, view in ipairs(views) do
            if view.view_id == id then return view end
        end
    end

    test.case('UI components: control tooltips explain non-obvious actions', function()
        test.assert_sequence({
            'Edit the current filters.',
            'Close',
            'Choose which units are included in the results.',
            'Add an attribute or trait to the ranking criteria.',
            'Add a skill to the ranking criteria.',
            'Add a race to the candidate scope.',
            'Save the current filters or load a custom, role, or skill preset.',
            'Save the current ordered filters under this preset name.',
            'Close',
            'Close',
            'Close',
            'Close',
        }, (function()
            local texts = {}
            for _, tooltip in ipairs(components.CONTROL_TOOLTIPS) do
                table.insert(texts, tooltip.text)
            end
            return texts
        end)())
    end)

    test.case('UI components: result header tooltip explains its sort', function()
        test.assert_equal('Sort by unit ID.',
            components.RESULT_HEADER_TOOLTIPS.unit_id)
    end)

    test.case('UI components: filter panel preserves child and picker order', function()
        local filter_panel_open = false
        local focused
        local views = components.create_filter_panel{
            is_filter_panel_open=function() return filter_panel_open end,
            on_open_filter_panel=function() filter_panel_open = true end,
            on_close_filter_panel_state=function() filter_panel_open = false end,
            on_close_filter_panel=noop,
            is_attribute_picker_open=function() return false end,
            is_skill_picker_open=function() return false end,
            is_race_picker_open=function() return false end,
            is_unit_scope_picker_open=function() return false end,
            unit_scope='fort_residents',
            unit_scope_options={{label='Residents', value='fort_residents'}},
            on_unit_scope_change=noop,
            on_toggle_unit_scope_picker=noop,
            on_toggle_attribute_picker=noop,
            on_toggle_skill_picker=noop,
            on_toggle_race_picker=noop,
            on_clear=noop,
            is_preset_picker_open=function() return false end,
            on_toggle_preset_picker=noop,
            on_close_preset_picker=noop,
            on_preset_query=noop,
            on_save_preset=noop,
            on_load_preset=noop,
            on_load_default_preset=noop,
            on_load_role_preset=noop,
            on_close_picker=noop,
            on_attribute_query=noop,
            on_skill_query=noop,
            on_race_query=noop,
            on_add=noop,
            on_filter_action=noop,
        }
        test.assert_equal('filter_panel_window', views.view_id)
        test.assert_equal('Window', views.widget_kind)
        test.assert_true(views.onInput ~= nil)
        views.setFocus=function(_, value) focused = value end
        views.getMouseFramePos=function() return 1, 1 end
        test.assert_false(views:onInput{_MOUSE_L=true})
        test.assert_true(views:open())
        test.assert_true(focused)
        test.assert_true(views:onInput{_MOUSE_L=true})
        test.assert_true(views:onInput{_MOUSE_R=true})
        test.assert_false(focused)
        test.assert_false(filter_panel_open)
        test.assert_true(views:open())
        test.assert_true(views:close())
        views.getMouseFramePos=function() return nil end
        test.assert_false(views:onInput{})
        test.assert_false(views.visible())
        local subviews = views.subviews
        local filter_list = by_id(subviews, 'filter_list')
        local action
        filter_list.getIdxUnderMouse=function() return nil end
        filter_list.start_line_num=1
        filter_list.action_choices={{descriptor={id='attribute:strength'}}}
        filter_list.setSelected=function(_, index) filter_list.selected=index end
        filter_list.getMousePos=function()
            return layout.ACTIVE_FILTER_BUTTON_START_X +
                layout.FILTER_ACTION_ZONE_WIDTH - 1, 0
        end
        filter_list.on_filter_action=function(filter_id, callback)
            action={filter_id, callback}
        end
        test.assert_true(filter_list:onInput{_MOUSE_L=true})
        test.assert_equal(1, filter_list.selected)
        test.assert_sequence({'attribute:strength', 'remove'}, action)
        test.assert_equal(14, #subviews)
        test.assert_equal('close_filter_panel_button', subviews[1].view_id)
        test.assert_equal('TextButton', subviews[1].widget_kind)
        test.assert_equal('X', subviews[1].label)
        test.assert_equal('Label', by_id(subviews, 'unit_scope_label').widget_kind)
        test.assert_equal('Include: Residents', by_id(subviews, 'unit_scope_label').text)
        test.assert_equal('TextButton',
            by_id(subviews, 'unit_scope_edit').widget_kind)
        test.assert_equal('Edit', by_id(subviews, 'unit_scope_edit').label)
        for _, button in ipairs({
            {id='add_filter_button', key='CUSTOM_A', label='Add attribute filter'},
            {id='add_skill_button', key='CUSTOM_S', label='Add skill filter'},
            {id='add_race_button', key='CUSTOM_G', label='Add race filter'},
            {id='clear_filters_button', key='CUSTOM_C', label='Clear filters'},
            {id='preset_button', key='CUSTOM_P', label='Filter presets'},
        }) do
            local view = by_id(subviews, button.id)
            test.assert_equal('TextButton', view.widget_kind)
            test.assert_equal(button.key, view.key)
            test.assert_equal(button.label, view.label)
        end
        test.assert_equal('available_filter_list',
            by_id(subviews, 'available_filter_window').subviews[3].view_id)
        for _, picker_id in ipairs({
            'available_filter_window',
            'available_race_window',
            'available_skill_window',
            'preset_picker_window',
        }) do
            local close_button = by_id(subviews, picker_id).subviews[1]
            test.assert_equal('TextButton', close_button.widget_kind)
            test.assert_equal('X', close_button.label)
        end
        local save_preset_button =
            by_id(subviews, 'preset_picker_window').subviews[2]
        test.assert_equal('TextButton', save_preset_button.widget_kind)
        test.assert_equal('CUSTOM_W', save_preset_button.key)
        test.assert_equal('Save preset', save_preset_button.label)
        test.assert_equal('unit_scope_picker_list',
            by_id(subviews, 'unit_scope_picker_window').subviews[1].view_id)
        test.assert_equal('filters_button',
            components.create_filter_panel_button(noop).view_id)
        test.assert_equal('TextButton',
            components.create_filter_panel_button(noop).widget_kind)
        test.assert_equal('Edit',
            components.create_filter_panel_button(noop).label)
        test.assert_equal('yellow',
            components.create_filter_panel_button(noop).text_pen)
        local active_filter_count = components.create_active_filter_count()
        test.assert_equal('active_filter_count', active_filter_count.view_id)
        test.assert_equal('Filters: 0', active_filter_count.text)
        test.assert_equal('grey', active_filter_count.text_pen)
    end)

    test.case('UI components: race picker hides the active filter list', function()
        local views = components.create_filter_panel{
            is_filter_panel_open=function() return true end,
            on_close_filter_panel=noop,
            is_attribute_picker_open=function() return false end,
            is_skill_picker_open=function() return false end,
            is_race_picker_open=function() return true end,
            is_unit_scope_picker_open=function() return false end,
            unit_scope='fort_residents',
            unit_scope_options={{label='Residents', value='fort_residents'}},
            on_unit_scope_change=noop,
            on_toggle_unit_scope_picker=noop,
            on_toggle_attribute_picker=noop,
            on_toggle_skill_picker=noop,
            on_toggle_race_picker=noop,
            on_clear=noop,
            is_preset_picker_open=function() return false end,
            on_toggle_preset_picker=noop,
            on_close_preset_picker=noop,
            on_preset_query=noop,
            on_save_preset=noop,
            on_load_preset=noop,
            on_load_default_preset=noop,
            on_load_role_preset=noop,
            on_close_picker=noop,
            on_attribute_query=noop,
            on_skill_query=noop,
            on_race_query=noop,
            on_add=noop,
        }
        local subviews = views.subviews
        test.assert_true(views.visible())
        test.assert_false(by_id(subviews, 'filter_list').visible())
        test.assert_true(by_id(subviews, 'available_race_window').visible())
        test.assert_false(by_id(subviews, 'available_filter_window').visible())
        test.assert_false(by_id(subviews, 'available_skill_window').visible())
        test.assert_false(by_id(subviews, 'preset_picker_window').visible())
        test.assert_false(by_id(subviews, 'unit_scope_picker_window').visible())
    end)

    test.case('UI components: unit-scope picker is a modal below the control', function()
        local views = components.create_filter_panel{
            is_filter_panel_open=function() return true end,
            on_close_filter_panel=noop,
            is_attribute_picker_open=function() return false end,
            is_skill_picker_open=function() return false end,
            is_race_picker_open=function() return false end,
            is_unit_scope_picker_open=function() return true end,
            unit_scope='visitors',
            unit_scope_options={{label='Visitors', value='visitors'}},
            on_unit_scope_change=noop,
            on_toggle_unit_scope_picker=noop,
            on_toggle_attribute_picker=noop,
            on_toggle_skill_picker=noop,
            on_toggle_race_picker=noop,
            on_clear=noop,
            is_preset_picker_open=function() return false end,
            on_toggle_preset_picker=noop,
            on_close_preset_picker=noop,
            on_preset_query=noop,
            on_save_preset=noop,
            on_load_preset=noop,
            on_load_default_preset=noop,
            on_load_role_preset=noop,
            on_close_picker=noop,
            on_attribute_query=noop,
            on_skill_query=noop,
            on_race_query=noop,
            on_add=noop,
        }
        local subviews = views.subviews
        test.assert_true(views.visible())
        test.assert_true(by_id(subviews, 'unit_scope_picker_window').visible())
        test.assert_false(by_id(subviews, 'filter_list').visible())
    end)

    test.case('UI components: results and stats expose explicit panel views', function()
        local query = components.create_results_query(noop)
        test.assert_equal('search_field', query.view_id)
        test.assert_equal('EditField', query.widget_kind)

        local result_sort
        local results = components.create_results_panel{
            on_select=noop,
            on_submit=noop,
            on_sort=function(column) result_sort = column end,
        }
        test.assert_equal('result_header', results[1].view_id)
        test.assert_equal('result_header_underline', results[2].view_id)
        test.assert_equal('result_columns', results[3].view_id)
        test.assert_equal('result_list', results[4].view_id)
        results[3].getMousePos=function() return 0, 0 end
        test.assert_true(results[3]:onInput{_MOUSE_L=true})
        test.assert_equal('name', result_sort)

        test.assert_equal('close_button', components.create_close_button(noop).view_id)
    end)

    test.case('UI components: result navigation is explicit', function()
        local list = {
            setChoices=function(self, choices, selected)
                self.choices = choices
                self.selected = selected
            end,
            moveCursor=function(self, delta) self.delta = delta end,
        }
        components.set_result_choices(list, {'choice'}, 1)
        components.move_result_cursor(list, -10)
        test.assert_sequence({'choice'}, list.choices)
        test.assert_equal(1, list.selected)
        test.assert_equal(-10, list.delta)

    end)
end
