--@ module=true

local layout = reqscript('internal/soulsearch/stats_layout')

FRAME_INSET = 1 -- gui.FRAME_BOLD contributes one tile on every edge.
CLOSE_WIDTH = 3 -- TextButton's banner margins plus its X label.
DEFAULT_WIDTH = math.max(layout.MIN_CONTENT_WIDTH + FRAME_INSET * 2, 40)
DEFAULT_HEIGHT = math.max(layout.MIN_CONTENT_HEIGHT + FRAME_INSET * 2, 12)
MIN_WIDTH = math.max(layout.MIN_CONTENT_WIDTH + FRAME_INSET * 2, CLOSE_WIDTH + 8)
MIN_HEIGHT = layout.MIN_CONTENT_HEIGHT + FRAME_INSET * 2
DEFAULT_SORT = {key=nil, reverse=false, phase=0}

---@return table
function get_minimum()
    return {w=MIN_WIDTH, h=MIN_HEIGHT}
end

---@param screen_width integer
---@param screen_height integer
---@return table|nil frame
---@return string|nil error
function resolve(screen_width, screen_height)
    if type(screen_width) ~= 'number' or type(screen_height) ~= 'number' then
        return nil, 'SoulSearch Stats popover requires a valid screen size.'
    end
    screen_width, screen_height = math.floor(screen_width), math.floor(screen_height)
    if screen_width < MIN_WIDTH or screen_height < MIN_HEIGHT then
        return nil, ('SoulSearch Stats popover requires at least %dx%d tiles.'):
            format(MIN_WIDTH, MIN_HEIGHT)
    end
    local width = math.min(DEFAULT_WIDTH, screen_width)
    local height = math.min(DEFAULT_HEIGHT, screen_height)
    return {
        l=math.floor((screen_width - width) / 2),
        t=math.floor((screen_height - height) / 2),
        w=width,
        h=height,
    }, nil
end
