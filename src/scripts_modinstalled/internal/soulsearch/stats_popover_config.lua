--@ module=true

local layout = reqscript('internal/soulsearch/stats_layout')

FRAME_INSET = 1 -- gui.FRAME_BOLD contributes one tile on every edge.
CLOSE_WIDTH = 3 -- TextButton's banner margins plus its X label.
DEFAULT_WIDTH = math.max(layout.MIN_CONTENT_WIDTH + FRAME_INSET * 2, 40)
-- Leave enough room for a useful portion of the scrolling stats list.
DEFAULT_HEIGHT = math.max(layout.MIN_CONTENT_HEIGHT + FRAME_INSET * 2, 20)
MIN_WIDTH = math.max(layout.MIN_CONTENT_WIDTH + FRAME_INSET * 2, CLOSE_WIDTH + 8)
MIN_HEIGHT = layout.MIN_CONTENT_HEIGHT + FRAME_INSET * 2
DEFAULT_SORT = {key=nil, reverse=false, phase=0}
-- unit-info-viewer's skills-progress overlay uses x=-43, which places its
-- right edge 42 tiles from the screen's right edge. Use that established unit
-- card boundary when the native widget tree cannot provide a live rectangle.
FALLBACK_UNIT_CARD_RIGHT_INSET = 42

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
---@return table|nil
local function resolve_from_unit_card(rect, screen_width, screen_height, width, height)
    if not rect then return nil end
    local x2 = get_integer(rect, 'x2')
    local y1 = get_integer(rect, 'y1')
    local y2 = get_integer(rect, 'y2')
    if not x2 or not y1 or not y2 or y2 < y1 then return nil end

    local l = x2 + 1
    if l < 0 or l + width > screen_width then return nil end
    local t = y1 + math.floor((y2 - y1 + 1 - height) / 2)
    return {l=l, t=math.max(0, math.min(t, screen_height - height)), w=width, h=height}
end

---@param screen_width integer
---@param screen_height integer
---@param unit_card_rect any|nil
---@return table|nil frame
---@return string|nil error
function resolve(screen_width, screen_height, unit_card_rect)
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
    local native_frame = resolve_from_unit_card(
        unit_card_rect, screen_width, screen_height, width, height)
    if native_frame then return native_frame, nil, 'native unit-card bounds' end
    return {
        l=math.max(0, math.min(screen_width - width,
            screen_width - FALLBACK_UNIT_CARD_RIGHT_INSET)),
        t=math.floor((screen_height - height) / 2),
        w=width,
        h=height,
    }, nil, 'screen-relative fallback'
end
