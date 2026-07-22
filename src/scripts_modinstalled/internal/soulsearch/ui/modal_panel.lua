--@ module=true

local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')

---Reusable modal window that owns open/close focus transitions and consumes
---mouse input within its frame while open.
---@class ModalPanelWindow: widgets.Window
---@field opened boolean
---@field on_open fun()|nil
---@field on_close fun()|nil
---@field initial_focus_view_id string|nil
---@field visible boolean
ModalPanelWindow = defclass(ModalPanelWindow, widgets.Window)
ModalPanelWindow.ATTRS{
    pointer_policy='block',
}

---Initializes closed modal state and optional lifecycle callbacks.
---@param info table modal construction parameters
function ModalPanelWindow:init(info)
    self.on_open = info.on_open
    self.on_close = info.on_close
    self.initial_focus_view_id = info.initial_focus_view_id
    self.opened = false
    self.visible = false
end

---@return boolean
function ModalPanelWindow:is_open()
    return self.opened
end

---@return boolean changed
function ModalPanelWindow:open()
    if self.opened then return false end
    self.opened = true
    self.visible = true
    self:setFocus(true)
    if self.on_open then self.on_open() end
    local initial_focus = self.initial_focus_view_id and
        self.subviews[self.initial_focus_view_id]
    if initial_focus then initial_focus:setFocus(true) end
    return true
end

---@return boolean changed
function ModalPanelWindow:close()
    if not self.opened then return false end
    self:setFocus(false)
    self.opened = false
    self.visible = false
    if self.on_close then self.on_close() end
    return true
end

---@param keys table
---@return boolean
function ModalPanelWindow:onInput(keys)
    if not self.opened then return false end
    if keys._MOUSE_R then
        -- Give a focused child the first chance to consume a contextual click.
        if type(self.inputToSubviews) == 'function' and
                self:inputToSubviews(keys) then
            return true
        end
        self:close()
        return true
    end
    if ModalPanelWindow.super.onInput(self, keys) then return true end
    return self:getMouseFramePos() ~= nil
end
