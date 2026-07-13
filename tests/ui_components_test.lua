local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local components = soulsearch_env.load_ui_components(repo_root)
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
            'Choose which units are searched.',
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

    test.case('UI components: stats delta tooltip explains its baseline', function()
        test.assert_equal(
            'Difference from the attribute average.',
            components.STATS_VALUE_TOOLTIP)
        test.assert_equal('Sort by unit ID.',
            components.RESULT_HEADER_TOOLTIPS.unit_id)
    end)

    test.case('UI components: filter panel preserves child and picker order', function()
        local views = components.create_filter_panel{
            is_filter_panel_open=function() return false end,
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
        }
        test.assert_equal('filter_panel_window', views.view_id)
        test.assert_equal('Window', views.widget_kind)
        test.assert_false(views.visible())
        local subviews = views.subviews
        test.assert_equal(13, #subviews)
        test.assert_equal('close_filter_panel_button', subviews[1].view_id)
        test.assert_equal('HotkeyLabel', by_id(subviews, 'unit_scope').widget_kind)
        test.assert_equal('Search: Residents', by_id(subviews, 'unit_scope').label)
        test.assert_equal('add_filter_button', by_id(subviews, 'add_filter_button').view_id)
        test.assert_equal('available_filter_list',
            by_id(subviews, 'available_filter_window').subviews[3].view_id)
        test.assert_equal('unit_scope_picker_list',
            by_id(subviews, 'unit_scope_picker_window').subviews[1].view_id)
        test.assert_equal('filters_button',
            components.create_filter_panel_button(noop).view_id)
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

        local results = components.create_results_panel{
            on_select=noop,
            on_submit=noop,
        }
        test.assert_equal('result_header', results[1].view_id)
        test.assert_equal('result_header_underline', results[2].view_id)
        test.assert_equal('result_columns', results[3].view_id)
        test.assert_equal('result_list', results[4].view_id)

        local stats = components.create_stats_panel()
        test.assert_equal('stats_header', stats[3].view_id)
        test.assert_equal('stats_columns', stats[4].view_id)
        test.assert_equal('stats', stats[5].view_id)
        test.assert_equal('close_button', components.create_close_button(noop).view_id)
    end)

    test.case('UI components: result navigation and stats updates are explicit', function()
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

        local function label(height)
            return {
                setText=function(self, text) self.text = text end,
                getTextHeight=function() return height end,
                updateLayout=function(self, frame) self.updated_with = frame end,
            }
        end
        local header, columns, body = label(3), label(2), label(1)
        local frame = {height=30}
        components.update_stats_panel(
            header, columns, body, {unit_id=7}, 'value', true, frame)
        test.assert_equal('header', header.text[1])
        test.assert_equal('columns', columns.text[1])
        test.assert_equal('body', body.text[1])
        test.assert_equal('value', body.text[3])
        test.assert_true(body.text[4])
        test.assert_equal(4, header.frame.t)
        test.assert_equal(7, columns.frame.t)
        test.assert_equal(9, body.frame.t)
        test.assert_equal(frame, header.updated_with)
        test.assert_equal(frame, columns.updated_with)
    end)
end
