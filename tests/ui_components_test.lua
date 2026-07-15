local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local components = soulsearch_env.load_ui_components(repo_root)
    local noop = function() end

    test.case('UI components: result header tooltip explains its sort', function()
        test.assert_equal('Sort by unit ID.',
            components.RESULT_HEADER_TOOLTIPS.unit_id)
    end)

    test.case('UI components: results retain their explicit panel views', function()
        local query = components.create_results_query(noop)
        test.assert_equal('search_field', query.view_id)
        test.assert_equal('EditField', query.widget_kind)
        local result_sort
        local results = components.create_results_panel{
            on_select=noop, on_submit=noop,
            on_sort=function(column) result_sort = column end,
        }
        test.assert_sequence({
            'result_header', 'result_header_underline', 'result_columns',
            'result_list',
        }, (function()
            local ids = {}
            for _, view in ipairs(results) do table.insert(ids, view.view_id) end
            return ids
        end)())
        results[3].getMousePos=function() return 0, 0 end
        test.assert_true(results[3]:onInput{_MOUSE_L=true})
        test.assert_equal('name', result_sort)
        test.assert_equal('close_button', components.create_close_button(noop).view_id)
    end)

    test.case('UI components: result navigation is explicit', function()
        local list = {
            setChoices=function(self, choices, selected)
                self.choices, self.selected = choices, selected
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
