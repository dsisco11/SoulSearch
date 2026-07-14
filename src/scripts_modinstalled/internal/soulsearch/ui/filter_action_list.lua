--@ module=true

local widgets = require('gui.widgets')
local ui_layout = reqscript('internal/soulsearch/ui_layout')

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
function FilterActionList:getActionUnderMouse()
    local x, y = self:getMousePos()
    local action = ui_layout.get_filter_action_at_x(x)
    if not action or not y then return nil end

    local index = self:getIdxUnderMouse()
    if not index then
        index = (self.start_line_num or 1) + y
    end
    return index, self.action_choices and self.action_choices[index], action
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

