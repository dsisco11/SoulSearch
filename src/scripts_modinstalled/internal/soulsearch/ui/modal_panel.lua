--@ module=true

local widgets = require('gui.widgets')

---Reusable modal window that owns open/close focus transitions and consumes
---mouse input within its frame while open.
---@class ModalPanelWindow: widgets.Window
---@field is_open fun(): boolean
---@field on_open fun()
---@field on_close fun()
ModalPanelWindow = defclass(ModalPanelWindow, widgets.Window)

function ModalPanelWindow:init(info)
    self.is_open = info.is_open
    self.on_open = info.on_open
    self.on_close = info.on_close
end

---@return boolean changed
function ModalPanelWindow:open()
    if self.is_open() then return false end
    self.on_open()
    self:setFocus(true)
    return true
end

---@return boolean changed
function ModalPanelWindow:close()
    if not self.is_open() then return false end
    self:setFocus(false)
    self.on_close()
    return true
end

---@param keys table
---@return boolean
function ModalPanelWindow:onInput(keys)
    if not self.is_open() then return false end
    if ModalPanelWindow.super.onInput(self, keys) then return true end

    if keys._MOUSE_R and self:getMouseFramePos() then
        self:close()
        return true
    end
    return self:getMouseFramePos() ~= nil
end

