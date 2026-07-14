--@ module=true

local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

UNIT_CARD_FOCUS = 'dwarfmode/ViewSheets/UNIT'
BUTTON_LABEL = 'Stats'
BUTTON_WIDTH = #BUTTON_LABEL
BUTTON_HEIGHT = 1
WIDGET_KEY = 'soulsearch_stats'

local function has_unit_card_focus()
    local screen = dfhack.gui.getCurViewscreen(true)
    for _, focus in ipairs(dfhack.gui.getFocusStrings(screen) or {}) do
        if focus == UNIT_CARD_FOCUS then return true end
    end
    return false
end

local function report(error)
    if error then dfhack.printerr(error) end
end

---@return SoulSearchStatsPopoverScreen|nil
function activate()
    if not has_unit_card_focus() then
        report('SoulSearch Stats is only available from a unit card.')
        return nil
    end
    local unit = dfhack.gui.getSelectedUnit(true)
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
    desc='Open SoulSearch Stats for the unit on this card.',
    version=1,
    default_enabled=true,
    default_pos={x=-2, y=-2},
    viewscreens=UNIT_CARD_FOCUS,
    frame={w=BUTTON_WIDTH, h=BUTTON_HEIGHT},
}

function SoulSearchStatsOverlay:init()
    self:addviews{
        widgets.Label{
            view_id='button_label', frame={l=0, t=0, w=BUTTON_WIDTH, h=BUTTON_HEIGHT},
            text=BUTTON_LABEL,
        },
    }
end

function SoulSearchStatsOverlay:onInput(keys)
    if keys._MOUSE_L then
        local x, y = self:getMousePos()
        if x and y and x >= 0 and x < BUTTON_WIDTH and y >= 0 and y < BUTTON_HEIGHT then
            activate()
            return true
        end
    end
    return SoulSearchStatsOverlay.super.onInput(self, keys)
end

function SoulSearchStatsOverlay:overlay_trigger()
    return activate()
end

OVERLAY_WIDGETS = {[WIDGET_KEY]=SoulSearchStatsOverlay}
