--@ module=true

local gui = require('gui')
local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')
local ui_format = reqscript('internal/soulsearch/ui_format')

local BACKGROUND = dfhack.pen.parse{ch=32, fg=COLOR_BLACK, bg=COLOR_BLACK}
local TEXT = dfhack.pen.parse{fg=COLOR_WHITE, bg=COLOR_BLACK}

-- A tooltip is presentation layered over the screen, not an interactive
-- window. In particular, widgets.Panel:updateLayout() requests a global full
-- screen refresh. A moving tooltip must not trigger that window lifecycle from
-- inside the render pass.
SoulSearchTooltip = defclass(SoulSearchTooltip, widgets.Widget)
SoulSearchTooltip.ATTRS{frame={l=0,t=0,w=1,h=3}, frame_style=gui.FRAME_THIN,
    frame_background=BACKGROUND, frame_inset=1, draggable=false,
    no_force_pause_badge=true, pointer_policy='none', visible=false}
function SoulSearchTooltip:init()
    self.visible = false
    self.tooltip_text = nil
    self.mouse_x = nil
    self.mouse_y = nil
    self.label = widgets.Label{frame={l=0,t=0,w=1,h=1}, auto_height=false,
        text_pen=TEXT, text=''}
    self:addviews{self.label}
end

---@param text string|nil
---@param mouse_x integer|nil
---@param mouse_y integer|nil
function SoulSearchTooltip:set_tooltip(text, mouse_x, mouse_y)
    local has_text = text ~= nil and text ~= ''
    local has_pointer = mouse_x ~= nil and mouse_y ~= nil
    local visible = has_text and has_pointer
    local tooltip_text = visible and text or nil
    local changed = self.visible ~= visible or self.tooltip_text ~= tooltip_text or
        self.mouse_x ~= mouse_x or self.mouse_y ~= mouse_y
    self.visible = visible
    self.tooltip_text = tooltip_text
    self.mouse_x = mouse_x
    self.mouse_y = mouse_y
    if self.visible then
        local sw, sh = dfhack.screen.getWindowSize()
        local lines = ui_format.wrap_text(
            self.tooltip_text, math.max(1, math.min(60, sw - 2)))
        local width = 2
        for _, line in ipairs(lines) do width = math.max(width, #line + 2) end
        local height = #lines + 2
        self.frame={l=math.max(0, math.min(mouse_x + 2, sw - width)),
            t=math.max(0, math.min(mouse_y + 1, sh - height)), w=width, h=height}
        self.label.frame={l=0,t=0,w=width-2,h=height-2}
        self.label:setText(table.concat(lines, '\n'))
        self:updateLayout()
    else
        self.label:setText('')
    end
    -- A child-view visibility change does not itself redraw the old frame.
    -- Requesting the owning screen repaint makes mouse-out removal immediate.
    if changed and self.parent_view and self.parent_view.invalidate then
        self.parent_view:invalidate()
    end
end

function SoulSearchTooltip:render(dc)
    if not self.visible then return end
    SoulSearchTooltip.super.render(self, dc)
end

function SoulSearchTooltip:onRenderFrame(dc, rect)
    if self.frame_background then dc:fill(rect, self.frame_background) end
    gui.paint_frame(dc, rect, self.frame_style)
end
return SoulSearchTooltip
