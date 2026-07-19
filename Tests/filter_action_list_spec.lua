local soulsearch_env = require('support.soulsearch_env')
local widget_harness = require('support.widget_harness')

local repo_root = require('support.repo_root')

describe('filter action list', function()

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

    it('filter action list: setChoices retains the action snapshot', function()
        local list = make_list(function() end)
        local choices = {{descriptor={id='attribute:strength'}}}
        list.base_set_choices_result = 'set'
        assert.are.equal('set', list:setChoices(choices, 1))
        assert.is_truthy(list.action_choices == choices)
        assert.is_truthy(list.base_choices == choices)
        assert.are.equal(1, list.base_selected)
    end)

    it('filter action list: every action boundary dispatches metadata', function()
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
                assert.is_truthy(list:onInput{_MOUSE_L=true})
                assert.are.equal('attribute:strength:' .. action.callback,
                    calls[#calls])
                assert.are.equal(1, list.selected)
            end
        end
    end)

    it('filter action list: scrolled row fallback uses visible offset', function()
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
        assert.is_truthy(list:onInput{_MOUSE_L=true})
        assert.are.equal(6, list.selected)
        assert.are.same({'attribute:agility', action.SET_HIGH}, dispatched)
    end)

    it('filter action list: native page top identifies the hovered action row', function()
        local list = make_list(function() end)
        list:setChoices({
            {descriptor={id='attribute:strength'}},
            {descriptor={id='attribute:agility'}},
            {descriptor={id='attribute:toughness'}},
        }, 1)
        list.page_top = 3
        list:on_pointer_update(layout.ACTIVE_FILTER_BUTTON_START_X, 0)

        assert.are.equal('Prefer high', list.tooltip)
    end)

    it('filter action list: misses and incomplete rows delegate', function()
        local calls = 0
        local list = make_list(function() calls = calls + 1 end)
        list:setChoices({{}}, 1)
        list.mouse_index, list.mouse_y = 1, 0
        list.mouse_x = layout.ACTIVE_FILTER_BUTTON_START_X - 1
        assert.is_falsy(list:onInput{_MOUSE_L=true})
        list.mouse_x = layout.ACTIVE_FILTER_BUTTON_START_X
        assert.is_falsy(list:onInput{_MOUSE_L=true})
        assert.are.equal(0, calls)
        assert.are.equal(2, list.super_input_calls)
    end)

    it('filter action list: terminal pointer updates own action and descriptor text', function()
        local list = make_list(function() end)
        list:setChoices({{descriptor={kind='trait', key='PATIENCE'}}}, 1)
        list:on_pointer_update(0, 0)
        assert.are.equal('A personality trait that shapes behavior and social interaction.',
            list.tooltip)
        list:on_pointer_update(layout.ACTIVE_FILTER_BUTTON_START_X, 0)
        assert.are.equal('Prefer high', list.tooltip)

        list:setChoices({{descriptor={kind='race', key='DWARF', behavior='candidate'}}}, 1)
        list:on_pointer_update(layout.ACTIVE_FILTER_BUTTON_START_X, 0)
        assert.are.equal('Include in results.', list.tooltip)
        list:on_pointer_update(layout.ACTIVE_FILTER_BUTTON_START_X +
            2 * layout.FILTER_ACTION_WIDTH, 0)
        assert.are.equal(nil, list.tooltip)
        list:on_pointer_update(0, 3)
        assert.are.equal(nil, list.tooltip)

        list:setChoices({{descriptor={kind='unit_scope', key='visitors',
            behavior='candidate'}}}, 1)
        list:on_pointer_update(0, 0)
        assert.are.equal('Filters which active units are considered.', list.tooltip)
    end)

    it('filter action list: candidate move hit zones cannot dispatch', function()
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
            assert.is_truthy(list:onInput{_MOUSE_L=true})
        end
        assert.are.same({
            'unit_scope:visitors:' .. action.SET_HIGH,
            'unit_scope:visitors:' .. action.SET_LOW,
            'unit_scope:visitors:' .. action.REMOVE,
        }, calls)
        for _, index in ipairs({3, 4}) do
            list.mouse_x = action_x + (index - 1) * layout.FILTER_ACTION_WIDTH
            assert.is_falsy(list:onInput{_MOUSE_L=true})
        end
        assert.are.equal(2, list.super_input_calls)
    end)

    it('filter action list: dispatcher invokes class pointer method with local coordinates',
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

        assert.are.equal(list, result.target)
        assert.are.equal(layout.ACTIVE_FILTER_BUTTON_START_X, result.x)
        assert.are.equal(0, result.y)
        assert.are.equal('Prefer high', list.tooltip)
    end)

end)