local soulsearch_env = require('support.soulsearch_env')
local widget_harness = require('support.widget_harness')

return function(test, repo_root)
    local FilterActionList = soulsearch_env.load_filter_action_list(
        repo_root).FilterActionList
    local layout = soulsearch_env.load_ui_layout(repo_root)

    local function make_list(callback)
        local list = FilterActionList{on_filter_action=callback}
        function list:getMousePos() return self.mouse_x, self.mouse_y end
        function list:getIdxUnderMouse() return self.mouse_index end
        function list:setSelected(index) self.selected = index end
        return list
    end

    test.case('filter action list: setChoices retains the action snapshot', function()
        local list = make_list(function() end)
        local choices = {{descriptor={id='attribute:strength'}}}
        list.base_set_choices_result = 'set'
        test.assert_equal('set', list:setChoices(choices, 1))
        test.assert_true(list.action_choices == choices)
        test.assert_true(list.base_choices == choices)
        test.assert_equal(1, list.base_selected)
    end)

    test.case('filter action list: every action boundary dispatches metadata', function()
        local calls = {}
        local list = make_list(function(id, action)
            table.insert(calls, id .. ':' .. action)
        end)
        list:setChoices({{descriptor={id='attribute:strength'}}}, 1)
        list.mouse_index, list.mouse_y = 1, 0
        for index, action in ipairs(layout.FILTER_ACTIONS) do
            local left = layout.ACTIVE_FILTER_BUTTON_START_X +
                (index - 1) * layout.FILTER_ACTION_WIDTH
            for _, x in ipairs({left, left + layout.FILTER_ACTION_WIDTH - 1}) do
                list.mouse_x = x
                test.assert_true(list:onInput{_MOUSE_L=true})
                test.assert_equal('attribute:strength:' .. action.callback,
                    calls[#calls])
                test.assert_equal(1, list.selected)
            end
        end
    end)

    test.case('filter action list: scrolled row fallback uses visible offset', function()
        local dispatched
        local list = make_list(function(id, action)
            dispatched = {id, action}
        end)
        local choices = {}
        choices[6] = {descriptor={id='attribute:agility'}}
        list:setChoices(choices, 1)
        list.start_line_num = 4
        list.mouse_index = nil
        list.mouse_x = layout.ACTIVE_FILTER_BUTTON_START_X
        list.mouse_y = 2
        test.assert_true(list:onInput{_MOUSE_L=true})
        test.assert_equal(6, list.selected)
        test.assert_sequence({'attribute:agility', 'set_high'}, dispatched)
    end)

    test.case('filter action list: native page top identifies the hovered action row', function()
        local list = make_list(function() end)
        list:setChoices({
            {descriptor={id='attribute:strength'}},
            {descriptor={id='attribute:agility'}},
            {descriptor={id='attribute:toughness'}},
        }, 1)
        list.page_top = 3
        list:on_pointer_update(layout.ACTIVE_FILTER_BUTTON_START_X, 0)

        test.assert_equal('Prefer high', list.tooltip)
    end)

    test.case('filter action list: misses and incomplete rows delegate', function()
        local calls = 0
        local list = make_list(function() calls = calls + 1 end)
        list:setChoices({{}}, 1)
        list.mouse_index, list.mouse_y = 1, 0
        list.mouse_x = layout.ACTIVE_FILTER_BUTTON_START_X - 1
        test.assert_false(list:onInput{_MOUSE_L=true})
        list.mouse_x = layout.ACTIVE_FILTER_BUTTON_START_X
        test.assert_false(list:onInput{_MOUSE_L=true})
        test.assert_equal(0, calls)
        test.assert_equal(2, list.super_input_calls)
    end)

    test.case('filter action list: terminal pointer updates own action and descriptor text', function()
        local list = make_list(function() end)
        list:setChoices({{descriptor={kind='trait', key='PATIENCE'}}}, 1)
        list:on_pointer_update(0, 0)
        test.assert_equal('A personality trait that shapes behavior and social interaction.',
            list.tooltip)
        list:on_pointer_update(layout.ACTIVE_FILTER_BUTTON_START_X, 0)
        test.assert_equal('Prefer high', list.tooltip)

        list:setChoices({{descriptor={kind='race', key='DWARF', behavior='candidate'}}}, 1)
        list:on_pointer_update(layout.ACTIVE_FILTER_BUTTON_START_X, 0)
        test.assert_equal('Include in results.', list.tooltip)
        list:on_pointer_update(layout.ACTIVE_FILTER_BUTTON_START_X +
            2 * layout.FILTER_ACTION_WIDTH, 0)
        test.assert_equal(nil, list.tooltip)
        list:on_pointer_update(0, 3)
        test.assert_equal(nil, list.tooltip)
    end)

    test.case('filter action list: dispatcher invokes class pointer method with local coordinates',
            function()
        local dispatcher = soulsearch_env.load_pointer_dispatcher(repo_root)
        local list = make_list(function() end)
        list:setChoices({{descriptor={kind='trait', key='PATIENCE'}}}, 1)
        list.visible, list.active, list.pointer_policy = true, true, 'target'
        list.subviews = {}
        widget_harness.set_frame(list, 3, 2, 40, 4)
        local root = {
            visible=true,
            active=true,
            pointer_policy='target',
            subviews={list},
        }
        widget_harness.set_frame(root, 0, 0, 50, 10)

        local context = dispatcher.PointerContext.new(root)
        local result = dispatcher.PointerDispatcher.sample(context,
            3 + layout.ACTIVE_FILTER_BUTTON_START_X, 2)

        test.assert_equal(list, result.target)
        test.assert_equal(layout.ACTIVE_FILTER_BUTTON_START_X, result.x)
        test.assert_equal(0, result.y)
        test.assert_equal('Prefer high', list.tooltip)
    end)
end
