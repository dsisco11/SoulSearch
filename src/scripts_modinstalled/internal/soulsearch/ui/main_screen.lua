--@ module=true

local gui = require('gui')
reqscript('internal/soulsearch/ui/widget_extensions')
local screen_registry = reqscript('internal/soulsearch/screen_registry')
local SoulSearchWindow =
    reqscript('internal/soulsearch/ui/main_window').SoulSearchWindow
local SoulSearchTooltip =
    reqscript('internal/soulsearch/ui_tooltip').SoulSearchTooltip
local TooltipAgent = reqscript('internal/soulsearch/ui/tooltip_agent').TooltipAgent

local function try_load_dwarfui_tooltip_registration()
    local reqscript_fn = rawget(_G, 'reqscript')
    if type(reqscript_fn) ~= 'function' then return nil end
    for _, name in ipairs({
            'dwarfui/tooltip/api',
            'dwarfui/tooltip/registration',
        }) do
        local ok, module = pcall(reqscript_fn, name)
        if ok and type(module) == 'table' then
            return module
        end
    end
    return nil
end

-- Phase 1 migration boundary: probe DwarfUI tooltip registration at load time
-- without changing SoulSearch tooltip ownership yet.
local DWARFUI_TOOLTIP_REGISTRATION = try_load_dwarfui_tooltip_registration()

local function tooltip_debug_log(message)
    dfhack.println(message)
end

---@class SoulSearchScreen: gui.ZScreen
---@field window SoulSearchWindow
SoulSearchScreen = defclass(SoulSearchScreen, gui.ZScreen)
SoulSearchScreen.ATTRS {
    focus_path='soulsearch',
    settings_id=DEFAULT_NIL,
    settings=DEFAULT_NIL,
}

function SoulSearchScreen:init()
    self.dwarfui_tooltip_registration = DWARFUI_TOOLTIP_REGISTRATION
    self.window = SoulSearchWindow{
        view_id='window',
        settings_id=self.settings_id,
        settings=self.settings,
    }
    self.tooltip = SoulSearchTooltip{view_id='tooltip'}
    self:addviews{self.window, self.tooltip}
    -- Temporary resolver instrumentation for diagnosing live hover-state
    -- oscillation. The agent suppresses consecutive identical samples.
    tooltip_debug_log('[SoulSearch tooltip resolver] logging enabled')
    self.tooltip_agent = TooltipAgent.new(
        self, self.tooltip, tooltip_debug_log)
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
