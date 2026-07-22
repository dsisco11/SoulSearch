--@ module=true

local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local descriptions = reqscript('internal/soulsearch/attribute_descriptions')
local filter_constants = reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

local CANDIDATE = filter_constants.behavior.CANDIDATE
local ACTION = ui_layout.FILTER_ACTION

---List that snapshots filter choices and dispatches clicks in the fixed-width
---action zone for the row under the mouse.
---@class FilterActionList: widgets.List
---@field on_filter_action fun(filter_id: string, action: string)
---@field action_choices table[]|nil
FilterActionList = defclass(FilterActionList, widgets.List)

function FilterActionList:init(info)
    self.on_filter_action = info.on_filter_action
end

function FilterActionList:setChoices(choices, selected)
    self.action_choices = choices
    return FilterActionList.super.setChoices(self, choices, selected)
end

---@return integer|nil, table|nil, SoulSearchFilterActionMetadata|nil
function FilterActionList:get_action_at(x, y)
    local action = ui_layout.get_filter_action_at_x(x)
    if y == nil then return nil end

    -- widgets.List calls its first visible row page_top. start_line_num is
    -- retained as the lightweight test-harness fallback.
    local index = (self.page_top or self.start_line_num or 1) + y
    return index, self.action_choices and self.action_choices[index], action
end

---@return integer|nil, table|nil, SoulSearchFilterActionMetadata|nil
function FilterActionList:getActionUnderMouse()
    local x, y = self:getMousePos()
    return self:get_action_at(x, y)
end

local function describe_choice(choice)
    local descriptor = choice and choice.descriptor
    if descriptor and descriptor.behavior == CANDIDATE then
        return descriptor.kind == filter_constants.kind.UNIT_SCOPE and
            'Filters which active units are considered.' or
            'Filters by a creatures race.'
    end
    return descriptor and descriptions.get_tooltip(descriptor.kind, descriptor.key) or nil
end

local function is_action_enabled(choice, action)
    local descriptor = choice and choice.descriptor
    if descriptor and descriptor.behavior == CANDIDATE and
            (action.callback == ACTION.MOVE_UP or action.callback == ACTION.MOVE_DOWN) then
        return false
    end
    local state = choice and choice.action_state
    if action.callback == ACTION.MOVE_UP and state and state.can_move_up ~= nil then
        return state.can_move_up
    end
    if action.callback == ACTION.MOVE_DOWN and state and state.can_move_down ~= nil then
        return state.can_move_down
    end
    return true
end

function FilterActionList:on_pointer_update(x, y)
    local _, choice, action = self:get_action_at(x, y)
    if action then
        local descriptor = choice and choice.descriptor
        if descriptor and descriptor.behavior == CANDIDATE then
            if action.callback == ACTION.SET_HIGH then
                self.tooltip = 'Include in results.'
                return
            elseif action.callback == ACTION.SET_LOW then
                self.tooltip = 'Exclude from results.'
                return
            elseif action.callback == ACTION.MOVE_UP or action.callback == ACTION.MOVE_DOWN then
                self.tooltip = nil
                return
            end
        end
        self.tooltip = choice and is_action_enabled(choice, action) and
            action.tooltip or nil
        return
    end
    self.tooltip = describe_choice(choice)
end

---@param keys table
---@return boolean
function FilterActionList:onInput(keys)
    if keys._MOUSE_L then
        local index, choice, action = self:getActionUnderMouse()
        if choice and action and is_action_enabled(choice, action) then
            self:setSelected(index)
            local descriptor = choice.descriptor
            if descriptor then
                self.on_filter_action(descriptor.id, action.callback)
                return true
            end
        end
    end
    return FilterActionList.super.onInput(self, keys)
end
