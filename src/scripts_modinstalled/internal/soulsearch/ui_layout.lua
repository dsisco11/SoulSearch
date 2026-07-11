--@ module=true

local glyphs = reqscript('internal/soulsearch/ui_glyphs')

WINDOW_FRAME = {w=150, h=45, xalign=0.5, yalign=0.5}
WINDOW_RESIZE_MIN = {w=120, h=30}

FILTER_LEFT = 1
FILTER_WIDTH = 38
RESULTS_LEFT = 41
RESULTS_WIDTH = 64
STATS_LEFT = 107
DIVIDER_XS = {RESULTS_LEFT - 2, STATS_LEFT - 2}
HEADER_ROW = 2
UNDERLINE_ROW = 3
PICKER_TOP = 7
STATS_CONTENT_TOP = 4

STATS_LABEL_WIDTH = 24
STATS_VALUE_COLUMN_X = 27
STATS_VALUE_HEADER_WIDTH = 7

ACTIVE_FILTER_BUTTON_START_X = 21
FILTER_ACTION_WIDTH = 3

---@class SoulSearchFilterActionMetadata
---@field id string
---@field label string
---@field width integer
---@field tooltip string
---@field pen_rule string
---@field enabled_rule string
---@field callback string

---@type SoulSearchFilterActionMetadata[]
FILTER_ACTIONS = {
    {
        id='plus', label='[+]', width=FILTER_ACTION_WIDTH,
        tooltip='Prefer high', pen_rule='high_selected',
        enabled_rule='always', callback='set_high',
    },
    {
        id='minus', label='[-]', width=FILTER_ACTION_WIDTH,
        tooltip='Prefer low', pen_rule='low_selected',
        enabled_rule='always', callback='set_low',
    },
    {
        id='up', label='[' .. glyphs.CP437_TRIANGLE_UP .. ']', width=FILTER_ACTION_WIDTH,
        tooltip='Move up', pen_rule='enabled',
        enabled_rule='can_move_up', callback='move_up',
    },
    {
        id='down', label='[' .. glyphs.CP437_TRIANGLE_DOWN .. ']', width=FILTER_ACTION_WIDTH,
        tooltip='Move down', pen_rule='enabled',
        enabled_rule='can_move_down', callback='move_down',
    },
    {
        id='remove', label='[x]', width=FILTER_ACTION_WIDTH,
        tooltip='Remove', pen_rule='remove',
        enabled_rule='always', callback='remove',
    },
}

FILTER_ACTION_ZONE_WIDTH = FILTER_ACTION_WIDTH * #FILTER_ACTIONS

FRAMES = {
    search_field={l=RESULTS_LEFT, t=4, w=RESULTS_WIDTH, h=1},
    filter_title={l=FILTER_LEFT, t=HEADER_ROW, w=FILTER_WIDTH, h=1},
    filter_underline={l=FILTER_LEFT, t=UNDERLINE_ROW, w=FILTER_WIDTH, h=1},
    add_filter={l=FILTER_LEFT, t=4, w=25, h=1},
    add_skill={l=FILTER_LEFT, t=5, w=25, h=1},
    clear_filters={l=FILTER_LEFT, t=6, w=20, h=1},
    filter_list={l=FILTER_LEFT, t=8, w=FILTER_WIDTH, b=0},
    picker={l=FILTER_LEFT, t=PICKER_TOP, w=FILTER_WIDTH, b=0},
    picker_close={r=0, t=0, w=3, h=1},
    picker_search={l=0, t=0, r=4, h=1},
    picker_list={l=0, t=2, r=0, b=0},
    result_title={l=RESULTS_LEFT, t=HEADER_ROW, w=RESULTS_WIDTH, h=1},
    result_underline={l=RESULTS_LEFT, t=UNDERLINE_ROW, w=RESULTS_WIDTH, h=1},
    result_list={l=RESULTS_LEFT, t=6, w=RESULTS_WIDTH, b=0},
    stats_title={l=STATS_LEFT, t=HEADER_ROW, r=1, h=1},
    stats_underline={l=STATS_LEFT, t=UNDERLINE_ROW, r=1, h=1},
    stats_header={l=STATS_LEFT, t=STATS_CONTENT_TOP, r=1, b=0},
    stats_body={l=STATS_LEFT, t=STATS_CONTENT_TOP + 1, r=1, b=0},
    close={r=1, t=0, w=16, h=1},
}

---@param source table
---@return table
function copy_dimensions(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

---@param name string
---@return table
function get_frame(name)
    return copy_dimensions(assert(FRAMES[name],
        'unknown SoulSearch frame: ' .. name))
end

---@param x integer|nil
---@return SoulSearchFilterActionMetadata|nil
function get_filter_action_at_x(x)
    if not x or x < ACTIVE_FILTER_BUTTON_START_X then
        return nil
    end
    local offset = x - ACTIVE_FILTER_BUTTON_START_X
    for _, action in ipairs(FILTER_ACTIONS) do
        if offset < action.width then
            return action
        end
        offset = offset - action.width
    end
    return nil
end

---@param x integer|nil
---@param y integer|nil
---@return string|nil
function get_stats_header_column(x, y)
    if not x or y ~= 0 then
        return nil
    end
    if x >= 2 and x < 2 + STATS_LABEL_WIDTH then
        return 'label'
    end
    if x >= STATS_VALUE_COLUMN_X and
            x < STATS_VALUE_COLUMN_X + STATS_VALUE_HEADER_WIDTH then
        return 'value'
    end
    return nil
end
