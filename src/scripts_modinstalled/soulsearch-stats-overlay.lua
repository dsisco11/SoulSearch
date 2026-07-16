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

local function union_frames(a, b)
    local l, t = math.min(a.l, b.l), math.min(a.t, b.t)
    local r = math.max(a.l + a.w, b.l + b.w)
    local bottom = math.max(a.t + a.h, b.t + b.h)
    return {l=l, t=t, w=r - l, h=bottom - t}
end

local function relative_frame(frame, parent)
    return {l=frame.l - parent.l, t=frame.t - parent.t, w=frame.w, h=frame.h}
end

local function absolute_origin(frame, parent_rect)
    if not frame or not parent_rect or not frame.w or not frame.h then return nil end
    local l = frame.l
    local t = frame.t
    if l == nil and frame.r ~= nil then
        l = parent_rect.width - frame.r - frame.w
    end
    if t == nil and frame.b ~= nil then
        t = parent_rect.height - frame.b - frame.h
    end
    if type(l) ~= 'number' or type(t) ~= 'number' then return nil end
    return {l=l, t=t}
end

local function same_origin(a, b)
    return a and b and a.l == b.l and a.t == b.t
end

StatsDeploymentButton = defclass(StatsDeploymentButton, widgets.TextButton)
StatsDeploymentButton.ATTRS{
    direction=DEFAULT_NIL,
}

SoulSearchStatsOverlay = defclass(SoulSearchStatsOverlay, overlay.OverlayWidget)
SoulSearchStatsOverlay.ATTRS{
    desc='Display SoulSearch Stats beside the selected unit card.',
    version=18,
    default_enabled=true,
    default_pos={x=1, y=1}, -- replaced by resolve_frame() during layout
    hotspot=true,
    viewscreens=UNIT_CARD_FOCUS,
    frame={w=1, h=1},
    -- The button is anchored first; its direction deploys the panel away from the card.
    placement={
        {button=config.BUTTON_PLACEMENT.OUTSIDE_LEFT, direction=config.DIRECTION.LEFT},
        {button=config.BUTTON_PLACEMENT.OUTSIDE_RIGHT, direction=config.DIRECTION.RIGHT},
    },
    overlay_onupdate_max_freq_seconds=0,
}

function SoulSearchStatsOverlay:init()
    self.tooltip = Tooltip{}
    self.collapsed = false
    self:addviews{
        widgets.Window{
            view_id='window', frame={l=0, t=0, r=0, b=0},
            frame_style=gui.FRAME_THIN, draggable=false, resizable=false,
            subviews={
                UnitStatsList{
                    view_id='stats_panel', frame={l=0, t=0, r=0, b=0},
                    subject=nil, sort=config.OVERLAY_DEFAULT_SORT, adaptive_columns=true,
                },
            },
        },
        StatsDeploymentButton{view_id='collapse_button', frame={l=0, t=0,
            w=config.COLLAPSE_BUTTON_WIDTH, h=1}, label=glyphs.CP437_TRIANGLE_UP,
            tooltip='Collapse the SoulSearch stats view.',
            on_activate=function() self:set_collapsed(true) end},
        StatsDeploymentButton{view_id='expand_button', frame={l=0, t=0,
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
    local resolved, err, source = config.resolve(
        width, height, get_unit_card_rect(), self.placement, self.repositioned_panel)
    if not resolved then
        if self.layout_error ~= err then
            self.layout_error = err
            dfhack.printerr(err)
        end
        return nil, err
    end
    self.layout_error = nil
    local frame = self.collapsed and {
        l=resolved.button.l, t=resolved.button.t,
        w=resolved.button.w, h=resolved.button.h,
    } or union_frames(resolved.panel, resolved.button)
    self.subviews.window.frame = relative_frame(resolved.panel, frame)
    local button_frame = relative_frame(resolved.button, frame)
    self.subviews.collapse_button.frame = button_frame
    self.subviews.expand_button.frame = button_frame
    self.subviews.collapse_button.direction = resolved.direction
    self.subviews.expand_button.direction = resolved.direction
    local key = frame_key(frame, source)
    self.frame = frame
    self.managed_origin = {l=frame.l, t=frame.t}
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
    local incoming_origin = absolute_origin(self.frame, parent_rect)
    if incoming_origin and self.managed_origin and
            not same_origin(incoming_origin, self.managed_origin) then
        if incoming_origin.l == 0 and incoming_origin.t == 0 then
            self.repositioned_panel = nil
        else
            local window_frame = self.subviews.window.frame
            self.repositioned_panel = {
                l=incoming_origin.l + (window_frame.l or 0),
                t=incoming_origin.t + (window_frame.t or 0),
            }
        end
    elseif incoming_origin and not self.managed_origin and
            (incoming_origin.l ~= 0 or incoming_origin.t ~= 0) then
        self.repositioned_panel = {
            l=incoming_origin.l, t=incoming_origin.t,
        }
    end
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
