local soulsearch_env = require('support.soulsearch_env')
local widget_harness = require('support.widget_harness')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local FilterActionList = soulsearch_env.load_filter_action_list(
        repo_root).FilterActionList
    local layout = soulsearch_env.load_ui_layout(repo_root)
    local action = layout.FILTER_ACTION

    local function make_list(callback)
        local list = FilterActionList{on_filter_action=callback}
        function list:getMousePos() return self.mouse_x, self.mouse_y end
        function list:getIdxUnderMouse() return self.mouse_index end
        function list:setSelected(index) self.selected = index end
        return list
    end

    add_test('filter action list: setChoices retains the action snapshot', function()
        local list = make_list(function() end)
        local choices = {{descriptor={id='attribute:strength'}}}
        list.base_set_choices_result = 'set'
        luaunit.assertIs('set', list:setChoices(choices, 1))
        luaunit.assertEvalToTrue(list.action_choices == choices)
        luaunit.assertEvalToTrue(list.base_choices == choices)
        luaunit.assertIs(1, list.base_selected)
    end)

    add_test('filter action list: every action boundary dispatches metadata', function()
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
                luaunit.assertEvalToTrue(list:onInput{_MOUSE_L=true})
                luaunit.assertIs('attribute:strength:' .. action.callback,
                    calls[#calls])
                luaunit.assertIs(1, list.selected)
            end
        end
    end)

    add_test('filter action list: scrolled row fallback uses visible offset', function()
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
        luaunit.assertEvalToTrue(list:onInput{_MOUSE_L=true})
        luaunit.assertIs(6, list.selected)
        luaunit.assertEquals({'attribute:agility', action.SET_HIGH}, dispatched)
    end)

    add_test('filter action list: native page top identifies the hovered action row', function()
        local list = make_list(function() end)
        list:setChoices({
            {descriptor={id='attribute:strength'}},
            {descriptor={id='attribute:agility'}},
            {descriptor={id='attribute:toughness'}},
        }, 1)
        list.page_top = 3
        list:on_pointer_update(layout.ACTIVE_FILTER_BUTTON_START_X, 0)

        luaunit.assertIs('Prefer high', list.tooltip)
    end)

    add_test('filter action list: misses and incomplete rows delegate', function()
        local calls = 0
        local list = make_list(function() calls = calls + 1 end)
        list:setChoices({{}}, 1)
        list.mouse_index, list.mouse_y = 1, 0
        list.mouse_x = layout.ACTIVE_FILTER_BUTTON_START_X - 1
        luaunit.assertEvalToFalse(list:onInput{_MOUSE_L=true})
        list.mouse_x = layout.ACTIVE_FILTER_BUTTON_START_X
        luaunit.assertEvalToFalse(list:onInput{_MOUSE_L=true})
        luaunit.assertIs(0, calls)
        luaunit.assertIs(2, list.super_input_calls)
    end)

    add_test('filter action list: terminal pointer updates own action and descriptor text', function()
        local list = make_list(function() end)
        list:setChoices({{descriptor={kind='trait', key='PATIENCE'}}}, 1)
        list:on_pointer_update(0, 0)
        luaunit.assertIs('A personality trait that shapes behavior and social interaction.',
            list.tooltip)
        list:on_pointer_update(layout.ACTIVE_FILTER_BUTTON_START_X, 0)
        luaunit.assertIs('Prefer high', list.tooltip)

        list:setChoices({{descriptor={kind='race', key='DWARF', behavior='candidate'}}}, 1)
        list:on_pointer_update(layout.ACTIVE_FILTER_BUTTON_START_X, 0)
        luaunit.assertIs('Include in results.', list.tooltip)
        list:on_pointer_update(layout.ACTIVE_FILTER_BUTTON_START_X +
            2 * layout.FILTER_ACTION_WIDTH, 0)
        luaunit.assertIs(nil, list.tooltip)
        list:on_pointer_update(0, 3)
        luaunit.assertIs(nil, list.tooltip)

        list:setChoices({{descriptor={kind='unit_scope', key='visitors',
            behavior='candidate'}}}, 1)
        list:on_pointer_update(0, 0)
        luaunit.assertIs('Filters which active units are considered.', list.tooltip)
    end)

    add_test('filter action list: candidate move hit zones cannot dispatch', function()
        local calls = {}
        local list = make_list(function(id, action)
            table.insert(calls, id .. ':' .. action)
        end)
        list:setChoices({{descriptor={id='unit_scope:visitors', kind='unit_scope',
            behavior='candidate'}}}, 1)
        list.mouse_index, list.mouse_y = 1, 0
        local action_x = layout.ACTIVE_FILTER_BUTTON_START_X
        for _, index in ipairs({1, 2, 5}) do
            list.mouse_x = action_x + (index - 1) * layout.FILTER_ACTION_WIDTH
            luaunit.assertEvalToTrue(list:onInput{_MOUSE_L=true})
        end
        luaunit.assertEquals({
            'unit_scope:visitors:' .. action.SET_HIGH,
            'unit_scope:visitors:' .. action.SET_LOW,
            'unit_scope:visitors:' .. action.REMOVE,
        }, calls)
        for _, index in ipairs({3, 4}) do
            list.mouse_x = action_x + (index - 1) * layout.FILTER_ACTION_WIDTH
            luaunit.assertEvalToFalse(list:onInput{_MOUSE_L=true})
        end
        luaunit.assertIs(2, list.super_input_calls)
    end)

    add_test('filter action list: dispatcher invokes class pointer method with local coordinates',
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

        luaunit.assertIs(list, result.target)
        luaunit.assertIs(layout.ACTIVE_FILTER_BUTTON_START_X, result.x)
        luaunit.assertIs(0, result.y)
        luaunit.assertIs('Prefer high', list.tooltip)
    end)

return native_tests
