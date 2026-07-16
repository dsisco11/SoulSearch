--@ module=true

local layout = reqscript('internal/soulsearch/stats_layout')

---@enum SoulSearchStatsButtonPlacement
BUTTON_PLACEMENT = {
    OUTSIDE_LEFT='outside-left',
    OUTSIDE_RIGHT='outside-right',
    INSIDE_LEFT='inside-left',
    INSIDE_RIGHT='inside-right',
}

---@enum SoulSearchStatsDirection
DIRECTION = {
    LEFT='left',
    RIGHT='right',
    UP='up',
    DOWN='down',
}

FRAME_INSET = 1 -- The window frame contributes one tile on every edge.
CLOSE_WIDTH = 3 -- TextButton's banner margins plus its X label.
COLLAPSE_BUTTON_WIDTH = 3 -- Match the standard compact TextButton footprint.
UNIT_CARD_GAP = 1 -- Keep the popout visually separate from the vanilla card.
DEFAULT_WIDTH = math.max(layout.MIN_CONTENT_WIDTH + FRAME_INSET * 2, 36)
-- Leave enough room for a useful portion of the scrolling stats list.
DEFAULT_HEIGHT = math.max(layout.MIN_CONTENT_HEIGHT + FRAME_INSET * 2, 20)
MIN_WIDTH = math.max(layout.MIN_CONTENT_WIDTH + FRAME_INSET * 2, CLOSE_WIDTH + 8)
MIN_HEIGHT = layout.MIN_CONTENT_HEIGHT + FRAME_INSET * 2
DEFAULT_SORT = {key=nil, reverse=false, phase=0}
-- The attached popout opens on the first Delta sort mode (descending), while
-- reusable lists retain their caller-provided default sort state.
OVERLAY_DEFAULT_SORT = {key='value', reverse=true, phase=1}
---@return table
function get_minimum()
    return {w=MIN_WIDTH, h=MIN_HEIGHT}
end

---@param rect any
---@param key string
---@return integer|nil
local function get_integer(rect, key)
    local ok, value = pcall(function() return rect[key] end)
    if not ok or type(value) ~= 'number' then return nil end
    return math.floor(value)
end

---@param rect any
---@param screen_width integer
---@param screen_height integer
---@param width integer
---@param height integer
---@class SoulSearchStatsDeployment
---@field button SoulSearchStatsButtonPlacement
---@field direction SoulSearchStatsDirection

---@param frame table
---@param screen_width integer
---@param screen_height integer
---@return boolean
local function frame_fits(frame, screen_width, screen_height)
    return frame.l >= 0 and frame.t >= 0 and
        frame.l + frame.w <= screen_width and frame.t + frame.h <= screen_height
end

---@param placement SoulSearchStatsDeployment
---@return table|nil
local function resolve_from_unit_card(
        rect, screen_width, screen_height, width, height, placement)
    if not rect then return nil end
    local x1 = get_integer(rect, 'x1')
    local x2 = get_integer(rect, 'x2')
    local y1 = get_integer(rect, 'y1')
    local y2 = get_integer(rect, 'y2')
    if not x1 or not x2 or not y1 or not y2 or x2 < x1 or y2 < y1 then return nil end

    local panel = {w=width, h=height}
    local button = {w=COLLAPSE_BUTTON_WIDTH, h=1}
    if placement.button == BUTTON_PLACEMENT.OUTSIDE_LEFT then
        button.l = x1 - UNIT_CARD_GAP - button.w
    elseif placement.button == BUTTON_PLACEMENT.OUTSIDE_RIGHT then
        button.l = x2 + 1 + UNIT_CARD_GAP
    elseif placement.button == BUTTON_PLACEMENT.INSIDE_LEFT then
        button.l = x1
    elseif placement.button == BUTTON_PLACEMENT.INSIDE_RIGHT then
        button.l = x2 - button.w + 1
    end

    if placement.direction == DIRECTION.LEFT or placement.direction == DIRECTION.RIGHT then
        button.t = y1 + math.floor((y2 - y1 + 1 - button.h) / 2)
    elseif placement.direction == DIRECTION.UP then
        button.t = y1
    elseif placement.direction == DIRECTION.DOWN then
        button.t = y2 - button.h + 1
    end

    if placement.direction == DIRECTION.LEFT then
        panel.l = button.l + button.w - panel.w
    elseif placement.direction == DIRECTION.RIGHT then
        panel.l = button.l
    elseif placement.direction == DIRECTION.UP then
        panel.l = placement.button == BUTTON_PLACEMENT.INSIDE_LEFT and button.l or
            button.l + button.w - panel.w
        panel.t = button.t - panel.h
    elseif placement.direction == DIRECTION.DOWN then
        panel.l = placement.button == BUTTON_PLACEMENT.INSIDE_LEFT and button.l or
            button.l + button.w - panel.w
        panel.t = button.t + button.h
    end

    if placement.direction == DIRECTION.LEFT or placement.direction == DIRECTION.RIGHT then
        local below = button.t + button.h
        local above = button.t - panel.h
        if below + panel.h <= screen_height then
            panel.t = below
        elseif above >= 0 then
            panel.t = above
        else
            return nil
        end
    end

    if not frame_fits(panel, screen_width, screen_height) or
            not frame_fits(button, screen_width, screen_height) then
        return nil
    end
    return {panel=panel, button=button, direction=placement.direction}
end

local VALID_BUTTON_PLACEMENTS = {
    [BUTTON_PLACEMENT.OUTSIDE_LEFT]=true,
    [BUTTON_PLACEMENT.OUTSIDE_RIGHT]=true,
    [BUTTON_PLACEMENT.INSIDE_LEFT]=true,
    [BUTTON_PLACEMENT.INSIDE_RIGHT]=true,
}

local VALID_DIRECTIONS = {
    [DIRECTION.LEFT]=true,
    [DIRECTION.RIGHT]=true,
    [DIRECTION.UP]=true,
    [DIRECTION.DOWN]=true,
}

---@param placements SoulSearchStatsDeployment[]
local function validate_placements(placements)
    assert(type(placements) == 'table' and #placements > 0,
        'SoulSearch Stats placement must be a non-empty list.')
    local count = 0
    for index, placement in ipairs(placements) do
        count = index
        assert(type(placement) == 'table',
            'Each SoulSearch Stats placement must be a table.')
        assert(VALID_BUTTON_PLACEMENTS[placement.button],
            ('Unsupported SoulSearch Stats button placement: %s'):
                format(tostring(placement.button)))
        assert(VALID_DIRECTIONS[placement.direction],
            ('Unsupported SoulSearch Stats deployment direction: %s'):
                format(tostring(placement.direction)))
        if placement.button == BUTTON_PLACEMENT.OUTSIDE_LEFT then
            assert(placement.direction == DIRECTION.LEFT,
                'An outside-left stats button must deploy left.')
        elseif placement.button == BUTTON_PLACEMENT.OUTSIDE_RIGHT then
            assert(placement.direction == DIRECTION.RIGHT,
                'An outside-right stats button must deploy right.')
        else
            assert(placement.direction == DIRECTION.UP or
                    placement.direction == DIRECTION.DOWN,
                'A stats button inside the unit card must deploy up or down.')
        end
    end
    for key in pairs(placements) do
        assert(type(key) == 'number' and key % 1 == 0 and key >= 1 and key <= count,
            'SoulSearch Stats placement must be an ordered list.')
    end
end

---@param position table
---@param screen_width integer
---@param screen_height integer
---@param width integer
---@param height integer
---@param rect any
---@return table|nil
local function resolve_from_repositioned_panel(
        position, screen_width, screen_height, width, height, rect)
    local x1 = get_integer(rect, 'x1')
    local x2 = get_integer(rect, 'x2')
    local y1 = get_integer(rect, 'y1')
    local y2 = get_integer(rect, 'y2')
    local panel = {l=position.l, t=position.t, w=width, h=height}
    if not x1 or not x2 or not y1 or not y2 or x2 < x1 or y2 < y1 or
            not frame_fits(panel, screen_width, screen_height) then
        return nil
    end

    local button = {w=COLLAPSE_BUTTON_WIDTH, h=1}
    if panel.l + panel.w <= x1 then
        button.l = panel.l + panel.w - button.w
    elseif panel.l > x2 then
        button.l = panel.l
    else
        local panel_center = panel.l + (panel.w - 1) / 2
        local card_center = x1 + (x2 - x1) / 2
        button.l = panel_center <= card_center and panel.l + panel.w - button.w or panel.l
    end

    local direction
    local above = panel.t - button.h
    local below = panel.t + panel.h
    if above >= 0 then
        button.t = above
        direction = DIRECTION.DOWN
    elseif below + button.h <= screen_height then
        button.t = below
        direction = DIRECTION.UP
    else
        return nil
    end

    if not frame_fits(button, screen_width, screen_height) then return nil end
    return {panel=panel, button=button, direction=direction}
end

---@param screen_width integer
---@param screen_height integer
---@param unit_card_rect any|nil
---@param placements SoulSearchStatsDeployment[] ordered placement fallbacks
---@param repositioned_panel table|nil absolute user-selected panel origin
---@return table|nil layout
---@return string|nil error
---@return string|nil source
function resolve(screen_width, screen_height, unit_card_rect, placements, repositioned_panel)
    validate_placements(placements)
    if type(screen_width) ~= 'number' or type(screen_height) ~= 'number' then
        return nil, 'SoulSearch Stats popout requires a valid screen size.'
    end
    screen_width, screen_height = math.floor(screen_width), math.floor(screen_height)
    if screen_width < MIN_WIDTH or screen_height < MIN_HEIGHT then
        return nil, ('SoulSearch Stats popout requires at least %dx%d tiles.'):
            format(MIN_WIDTH, MIN_HEIGHT)
    end
    local width = math.min(DEFAULT_WIDTH, screen_width)
    local height = math.min(DEFAULT_HEIGHT, screen_height)
    if repositioned_panel then
        local repositioned_layout = resolve_from_repositioned_panel(
            repositioned_panel, screen_width, screen_height, width, height, unit_card_rect)
        if repositioned_layout then
            return repositioned_layout, nil, 'user-positioned stats panel'
        end
        return nil, 'SoulSearch Stats cannot deploy from the repositioned panel.'
    end
    for _, placement in ipairs(placements) do
        local native_layout = resolve_from_unit_card(
            unit_card_rect, screen_width, screen_height, width, height, placement)
        if native_layout then
            return native_layout, nil,
                ('native unit-card bounds (%s, %s)'):
                    format(placement.button, placement.direction)
        end
    end
    return nil, 'SoulSearch Stats popout requires outer unit-card bounds.'
end
