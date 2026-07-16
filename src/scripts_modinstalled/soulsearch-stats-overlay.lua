--@ module=true

local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')
reqscript('internal/soulsearch/ui/widget_extensions')
local config = reqscript('internal/soulsearch/stats_popover_config')
local popover = reqscript('internal/soulsearch/stats_popover')
local glyphs = reqscript('internal/soulsearch/ui_glyphs')
local UnitStatsList = reqscript('internal/soulsearch/ui/unit_stats_list').UnitStatsList
local Tooltip = reqscript('internal/soulsearch/ui_tooltip').SoulSearchTooltip
local TooltipAgent = reqscript('internal/soulsearch/ui/tooltip_agent').TooltipAgent

UNIT_CARD_FOCUS = 'dwarfmode/ViewSheets/UNIT'
WIDGET_KEY = 'soulsearch_stats'

local function has_unit_card_focus()
    local screen = dfhack.gui.getCurViewscreen(true)
    while screen do
        for _, focus in ipairs(dfhack.gui.getFocusStrings(screen) or {}) do
            if focus:sub(1, #UNIT_CARD_FOCUS) == UNIT_CARD_FOCUS then return true end
        end
        screen = screen.parent
    end
    return false
end

---@return df.unit|nil
local function get_unit_card_unit()
    local game = df.global and df.global.game
    local main_interface = game and game.main_interface
    local view_sheets = main_interface and main_interface.view_sheets
    if not view_sheets or not df.unit or not df.unit.find then return nil end
    return df.unit.find(view_sheets.active_id)
end

local function get_unit_card_rect()
    -- view_sheets is vanilla/curses UI state, not a widget_container. Measure
    -- the rendered tab strip instead. "Overview" is inset two tiles from the
    -- vanilla unit card's left edge.
    if not dfhack.screen or not dfhack.screen.getWindowSize or not dfhack.screen.readTile then
        return nil
    end
    local width, height = dfhack.screen.getWindowSize()
    if type(width) ~= 'number' or type(height) ~= 'number' then return nil end

    local function row_text(y)
        local chars = {}
        for x = 0, width - 1 do
            local ok, tile = pcall(dfhack.screen.readTile, x, y)
            local ch = ok and tile and tile.ch
            chars[#chars + 1] = type(ch) == 'number' and ch >= 32 and ch <= 126 and
                string.char(ch) or ' '
        end
        return table.concat(chars)
    end

    for y = 0, height - 1 do
        local text = row_text(y)
        local overview_start = text:find('Overview', 1, true)
        if overview_start then
            local items_start = text:find('Items', overview_start + 8, true)
            if items_start and items_start - overview_start <= 16 then
                local tab_x = overview_start - 1 -- Lua strings are one-indexed.
                return {x1=tab_x - 2, y1=math.max(0, y - 2),
                        x2=width - 1, y2=height - 1}
            end
        end
    end
end

local function frame_key(frame, source)
    return ('%s:%d,%d,%d,%d'):format(source or 'unknown',
        frame.l, frame.t, frame.w, frame.h)
end

SoulSearchStatsOverlay = defclass(SoulSearchStatsOverlay, overlay.OverlayWidget)
SoulSearchStatsOverlay.ATTRS{
    desc='Display SoulSearch Stats beside the selected unit card.',
    version=12,
    default_enabled=true,
    default_pos={x=1, y=1}, -- replaced by resolve_frame() during layout
    hotspot=true,
    viewscreens=UNIT_CARD_FOCUS,
    frame={w=1, h=1},
    overlay_onupdate_max_freq_seconds=0,
}

function SoulSearchStatsOverlay:init()
    self.tooltip = Tooltip{}
    self.collapsed = false
    self:addviews{
        widgets.Window{
            view_id='window', frame={l=0, t=0, r=0, b=0},
            frame_style=gui.FRAME_BOLD, draggable=false, resizable=false,
            subviews={
                UnitStatsList{
                    view_id='stats_panel', frame={l=0, t=0, r=0, b=0},
                    subject=nil, sort=config.OVERLAY_DEFAULT_SORT, adaptive_columns=true,
                },
            },
        },
        widgets.TextButton{view_id='collapse_button', frame={r=0, t=0,
            w=config.COLLAPSE_BUTTON_WIDTH, h=1}, label=glyphs.CP437_TRIANGLE_UP,
            tooltip='Collapse the SoulSearch stats view.',
            on_activate=function() self:set_collapsed(true) end},
        widgets.TextButton{view_id='expand_button', frame={r=0, t=0,
            w=config.COLLAPSE_BUTTON_WIDTH, h=1}, label=glyphs.CP437_TRIANGLE_DOWN,
            tooltip='Expand the SoulSearch stats view.', visible=false,
            on_activate=function() self:set_collapsed(false) end},
    }
    -- Unlike the main SoulSearch screen, this is an offset and tightly
    -- clipped overlay. Render its tooltip separately, after the panel, so it
    -- can use screen-relative coordinates and extend beyond the popout.
    self.tooltip.parent_view = self
    self.tooltip_agent = TooltipAgent.new(self, self.tooltip)
end

function SoulSearchStatsOverlay:set_collapsed(collapsed)
    collapsed = not not collapsed
    if self.collapsed == collapsed then return end
    self.collapsed = collapsed
    self.subviews.window.visible = not collapsed
    self.subviews.collapse_button.visible = not collapsed
    self.subviews.expand_button.visible = collapsed
    local width, height = dfhack.screen.getWindowSize()
    self:resolve_frame(width, height)
    if self.frame_parent_rect then self:updateLayout() end
end

function SoulSearchStatsOverlay:resolve_frame(width, height)
    local panel_frame, err, source = config.resolve(
        width, height, get_unit_card_rect(), 'left')
    if not panel_frame then
        if self.layout_error ~= err then
            self.layout_error = err
            dfhack.printerr(err)
        end
        return nil, err
    end
    self.layout_error = nil
    local frame = {
        l=self.collapsed and panel_frame.l + panel_frame.w - config.COLLAPSE_BUTTON_WIDTH or
            panel_frame.l,
        t=panel_frame.t,
        w=self.collapsed and config.COLLAPSE_BUTTON_WIDTH or panel_frame.w,
        h=self.collapsed and 1 or panel_frame.h,
    }
    local key = frame_key(frame, source)
    self.frame = frame
    if key ~= self.frame_key then
        self.frame_key = key
    end
    return frame
end

function SoulSearchStatsOverlay:preUpdateLayout(parent_rect)
    -- Overlay registration and reload layout happen even while the vanilla
    -- unit card is closed. There is no card to measure in that state, so do
    -- not surface a geometry error to the player.
    if not has_unit_card_focus() then return end
    self:resolve_frame(parent_rect.width, parent_rect.height)
end

function SoulSearchStatsOverlay:onRenderFrame(dc, rect)
    self.tooltip_agent:update()
    SoulSearchStatsOverlay.super.onRenderFrame(self, dc, rect)
end

function SoulSearchStatsOverlay:render(dc)
    SoulSearchStatsOverlay.super.render(self, dc)
    if self.tooltip.visible then self.tooltip:render(dc) end
end

function SoulSearchStatsOverlay:update_subject(unit)
    if self.unit_id == unit.id then return end
    local subject, err = popover.get_subject(unit)
    if not subject then
        if self.subject_error ~= err then
            self.subject_error = err
            dfhack.printerr(err)
        end
        return
    end
    self.subject_error = nil
    self.unit_id = unit.id
    self.subviews.window.subviews.stats_panel:set_subject(subject)
end

---Synchronizes the attached panel; returning false prevents overlay_trigger.
function SoulSearchStatsOverlay:overlay_onupdate()
    if not has_unit_card_focus() then return false end
    local width, height = dfhack.screen.getWindowSize()
    local previous_key = self.frame_key
    local frame = self:resolve_frame(width, height)
    if frame and self.frame_key ~= previous_key and self.frame_parent_rect then
        self:updateLayout()
    end
    local unit = get_unit_card_unit()
    if unit then self:update_subject(unit) end
    return false
end

OVERLAY_WIDGETS = {[WIDGET_KEY]=SoulSearchStatsOverlay}
