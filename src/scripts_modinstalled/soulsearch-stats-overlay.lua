--@ module=true

local overlay = require('plugins.overlay')

UNIT_CARD_FOCUS = 'dwarfmode/ViewSheets/UNIT'
WIDGET_KEY = 'soulsearch_stats'

local function has_unit_card_focus()
    local screen = dfhack.gui.getCurViewscreen(true)
    for _, focus in ipairs(dfhack.gui.getFocusStrings(screen) or {}) do
        -- Unit-card tabs report a more specific focus such as
        -- dwarfmode/ViewSheets/UNIT/Overview. Match the same prefix rule the
        -- overlay framework uses for its viewscreens declaration.
        if focus:sub(1, #UNIT_CARD_FOCUS) == UNIT_CARD_FOCUS then return true end
    end
    return false
end

local function report(error)
    if error then dfhack.printerr(error) end
end

---@return df.unit|nil
local function get_unit_card_unit()
    local game = df.global and df.global.game
    local main_interface = game and game.main_interface
    local view_sheets = main_interface and main_interface.view_sheets
    if not view_sheets or not df.unit or not df.unit.find then return nil end
    return df.unit.find(view_sheets.active_id)
end

---@return SoulSearchStatsPopoverScreen|nil
function activate()
    if not has_unit_card_focus() then
        report('SoulSearch Stats is only available from a unit card.')
        return nil
    end
    -- The native unit card owns its subject in view_sheets.active_id. It is
    -- not exposed consistently through dfhack.gui.getSelectedUnit().
    local unit = get_unit_card_unit()
    if not unit then
        report('SoulSearch Stats requires a selected unit.')
        return nil
    end
    -- Resolve this at activation time so an overlay surviving a development
    -- rescan cannot retain a stale popover module table.
    local screen, error = reqscript('internal/soulsearch/stats_popover').open(unit)
    if not screen then report(error) end
    return screen
end

SoulSearchStatsOverlay = defclass(SoulSearchStatsOverlay, overlay.OverlayWidget)
SoulSearchStatsOverlay.ATTRS{
    desc='Automatically open SoulSearch Stats for the unit on this card.',
    version=2,
    default_enabled=true,
    visible=false,
    -- Unit-card overlays are rendered on the native viewscreen, but that
    -- render path does not guarantee a scheduled overlay_onupdate() call.
    -- A hotspot receives that callback independently; the focus guard below
    -- keeps activation scoped to the unit card.
    hotspot=true,
    viewscreens=UNIT_CARD_FOCUS,
    frame={w=1, h=1},
    overlay_onupdate_max_freq_seconds=0,
}

---The overlay framework calls this while rendering a matching unit card. A
---true result invokes overlay_trigger(), which opens the singleton popover.
function SoulSearchStatsOverlay:overlay_onupdate()
    return has_unit_card_focus() and get_unit_card_unit() ~= nil
end

function SoulSearchStatsOverlay:overlay_trigger()
    return activate()
end

OVERLAY_WIDGETS = {[WIDGET_KEY]=SoulSearchStatsOverlay}
