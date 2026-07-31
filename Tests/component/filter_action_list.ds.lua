local gui = require('gui')
local FilterActionList =
    reqscript('internal/soulsearch/ui/filter_action_list').FilterActionList
local ui_layout = reqscript('internal/soulsearch/ui_layout')

---@class tests.FilterActionListScreen: gui.ZScreen
---@field choices table[]
---@field callbacks table
---@field list_width integer
---@field list_height integer
local FilterActionListScreen = defclass(nil, gui.ZScreen)
FilterActionListScreen.ATTRS{
    choices=DEFAULT_NIL,
    callbacks=DEFAULT_NIL,
    list_width=43,
    list_height=1,
    focus_path='soulsearch/filter-action-list-test',
}

---Builds a real filter list for pointer interaction tests.
function FilterActionListScreen:init()
    self.list = FilterActionList{
        view_id='filter_list',
        frame={l=0, t=0, w=self.list_width, h=self.list_height},
        on_filter_action=self.callbacks.on_filter_action,
    }
    self:addviews{self.list}
    self.list:setChoices(self.choices, 1)
end

---Builds one ordinary ranking-filter choice.
---@param id string
---@param label string
---@param action_state table|nil
---@return table choice
local function ranking_choice(id, label, action_state)
    return {
        text=label,
        descriptor={id=id, kind='trait', key='PATIENCE', behavior='ranking'},
        action_state=action_state,
    }
end

---Builds one candidate-filter choice with movement actions disabled.
---@param id string
---@return table choice
local function candidate_choice(id)
    return {
        text='Visitors',
        descriptor={id=id, kind='unit_scope', key='visitors', behavior='candidate'},
    }
end

---Returns a list width whose center lies in a requested action zone.
---@param action_index integer
---@return integer width
local function width_for_action(action_index)
    local x = ui_layout.ACTIVE_FILTER_BUTTON_START_X +
        (action_index - 1) * ui_layout.FILTER_ACTION_WIDTH
    return x * 2 + 1
end

---Mounts a list with an explicit rendered width.
---@param list_width integer
---@param choices table[]
---@param list_height integer|nil
---@return table callback
local function mount_list(list_width, choices, list_height)
    local callback = spy.new(function() end)
    ds.mount(FilterActionListScreen{
        choices=choices,
        callbacks={on_filter_action=callback},
        list_width=list_width,
        list_height=list_height or 1,
    })
    return callback
end

---Mounts a list with its center aligned to one native action zone.
---@param action_index integer
---@param choices table[]
---@param list_height integer|nil
---@return table callback
local function mount_action_list(action_index, choices, list_height)
    return mount_list(width_for_action(action_index), choices, list_height)
end

describe('SoulSearch Filter Action List', function()
    it('dispatches every visible action zone with the selected filter ID', function()
        for action_index, action in ipairs(ui_layout.FILTER_ACTIONS) do
            local callback = mount_action_list(action_index,
                {ranking_choice('trait:PATIENCE', 'Patience')})
            local list = ds.get('filter_list')

            list:move_pointer()
            local mouse_x, mouse_y = list:raw():getMousePos()
            assert.equals(ui_layout.ACTIVE_FILTER_BUTTON_START_X +
                (action_index - 1) * ui_layout.FILTER_ACTION_WIDTH, mouse_x)
            assert.equals(0, mouse_y)
            list:click()

            assert.spy(callback).was_called_with(
                'trait:PATIENCE', action.callback)
            ds.unmount()
        end
    end)

    it('does not dispatch candidate priority actions', function()
        for _, action_index in ipairs({3, 4}) do
            local callback = mount_action_list(action_index,
                {candidate_choice('unit_scope:visitors')})

            ds.get('filter_list'):click()

            assert.spy(callback).was_not_called()
            ds.unmount()
        end
    end)

    it('does not dispatch priority actions at list boundaries', function()
        for _, boundary in ipairs({
            {action_index=3, state={can_move_up=false, can_move_down=true}},
            {action_index=4, state={can_move_up=true, can_move_down=false}},
        }) do
            local callback = mount_action_list(boundary.action_index,
                {ranking_choice('trait:PATIENCE', 'Patience', boundary.state)})

            ds.get('filter_list'):click()

            assert.spy(callback).was_not_called()
            ds.unmount()
        end
    end)

    it('renders dynamic action and descriptor tooltips on hover', function()
        mount_action_list(1, {candidate_choice('unit_scope:visitors')})
        ds.get('filter_list'):hover()
        ds.wait_frames(1)
        assert.equals('Include in results.', ds.get('filter_list'):raw().tooltip)
        ds.unmount()

        mount_list(21, {ranking_choice('trait:PATIENCE', 'Patience')})
        ds.get('filter_list'):hover()
        ds.wait_frames(1)
        assert.equals(
            'A personality trait that shapes behavior and social interaction.',
            ds.get('filter_list'):raw().tooltip)
    end)

    it('targets the correct action row after native scrolling', function()
        local callback = mount_action_list(1, {
            ranking_choice('trait:PATIENCE', 'Patience'),
            ranking_choice('trait:BRAVERY', 'Bravery'),
            ranking_choice('trait:IMMODERATION', 'Immoderation'),
        })
        local list = ds.get('filter_list')

        list:input('STANDARDSCROLL_DOWN')
        assert.equals(3, list:raw().page_top)
        list:click()

        assert.spy(callback).was_called_with(
            'trait:IMMODERATION', ui_layout.FILTER_ACTION.SET_HIGH)
    end)

    it('delegates descriptor-zone clicks without dispatching a filter action', function()
        local callback = mount_list(21,
            {ranking_choice('trait:PATIENCE', 'Patience')})

        ds.get('filter_list'):click()

        assert.spy(callback).was_not_called()
        assert.equals(1, ds.get('filter_list'):raw():getSelected())
    end)
end)
