local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local components = soulsearch_env.load_ui_components(repo_root)
    local noop = function() end

    test.case('UI components: control tooltips explain non-obvious actions', function()
        test.assert_sequence({
            'Add an attribute or trait to the ranking criteria.',
            'Add a skill to the ranking criteria.',
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
    end)

    test.case('UI components: filter panel preserves child and picker order', function()
        local views = components.create_filter_panel{
            is_attribute_picker_open=function() return false end,
            is_skill_picker_open=function() return false end,
            on_toggle_attribute_picker=noop,
            on_toggle_skill_picker=noop,
            on_clear=noop,
            on_close_picker=noop,
            on_attribute_query=noop,
            on_skill_query=noop,
            on_add=noop,
        }
        test.assert_equal(8, #views)
        test.assert_equal('add_filter_button', views[3].view_id)
        test.assert_equal('add_skill_button', views[4].view_id)
        test.assert_equal('clear_filters_button', views[5].view_id)
        test.assert_equal('filter_list', views[6].view_id)
        test.assert_equal('available_filter_window', views[7].view_id)
        test.assert_equal('close_filter_picker_button', views[7].subviews[1].view_id)
        test.assert_equal('attribute_search_field', views[7].subviews[2].view_id)
        test.assert_equal('available_filter_list', views[7].subviews[3].view_id)
        test.assert_equal('available_skill_window', views[8].view_id)
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
        test.assert_equal('result_list', results[3].view_id)

        local stats = components.create_stats_panel()
        test.assert_equal('stats_header', stats[3].view_id)
        test.assert_equal('stats', stats[4].view_id)
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
        local header, body = label(3), label(1)
        local frame = {height=30}
        components.update_stats_panel(
            header, body, {unit_id=7}, 'value', true, frame)
        test.assert_equal('header', header.text[1])
        test.assert_equal('body', body.text[1])
        test.assert_equal('value', body.text[3])
        test.assert_true(body.text[4])
        test.assert_equal(4, header.frame.t)
        test.assert_equal(7, body.frame.t)
        test.assert_equal(frame, header.updated_with)
    end)
end
