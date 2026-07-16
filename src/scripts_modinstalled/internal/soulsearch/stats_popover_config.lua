--@ module=true

local layout = reqscript('internal/soulsearch/stats_layout')

---@enum SoulSearchStatsPlacement
PLACEMENT = {
    OUTSIDE_LEFT='outside-left',
    OUTSIDE_RIGHT='outside-right',
    INSIDE_LEFT='inside-left',
    INSIDE_RIGHT='inside-right',
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
---@param placement SoulSearchStatsPlacement
---@return table|nil
local function resolve_from_unit_card(
        rect, screen_width, screen_height, width, height, placement)
    if not rect then return nil end
    local x1 = get_integer(rect, 'x1')
    local x2 = get_integer(rect, 'x2')
    local y1 = get_integer(rect, 'y1')
    local y2 = get_integer(rect, 'y2')
    if not x1 or not x2 or not y1 or not y2 or y2 < y1 then return nil end

    local l
    if placement == PLACEMENT.OUTSIDE_LEFT then
        l = x1 - width - UNIT_CARD_GAP
    elseif placement == PLACEMENT.OUTSIDE_RIGHT then
        l = x2 + 1 + UNIT_CARD_GAP
    elseif placement == PLACEMENT.INSIDE_LEFT then
        l = x1 + UNIT_CARD_GAP
    elseif placement == PLACEMENT.INSIDE_RIGHT then
        l = x2 - width - UNIT_CARD_GAP + 1
    end
    if (placement == PLACEMENT.INSIDE_LEFT or placement == PLACEMENT.INSIDE_RIGHT) and
            (l < x1 or l + width - 1 > x2) then
        return nil
    end
    if l < 0 or l + width > screen_width then return nil end
    local t = y1 + math.floor((y2 - y1 + 1 - height) / 2)
    return {l=l, t=math.max(0, math.min(t, screen_height - height)), w=width, h=height}
end

local VALID_PLACEMENTS = {
    [PLACEMENT.OUTSIDE_LEFT]=true,
    [PLACEMENT.OUTSIDE_RIGHT]=true,
    [PLACEMENT.INSIDE_LEFT]=true,
    [PLACEMENT.INSIDE_RIGHT]=true,
}

---@param placements SoulSearchStatsPlacement[]
local function validate_placements(placements)
    assert(type(placements) == 'table' and #placements > 0,
        'SoulSearch Stats placement must be a non-empty list.')
    local count = 0
    for index, placement in ipairs(placements) do
        count = index
        assert(VALID_PLACEMENTS[placement],
            ('Unsupported SoulSearch Stats placement: %s'):format(tostring(placement)))
    end
    for key in pairs(placements) do
        assert(type(key) == 'number' and key % 1 == 0 and key >= 1 and key <= count,
            'SoulSearch Stats placement must be an ordered list.')
    end
end

---@param screen_width integer
---@param screen_height integer
---@param unit_card_rect any|nil
---@param placements SoulSearchStatsPlacement[] ordered placement fallbacks
---@return table|nil frame
---@return string|nil error
---@return string|nil source
function resolve(screen_width, screen_height, unit_card_rect, placements)
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
    for _, placement in ipairs(placements) do
        local native_frame = resolve_from_unit_card(
            unit_card_rect, screen_width, screen_height, width, height, placement)
        if native_frame then
            return native_frame, nil,
                ('native unit-card bounds (%s)'):format(placement)
        end
    end
    return nil, 'SoulSearch Stats popout requires outer unit-card bounds.'
end
