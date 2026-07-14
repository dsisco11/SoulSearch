--@ module=true

local gui = require('gui')
local widgets = require('gui.widgets')
local ui_format = reqscript('internal/soulsearch/ui_format')

local BACKGROUND = dfhack.pen.parse{ch=32, fg=COLOR_BLACK, bg=COLOR_BLACK}
local TEXT = dfhack.pen.parse{fg=COLOR_WHITE, bg=COLOR_BLACK}

SoulSearchTooltip = defclass(SoulSearchTooltip, widgets.Window)
SoulSearchTooltip.ATTRS{frame={l=0,t=0,w=1,h=3}, frame_style=gui.FRAME_THIN,
    frame_background=BACKGROUND, frame_inset=0, draggable=false,
    no_force_pause_badge=true, get_text=DEFAULT_NIL}
function SoulSearchTooltip:init()
    self.label = widgets.Label{frame={l=0,t=0,w=1,h=1}, auto_height=false,
        text_pen=TEXT, text=''}
    self:addviews{self.label}
end
function SoulSearchTooltip:render(dc)
    local mouse_x, mouse_y = dfhack.screen.getMousePos()
    local text = self.get_text and self.get_text() or ''
    if not mouse_x or text == '' then return end
    local sw, sh = dfhack.screen.getWindowSize()
    local lines = ui_format.wrap_text(text, math.max(1, math.min(60, sw - 2)))
    local width = 2
    for _, line in ipairs(lines) do width = math.max(width, #line + 2) end
    local height = #lines + 2
    self.frame={l=math.max(0, math.min(mouse_x + 2, sw - width)),
        t=math.max(0, math.min(mouse_y + 1, sh - height)), w=width, h=height}
    self.label.frame={l=0,t=0,w=width-2,h=height-2}
    self.label:setText(table.concat(lines, '\n'))
    self:updateLayout()
    SoulSearchTooltip.super.render(self, dc)
end
return SoulSearchTooltip
