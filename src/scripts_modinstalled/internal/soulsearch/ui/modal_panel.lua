--@ module=true

local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')

---Reusable modal window that owns open/close focus transitions and consumes
---mouse input within its frame while open.
---@class ModalPanelWindow: widgets.Window
---@field opened boolean
---@field on_open fun()|nil
---@field on_close fun()|nil
---@field visible boolean
ModalPanelWindow = defclass(ModalPanelWindow, widgets.Window)

function ModalPanelWindow:init(info)
    self.on_open = info.on_open
    self.on_close = info.on_close
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
    if ModalPanelWindow.super.onInput(self, keys) then return true end

    if keys._MOUSE_R and self:getMouseFramePos() then
        self:close()
        return true
    end
    return self:getMouseFramePos() ~= nil
end
