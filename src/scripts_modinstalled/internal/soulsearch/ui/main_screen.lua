--@ module=true

local gui = require('gui')
reqscript('internal/soulsearch/ui/widget_extensions')
local screen_registry = reqscript('internal/soulsearch/screen_registry')
local SoulSearchWindow =
    reqscript('internal/soulsearch/ui/main_window').SoulSearchWindow
local dwarfui_tooltip = reqscript('dwarfui/tooltip/api')

local function walk_subviews(root, visit, seen)
    if not root or type(root) ~= 'table' then return end
    seen = seen or {}
    if seen[root] then return end
    seen[root] = true
    visit(root)
    for _, child in ipairs(root.subviews or {}) do
        walk_subviews(child, visit, seen)
    end
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
    self.window = SoulSearchWindow{
        view_id='window',
        settings_id=self.settings_id,
        settings=self.settings,
    }
    self:addviews{self.window}
    self:register_tooltips()
end

function SoulSearchScreen:register_tooltips()
    walk_subviews(self.window, function(view)
        dwarfui_tooltip.register(view)
    end)
end

function SoulSearchScreen:unregister_tooltips()
    walk_subviews(self.window, function(view)
        dwarfui_tooltip.unregister(view)
    end)
end

function SoulSearchScreen:onShow()
    screen_registry.add(self)
end

---@return boolean cleaned
function SoulSearchScreen:cleanup()
    if self.cleaned_up then return false end
    self.cleaned_up = true
    self:unregister_tooltips()
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
