--@ module=true

local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local descriptions = reqscript('internal/soulsearch/attribute_descriptions')
local filter_constants = reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

local FILTER_KIND_RACE = filter_constants.kind.RACE

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
    if descriptor and descriptor.kind == FILTER_KIND_RACE then
        return 'Filters by a creatures race.'
    end
    return descriptor and descriptions.get_tooltip(descriptor.kind, descriptor.key) or nil
end

function FilterActionList:on_pointer_update(target, x, y)
    local _, choice, action = self:get_action_at(x, y)
    if action then
        local descriptor = choice and choice.descriptor
        if descriptor and descriptor.kind == FILTER_KIND_RACE then
            if action.callback == 'set_high' then
                target.tooltip = 'Include in results.'
                return
            elseif action.callback == 'set_low' then
                target.tooltip = 'Exclude from results.'
                return
            elseif action.callback == 'move_up' or action.callback == 'move_down' then
                target.tooltip = nil
                return
            end
        end
        target.tooltip = choice and action.tooltip or nil
        return
    end
    target.tooltip = describe_choice(choice)
end

---@param keys table
---@return boolean
function FilterActionList:onInput(keys)
    if keys._MOUSE_L then
        local index, choice, action = self:getActionUnderMouse()
        if choice and action then
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
