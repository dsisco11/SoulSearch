--@ module=true

local gui = require('gui')
reqscript('internal/soulsearch/ui/widget_extensions')
local screen_registry = reqscript('internal/soulsearch/screen_registry')
local SoulSearchWindow =
    reqscript('internal/soulsearch/ui/main_window').SoulSearchWindow
local SoulSearchTooltip =
    reqscript('internal/soulsearch/ui_tooltip').SoulSearchTooltip
local TooltipAgent = reqscript('internal/soulsearch/ui/tooltip_agent').TooltipAgent

---@class SoulSearchScreen: gui.ZScreen
---@field window SoulSearchWindow
SoulSearchScreen = defclass(SoulSearchScreen, gui.ZScreen)
SoulSearchScreen.ATTRS {
    focus_path='soulsearch',
    settings_id=DEFAULT_NIL,
    settings=DEFAULT_NIL,
}

function SoulSearchScreen:init()
    self.window = SoulSearchWindow{
        settings_id=self.settings_id,
        settings=self.settings,
    }
    self.tooltip = SoulSearchTooltip{}
    self:addviews{self.window, self.tooltip}
    self.tooltip_agent = TooltipAgent.new(self, self.tooltip)
end

function SoulSearchScreen:onRender()
    self.tooltip_agent:update()
    SoulSearchScreen.super.onRender(self)
end

function SoulSearchScreen:onShow()
    screen_registry.add(self)
end

---@return boolean cleaned
function SoulSearchScreen:cleanup()
    if self.cleaned_up then return false end
    self.cleaned_up = true
    self.window:persist_frame_if_needed()
    screen_registry.remove(self)
    return true
end

function SoulSearchScreen:onDismiss()
    self:cleanup()
end

function SoulSearchScreen:onDestroy()
    self:cleanup()
end
