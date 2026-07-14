--@ module=true

local gui = require('gui')
local widgets = require('gui.widgets')
local residents = reqscript('internal/soulsearch/residents')
local subject_factory = reqscript('internal/soulsearch/stats_subject')
local config = reqscript('internal/soulsearch/stats_popover_config')
local StatsPanel = reqscript('internal/soulsearch/stats_panel').SoulSearchStatsPanel
local Tooltip = reqscript('internal/soulsearch/ui_tooltip').SoulSearchTooltip
local screen_registry = reqscript('internal/soulsearch/screen_registry')

local singleton

local function copy_sort(sort)
    return {key=sort.key, reverse=sort.reverse, phase=sort.phase}
end

local function is_active(screen)
    if not screen or screen.cleaned_up then return false end
    if type(screen.isActive) == 'function' then
        local ok, active = pcall(screen.isActive, screen)
        return ok and active
    end
    return not screen.dismissed
end

local function raise(screen)
    if type(screen.raise) == 'function' then screen:raise() end
    return screen
end

---Returns the native unit-sheet tab container rectangle when DF exposes it.
---The overlay never retains this widget; every layout pass resolves it again.
---@return any|nil
local function get_unit_card_rect()
    local gui_api = dfhack.gui
    local sheets = df.global and df.global.game and df.global.game.main_interface and
        df.global.game.main_interface.view_sheets
    if not gui_api or not gui_api.getWidget or not sheets then return nil end
    local ok, widget = pcall(gui_api.getWidget, sheets, 'Tabs')
    if not ok or not widget then return nil end
    local ok_rect, rect = pcall(function() return widget.rect end)
    return ok_rect and rect or nil
end

---@param rect any|nil
---@return string
local function format_rect(rect)
    if not rect then return 'unavailable' end
    local ok, text = pcall(function()
        return ('(%d,%d)-(%d,%d)'):format(rect.x1, rect.y1, rect.x2, rect.y2)
    end)
    return ok and text or 'unavailable'
end

---@param frame table
---@param source string|nil
---@param rect any|nil
local function log_position(frame, source, rect)
    if not config.LOG_POSITIONING then return end
    dfhack.println(('SoulSearch Stats placement: %s; unit-card rect=%s; frame=(%d,%d %dx%d)'):
        format(source or 'unknown', format_rect(rect), frame.l, frame.t, frame.w, frame.h))
end

SoulSearchStatsPopoverScreen = defclass(SoulSearchStatsPopoverScreen, gui.ZScreenModal)
SoulSearchStatsPopoverScreen.ATTRS{
    focus_path='soulsearch/stats',
    subject=DEFAULT_NIL,
    frame=DEFAULT_NIL,
}

function SoulSearchStatsPopoverScreen:init(info)
    self.subject = info.subject
    self.exclude_from_placement = true
    self.window = widgets.Window{
        view_id='stats_popover_window',
        frame=info.frame,
        frame_style=gui.FRAME_BOLD,
        draggable=false,
        resizable=false,
        subviews={
            StatsPanel{
                view_id='stats_panel', frame={l=0, t=0, r=0, b=0},
                subject=self.subject, sort=copy_sort(config.DEFAULT_SORT),
            },
            widgets.TextButton{
                view_id='close_button',
                frame={r=0, t=0, w=config.CLOSE_WIDTH, h=1},
                label='X', on_activate=function() self:dismiss() end,
            },
        },
    }
    self:addviews{
        self.window,
        Tooltip{get_text=function()
            return self.window.subviews.stats_panel:get_tooltip_text() or ''
        end},
    }
end

function SoulSearchStatsPopoverScreen:onShow()
    SoulSearchStatsPopoverScreen.super.onShow(self)
    screen_registry.add(self)
end

function SoulSearchStatsPopoverScreen:cleanup()
    if self.cleaned_up then return false end
    self.cleaned_up = true
    screen_registry.remove(self)
    if singleton == self then singleton = nil end
    return true
end

function SoulSearchStatsPopoverScreen:onDismiss() self:cleanup() end
function SoulSearchStatsPopoverScreen:onDestroy() self:cleanup() end
function SoulSearchStatsPopoverScreen:onGetSelectedUnit()
    return self.subject and self.subject.unit or nil
end

function SoulSearchStatsPopoverScreen:set_subject(subject)
    self.subject = subject
    local panel = self.window.subviews.stats_panel
    panel:set_subject(subject)
    panel:reset_view_state(copy_sort(config.DEFAULT_SORT))
end

function SoulSearchStatsPopoverScreen:onResize(w, h)
    SoulSearchStatsPopoverScreen.super.onResize(self, w, h)
    local rect = get_unit_card_rect()
    local frame, err, source = config.resolve(w, h, rect)
    if not frame then
        if not self.resize_error_reported then
            self.resize_error_reported = true
            print(err)
        end
        self:dismiss()
        return
    end
    self.window.frame = frame
    self.window:updateLayout()
    log_position(frame, source, rect)
end

---@param unit any
---@return SoulSearchStatsSubject|nil
---@return string|nil
local function build_subject(unit)
    local unavailable = residents.get_unavailable_reason()
    if unavailable then return nil, unavailable end
    local unit_id, err = residents.validate_unit_reference(unit)
    if not unit_id then return nil, err end
    if not df.unit.find or df.unit.find(unit_id) ~= unit then
        return nil, 'SoulSearch requires a current unit.'
    end
    local row
    row, err = residents.collect_unit(unit)
    if not row then return nil, err end
    return subject_factory.from_row(row, {}), nil
end

---Builds a stats subject for callers that render the reusable panel without a
---modal screen (for example, the attached unit-card overlay).
function get_subject(unit)
    return build_subject(unit)
end

---@param unit any
---@return SoulSearchStatsPopoverScreen|nil
---@return string|nil
function open(unit)
    local subject, err = build_subject(unit)
    if not subject then return nil, err end
    local width, height = dfhack.screen.getWindowSize()
    local frame
    local rect = get_unit_card_rect()
    frame, err, source = config.resolve(width, height, rect)
    if not frame then return nil, err end
    if not is_active(singleton) then singleton = nil end
    if singleton then
        if singleton.subject.unit_id == subject.unit_id then return raise(singleton), nil end
        singleton:set_subject(subject)
        return raise(singleton), nil
    end
    local screen = SoulSearchStatsPopoverScreen{subject=subject, frame=frame}:show()
    log_position(frame, source, rect)
    singleton = screen
    return screen, nil
end

function clear_singleton() singleton = nil end
function get_singleton() return singleton end
