--@ module=true

local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')
local creatures_scope = reqscript('internal/soulsearch/creatures_menu_scope')

local SOULSEARCH_COMMAND = 'soulsearch'
local UI_MODULE = 'internal/soulsearch/ui'
local BUTTON_LABEL = 'Open SoulSearch'
local BUTTON_WIDTH = #BUTTON_LABEL + 2 -- TextButton adds the surrounding brackets.
local BUTTON_LEFT_INSET = 2
local BUTTON_TOP_INSET = 3
local CREATURES_FOCUS = 'dwarfmode/Info/CREATURES'

local function get_creatures_menu_rect()
    local game = df.global and df.global.game
    local main_interface = game and game.main_interface
    local info = main_interface and main_interface.info
    local creatures = info and info.creatures
    local rect = creatures and creatures.rect
    if not rect then return nil end
    local ok, x1, y1, x2, y2 = pcall(
        function() return rect.x1, rect.y1, rect.x2, rect.y2 end)
    if not ok or type(x1) ~= 'number' or type(y1) ~= 'number' or
            type(x2) ~= 'number' or type(y2) ~= 'number' then
        return nil
    end
    return {x1=x1, y1=y1, x2=x2, y2=y2}
end

local function frame_key(frame)
    return ('%d,%d,%d,%d'):format(frame.l, frame.t, frame.w, frame.h)
end

SoulSearchCreaturesOverlay = defclass(
    SoulSearchCreaturesOverlay, overlay.OverlayWidget)
SoulSearchCreaturesOverlay.ATTRS{
    desc='Open SoulSearch scoped to the active Creatures tab.',
    version=9,
    default_enabled=true,
    default_pos={x=-2, y=2},
    frame={w=BUTTON_WIDTH, h=1},
    -- Residents has only this base focus; PET, OTHER, and DECEASED add a
    -- suffix. Resolve the live tab below to hide unsupported subcontexts.
    viewscreens=CREATURES_FOCUS,
    hotspot=true,
    overlay_onupdate_max_freq_seconds=0,
    active=function() return creatures_scope.get_active() ~= nil end,
}

function SoulSearchCreaturesOverlay:init()
    self:addviews{
        widgets.TextButton{
            view_id='open_scoped_search', frame={l=0, t=0, r=0, h=1},
            label=BUTTON_LABEL,
            tooltip='Open SoulSearch scoped to the active Creatures tab.',
            on_activate=function() self:open_scoped_search() end,
        },
    }
end

function SoulSearchCreaturesOverlay:resolve_frame(width, height)
    if type(width) ~= 'number' or type(height) ~= 'number' then return nil end
    width, height = math.floor(width), math.floor(height)
    local menu_rect = get_creatures_menu_rect()
    local frame = {
        l=menu_rect and math.max(0,
            math.min(width - BUTTON_WIDTH,
                menu_rect.x1 + BUTTON_LEFT_INSET)) or
            math.max(0, math.min(width - BUTTON_WIDTH, BUTTON_LEFT_INSET)),
        t=menu_rect and math.max(0, math.min(height - 1,
            menu_rect.y1 + BUTTON_TOP_INSET)) or
            math.max(0, math.min(height - 1, BUTTON_TOP_INSET)),
        w=BUTTON_WIDTH,
        h=1,
    }
    self.frame = frame
    self.frame_key = frame_key(frame)
    return frame
end

function SoulSearchCreaturesOverlay:preUpdateLayout(parent_rect)
    self:resolve_frame(parent_rect.width, parent_rect.height)
end

---Keeps the button docked to the rendered Creatures menu after UI changes.
function SoulSearchCreaturesOverlay:overlay_onupdate()
    local width, height = dfhack.screen.getWindowSize()
    local previous_key = self.frame_key
    local frame = self:resolve_frame(width, height)
    if frame and self.frame_key ~= previous_key and self.frame_parent_rect then
        self:updateLayout()
    end
    return false
end

---@return boolean opened
function SoulSearchCreaturesOverlay:open_scoped_search()
    local scope = creatures_scope.get_active()
    if not scope then return false end
    local modules = reqscript(SOULSEARCH_COMMAND).initialize()
    local ui = assert(modules[UI_MODULE],
        'SoulSearch runtime did not provide its UI module.')
    return ui.open(scope.options) ~= nil
end

OVERLAY_WIDGETS = {soulsearch_creatures=SoulSearchCreaturesOverlay}
