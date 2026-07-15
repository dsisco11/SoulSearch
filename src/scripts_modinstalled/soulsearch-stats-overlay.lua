--@ module=true

local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')
reqscript('internal/soulsearch/ui/widget_extensions')
local config = reqscript('internal/soulsearch/stats_popover_config')
local popover = reqscript('internal/soulsearch/stats_popover')
local UnitStatsList = reqscript('internal/soulsearch/ui/unit_stats_list').UnitStatsList
local Tooltip = reqscript('internal/soulsearch/ui_tooltip').SoulSearchTooltip

UNIT_CARD_FOCUS = 'dwarfmode/ViewSheets/UNIT'
WIDGET_KEY = 'soulsearch_stats'

local function has_unit_card_focus()
    local screen = dfhack.gui.getCurViewscreen(true)
    for _, focus in ipairs(dfhack.gui.getFocusStrings(screen) or {}) do
        if focus:sub(1, #UNIT_CARD_FOCUS) == UNIT_CARD_FOCUS then return true end
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
    local sheets = df.global and df.global.game and df.global.game.main_interface and
        df.global.game.main_interface.view_sheets
    if not sheets or not dfhack.gui.getWidget then return nil end
    local ok, widget = pcall(dfhack.gui.getWidget, sheets, 'Tabs')
    if not ok or not widget then return nil end
    local ok_rect, rect = pcall(function() return widget.rect end)
    return ok_rect and rect or nil
end

local function frame_key(frame, source)
    return ('%s:%d,%d,%d,%d'):format(source or 'unknown',
        frame.l, frame.t, frame.w, frame.h)
end

SoulSearchStatsOverlay = defclass(SoulSearchStatsOverlay, overlay.OverlayWidget)
SoulSearchStatsOverlay.ATTRS{
    desc='Display SoulSearch Stats beside the selected unit card.',
    version=3,
    default_enabled=true,
    default_pos={x=1, y=1}, -- replaced by resolve_frame() during layout
    hotspot=true,
    viewscreens=UNIT_CARD_FOCUS,
    frame={w=1, h=1},
    overlay_onupdate_max_freq_seconds=0,
}

function SoulSearchStatsOverlay:init()
    self:addviews{
        widgets.Window{
            view_id='window', frame={l=0, t=0, r=0, b=0},
            frame_style=gui.FRAME_BOLD, draggable=false, resizable=false,
            subviews={
                UnitStatsList{
                    view_id='stats_panel', frame={l=0, t=0, r=0, b=0},
                    subject=nil, sort=config.DEFAULT_SORT,
                },
            },
        },
        Tooltip{get_text=function()
            return self.subviews.window.subviews.stats_panel:get_tooltip_text() or ''
        end},
    }
end

function SoulSearchStatsOverlay:resolve_frame(width, height)
    local frame, err, source = config.resolve(width, height, get_unit_card_rect())
    if not frame then return nil, err end
    local key = frame_key(frame, source)
    self.frame = frame
    if key ~= self.frame_key then
        self.frame_key = key
    end
    return frame
end

function SoulSearchStatsOverlay:preUpdateLayout(parent_rect)
    self:resolve_frame(parent_rect.width, parent_rect.height)
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
