--@ module=true

---@class SoulSearchPosition
---@field x integer
---@field y integer
---@field z integer

---@class SoulSearchStatsRecord
---@field label string
---@field label_key string
---@field deviation number
---@field tier_distance number
---@field pen dfhack.color|dfhack.pen

local gui = require('gui')
local widgets = require('gui.widgets')

local residents = reqscript('internal/soulsearch/residents')
local search = reqscript('internal/soulsearch/search')
local attributes = reqscript('internal/soulsearch/attributes')
local descriptors = reqscript('internal/soulsearch/descriptors')
local skill_categories = reqscript('internal/soulsearch/skill_categories')

local view
local saved_filter_modes = {}
local saved_filter_order = {}
local SECTION_DIVIDER_PEN = COLOR_DARKGREY
local SECTION_DIVIDER_XS = {39, 105}
local FILTER_HIGH = 'high'
local FILTER_LOW = 'low'
local MATCHED_FILTER_LABEL_WIDTH = 24
local MATCHED_FILTER_VALUE_WIDTH = 6
local STATS_LABEL_WIDTH = 24
local STATS_VALUE_COLUMN_X = 27
local STATS_VALUE_HEADER_WIDTH = 7
local STATS_SORT_LABEL = 'label'
local STATS_SORT_VALUE = 'value'
local TITLE_UNDERLINE_PEN = COLOR_GREY
local FILTER_ACTION_PLUS = 'plus'
local FILTER_ACTION_MINUS = 'minus'
local FILTER_ACTION_REMOVE = 'remove'
local FILTER_ACTION_UP = 'up'
local FILTER_ACTION_DOWN = 'down'
local FILTER_ACTION_WIDTH = 3
local CP437_TRIANGLE_UP = string.char(30)
local CP437_TRIANGLE_DOWN = string.char(31)
local CP437_ARROW_RIGHT = string.char(16)
local CP437_ARROW_UP = string.char(24)
local CP437_ARROW_DOWN = string.char(25)
local FILTER_ACTION_UP_LABEL = '[' .. CP437_TRIANGLE_UP .. ']'
local FILTER_ACTION_DOWN_LABEL = '[' .. CP437_TRIANGLE_DOWN .. ']'
local FILTER_ACTION_TOOLTIPS = {
    [FILTER_ACTION_PLUS] = 'Prefer high',
    [FILTER_ACTION_MINUS] = 'Prefer low',
    [FILTER_ACTION_UP] = 'Move up',
    [FILTER_ACTION_DOWN] = 'Move down',
    [FILTER_ACTION_REMOVE] = 'Remove',
}
local STATS_HEADER_TOOLTIPS = {
    [STATS_SORT_LABEL]='Sort by stat name.',
    [STATS_SORT_VALUE]='Sort by baseline difference.',
}
local TOOLTIP_BACKGROUND_PEN = dfhack.pen.parse{ch=32, fg=COLOR_BLACK, bg=COLOR_BLACK}
local TOOLTIP_TEXT_PEN = dfhack.pen.parse{fg=COLOR_WHITE, bg=COLOR_BLACK}
local ACTIVE_FILTER_BUTTON_START_X = 21
local ACTIVE_FILTER_LABEL_WIDTH = ACTIVE_FILTER_BUTTON_START_X - 1
local ADD_FILTER_LABEL = 'Add attribute filter'
local ADD_SKILL_LABEL = 'Add skill filter'
---@param text any
---@param width integer
---@return string
local function truncate(text, width)
    text = tostring(text or '')
    if width <= 0 or #text <= width then
        return text
    end
    if width <= 3 then
        return text:sub(1, width)
    end
    return text:sub(1, width - 3) .. '...'
end

---@param haystack any
---@param needle string|nil
---@return boolean
local function contains_text(haystack, needle)
    if not needle or needle == '' then
        return true
    end
    return tostring(haystack or ''):lower():find(needle:lower(), 1, true) ~= nil
end

---@param pos SoulSearchPosition|nil
---@return string
local function format_position(pos)
    if not pos then
        return 'unknown'
    end
    return ('%d, %d, %d'):format(pos.x, pos.y, pos.z)
end

---@param x integer|table
---@param y integer|nil
---@param z integer|nil
---@return SoulSearchPosition|nil
local function make_position(x, y, z)
    if type(x) == 'table' then
        return {x=x.x, y=x.y, z=x.z}
    end
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then
        return nil
    end
    if x < 0 or y < 0 or z < 0 then
        return nil
    end
    return {x=x, y=y, z=z}
end

---@param result SoulSearchResult
---@return string
local function format_result_choice(result)
    return ('%-45s %s'):format(
        truncate(result.name, 45),
        truncate(result.profession or '', 18))
end

---@param descriptor SoulSearchFilterDescriptor|SoulSearchFilterCriterion
---@return dfhack.color|dfhack.pen
local function get_category_pen(descriptor)
    if descriptor.kind == 'skill' then
        return COLOR_YELLOW
    end
    if descriptor.kind == 'physical_attribute' then
        return COLOR_LIGHTGREEN
    end
    if descriptor.kind == 'mental_attribute' then
        return COLOR_LIGHTBLUE
    end
    return COLOR_LIGHTMAGENTA
end

---@param deviation number
---@param tier_distance number
---@return dfhack.color|dfhack.pen
local function get_deviation_pen(deviation, tier_distance)
    if deviation < 0 then
        if tier_distance >= 2 then
            return COLOR_LIGHTRED
        end
        return COLOR_RED
    end
    if tier_distance >= 4 then
        return COLOR_LIGHTGREEN
    end
    if tier_distance >= 2 then
        return COLOR_LIGHTGREEN
    end
    return COLOR_GREEN
end

---@param deviation number
---@return string
local function format_deviation(deviation)
    if deviation > 0 then
        return ('+%d'):format(deviation)
    end
    return tostring(deviation)
end

---@param value number|nil
---@return string
local function format_skill_value(value)
    value = math.floor((value or 0) * 10) / 10
    return ('%.1f'):format(value)
end

---@param criterion SoulSearchFilterCriterion
---@param evaluation SoulSearchEvaluation
---@return string
local function format_evaluation_value(criterion, evaluation)
    if criterion.kind == 'skill' then
        return format_skill_value(evaluation.value)
    end
    return format_deviation(evaluation.deviation)
end

---@param title any
---@return string
local function get_title_underline(title)
    return ('-'):rep(#tostring(title or ''))
end

---@param tokens table[]
---@param title string
---@param pen dfhack.color|dfhack.pen
local function add_underlined_title(tokens, title, pen)
    table.insert(tokens, {text=title, pen=pen})
    table.insert(tokens, NEWLINE)
    table.insert(tokens, {text=get_title_underline(title), pen=pen})
    table.insert(tokens, NEWLINE)
end

---@param descriptor SoulSearchFilterDescriptor
---@param mode SoulSearchFilterDirection|nil
---@param priority_index integer|nil
---@param priority_count integer
---@return table[]
local function format_active_filter_choice(descriptor, mode, priority_index, priority_count)
    local high_selected = mode == FILTER_HIGH
    local low_selected = mode == FILTER_LOW
    local can_move_up = priority_index and priority_index > 1
    local can_move_down = priority_index and priority_index < priority_count
    local label = truncate(descriptor.label, ACTIVE_FILTER_LABEL_WIDTH)
    local spacer_width = math.max(1, ACTIVE_FILTER_BUTTON_START_X - #label)
    return {
        {text=label, pen=get_category_pen(descriptor)},
        {text=(' '):rep(spacer_width), pen=COLOR_DARKGREY},
        {text='[+]', pen=high_selected and COLOR_LIGHTGREEN or COLOR_DARKGREY},
        {text='[-]', pen=low_selected and COLOR_LIGHTRED or COLOR_DARKGREY},
        {text=FILTER_ACTION_UP_LABEL, pen=can_move_up and COLOR_WHITE or COLOR_DARKGREY},
        {text=FILTER_ACTION_DOWN_LABEL, pen=can_move_down and COLOR_WHITE or COLOR_DARKGREY},
        {text='[x]', pen=COLOR_LIGHTRED},
    }
end

---@param descriptor SoulSearchFilterDescriptor
---@return table[]
local function format_available_filter_choice(descriptor)
    return {
        {text=descriptor.label, pen=get_category_pen(descriptor)},
    }
end

---@param descriptor SoulSearchFilterDescriptor
---@return table[]
local function format_available_skill_choice(descriptor)
    return {
        {text=CP437_ARROW_RIGHT .. ' ', pen=COLOR_DARKGREY},
        {text=descriptor.label, pen=get_category_pen(descriptor)},
    }
end

---@param category string
---@return table[]
local function format_skill_category_choice(category)
    return {
        {text=category, pen=COLOR_WHITE},
    }
end

---@param x integer|nil
---@return string|nil
local function get_filter_action_at_x(x)
    if not x then
        return nil
    end
    if x < ACTIVE_FILTER_BUTTON_START_X then
        return nil
    end

    x = x - ACTIVE_FILTER_BUTTON_START_X
    if x < FILTER_ACTION_WIDTH then
        return FILTER_ACTION_PLUS
    end
    if x < FILTER_ACTION_WIDTH * 2 then
        return FILTER_ACTION_MINUS
    end
    if x < FILTER_ACTION_WIDTH * 3 then
        return FILTER_ACTION_UP
    end
    if x < FILTER_ACTION_WIDTH * 4 then
        return FILTER_ACTION_DOWN
    end
    if x < FILTER_ACTION_WIDTH * 5 then
        return FILTER_ACTION_REMOVE
    end
    return nil
end

---@param keys table
---@return boolean
local function is_backspace_key(keys)
    return keys._BACKSPACE or keys.BACKSPACE or keys.KEYBOARD_BACKSPACE
end

---@param view table|nil
---@return boolean
local function is_visible(view)
    while view do
        if type(view.visible) == 'function' then
            if not view.visible() then
                return false
            end
        elseif not view.visible then
            return false
        end
        view = view.parent_view
    end
    return true
end

---@param view table|nil
---@return boolean
local function is_mouse_over(view)
    local rect = view and view.frame_body
    local x, y = dfhack.screen.getMousePos()
    return rect and x and is_visible(view) and rect:inClipGlobalXY(x, y)
end

---@param text string
---@param max_width integer
---@return string tooltip_text
---@return integer tooltip_width
local function get_tooltip_box(text, max_width)
    local text_width = math.min(#text, math.min(52, max_width - 2))
    local tooltip_text = truncate(text, text_width)
    return tooltip_text, #tooltip_text + 2
end

---@class SoulSearchTooltip: widgets.Window
---@field label widgets.Label
---@field owner SoulSearchWindow|nil
SoulSearchTooltip = defclass(SoulSearchTooltip, widgets.Window)
SoulSearchTooltip.ATTRS{
    frame={l=0, t=0, w=1, h=3},
    frame_style=gui.FRAME_THIN,
    frame_background=TOOLTIP_BACKGROUND_PEN,
    frame_inset=0,
    draggable=false,
    no_force_pause_badge=true,
    owner=DEFAULT_NIL,
}

---Creates tooltip label content.
function SoulSearchTooltip:init()
    self.label = widgets.Label{
        frame={l=0, t=0, w=1, h=1},
        auto_height=false,
        text_pen=TOOLTIP_TEXT_PEN,
        text='',
    }
    self:addviews{self.label}
end

---Positions and draws the tooltip near the mouse cursor.
---@param dc gui.Painter
function SoulSearchTooltip:render(dc)
    local owner = self.owner
    local mouse_x, mouse_y = dfhack.screen.getMousePos()
    if not owner or not mouse_x then
        return
    end

    local text = owner:get_tooltip_text()
    if text == '' then
        return
    end

    local screen_width, screen_height = dfhack.screen.getWindowSize()
    local tooltip_text, tooltip_width = get_tooltip_box(text, screen_width)
    local x = math.min(mouse_x + 2, screen_width - tooltip_width)
    local y = math.min(mouse_y + 1, screen_height - 3)

    self.frame = {
        l=math.max(0, x),
        t=math.max(0, y),
        w=tooltip_width,
        h=3,
    }
    self.label.frame.w = math.max(1, tooltip_width - 2)
    self.label:setText(tooltip_text)
    self:updateLayout()
    SoulSearchTooltip.super.render(self, dc)
end

---@param filter_modes table<string, SoulSearchFilterDirection>|nil
---@return table<string, SoulSearchFilterDirection>
local function copy_filter_modes(filter_modes)
    local copy = {}
    for filter_id, mode in pairs(filter_modes or {}) do
        copy[filter_id] = mode
    end
    return copy
end

---@param filter_order string[]|nil
---@return string[]
local function copy_filter_order(filter_order)
    local copy = {}
    for _, filter_id in ipairs(filter_order or {}) do
        table.insert(copy, filter_id)
    end
    return copy
end

---@param target SoulSearchFilterDescriptor[]
---@param descriptors SoulSearchFilterDescriptor[]|nil
local function append_descriptors(target, descriptors)
    for _, descriptor in ipairs(descriptors or {}) do
        table.insert(target, descriptor)
    end
end

---@param result SoulSearchResult|nil
---@return SoulSearchPosition|nil
local function get_live_position(result)
    if not result or not result.unit then
        return nil
    end

    local ok, x, y, z = pcall(dfhack.units.getPosition, result.unit)
    if ok then
        return make_position(x, y, z)
    end
    return nil
end

---@param kind SoulSearchStatKind
---@param key string
---@param value number
---@param unit df.unit
---@return boolean
local function is_notable_value(kind, key, value, unit)
    local evaluation = attributes.evaluate(kind, key, value, unit)
    return evaluation and evaluation.tier_distance ~= 0
end

---@param records SoulSearchStatsRecord[]
---@param pen dfhack.color|dfhack.pen
---@param kind SoulSearchStatKind
---@param values table<string, number>|nil
---@param unit df.unit|nil
---@return boolean
local function collect_attribute_records(records, pen, kind, values, unit)
    if not values or not unit then
        return false
    end

    local keys = {}
    for key, value in pairs(values) do
        if is_notable_value(kind, key, value, unit) then
            table.insert(keys, key)
        end
    end
    table.sort(keys)

    if #keys == 0 then
        return false
    end

    for _, key in ipairs(keys) do
        local label = key:gsub('_', ' '):lower():gsub('^%l', string.upper)
        local evaluation = attributes.evaluate(kind, key, values[key], unit)
        table.insert(records, {
            label=label,
            label_key=label:lower(),
            deviation=evaluation.deviation,
            tier_distance=evaluation.tier_distance,
            pen=pen,
        })
    end
    return true
end

---@param tokens table[]
---@param record SoulSearchStatsRecord
local function add_attribute_record(tokens, record)
    table.insert(tokens, {text=('  %-' .. STATS_LABEL_WIDTH .. 's '):format(record.label), pen=record.pen})
    table.insert(tokens, {
        text=format_deviation(record.deviation),
        pen=get_deviation_pen(record.deviation, record.tier_distance),
    })
    table.insert(tokens, NEWLINE)
end

---@param records SoulSearchStatsRecord[]
---@param sort_key string|nil
---@param sort_reverse boolean
local function sort_attribute_records(records, sort_key, sort_reverse)
    table.sort(records, function(left, right)
        local left_value = sort_key == STATS_SORT_VALUE and left.deviation or left.label_key
        local right_value = sort_key == STATS_SORT_VALUE and right.deviation or right.label_key
        if left_value == right_value then
            return left.label_key < right.label_key
        end
        if sort_reverse then
            return left_value > right_value
        end
        return left_value < right_value
    end)
end

---@param sort_key string|nil
---@param active_key string
---@param sort_reverse boolean
---@return string
local function get_sort_marker(sort_key, active_key, sort_reverse)
    if sort_key ~= active_key then
        return ''
    end
    return ' ' .. (sort_reverse and CP437_ARROW_DOWN or CP437_ARROW_UP)
end

---@param tokens table[]
---@param sort_key string|nil
---@param sort_reverse boolean
local function add_stats_column_header(tokens, sort_key, sort_reverse)
    local label_header = 'Stat' .. get_sort_marker(sort_key, STATS_SORT_LABEL, sort_reverse)
    local value_header = 'Delta' .. get_sort_marker(sort_key, STATS_SORT_VALUE, sort_reverse)
    table.insert(tokens, {text='  ', pen=COLOR_DARKGREY})
    table.insert(tokens, {text=('%-' .. STATS_LABEL_WIDTH .. 's '):format(label_header), pen=COLOR_GREY})
    table.insert(tokens, {text=value_header, pen=COLOR_GREY})
    table.insert(tokens, NEWLINE)
    table.insert(tokens, {text='  ', pen=COLOR_DARKGREY})
    table.insert(tokens, {text=('-'):rep(STATS_LABEL_WIDTH), pen=COLOR_DARKGREY})
    table.insert(tokens, {text=' ', pen=COLOR_DARKGREY})
    table.insert(tokens, {text=('-'):rep(5), pen=COLOR_DARKGREY})
    table.insert(tokens, NEWLINE)
end

---@param criterion SoulSearchFilterCriterion
---@param default_pen dfhack.color|dfhack.pen
---@return dfhack.color|dfhack.pen
local function get_filter_criterion_pen(criterion, default_pen)
    if criterion.matched then
        return default_pen
    end
    return COLOR_DARKGREY
end

---@param criterion SoulSearchFilterCriterion
---@param unit df.unit
---@return SoulSearchEvaluation|SoulSearchFilterCriterion|nil
local function get_criterion_evaluation(criterion, unit)
    if criterion.deviation ~= nil and criterion.tier_distance ~= nil then
        return criterion
    end
    return attributes.evaluate(criterion.kind, criterion.key, criterion.value, unit)
end

---@param tokens table[]
---@param filter_criteria SoulSearchFilterCriterion[]|nil
---@param unit df.unit
local function add_selected_filter_section(tokens, filter_criteria, unit)
    if not filter_criteria or #filter_criteria == 0 then
        return
    end

    add_underlined_title(tokens, 'Selected filters', COLOR_WHITE)

    for _, criterion in ipairs(filter_criteria) do
        local is_low = criterion.direction == FILTER_LOW
        local evaluation = get_criterion_evaluation(criterion, unit)
        if evaluation then
            local direction_pen = get_filter_criterion_pen(
                criterion,
                is_low and COLOR_LIGHTRED or COLOR_LIGHTGREEN)
            local label_pen = get_filter_criterion_pen(criterion, get_category_pen(criterion))
            local value_pen = get_filter_criterion_pen(
                criterion,
                get_deviation_pen(evaluation.deviation, evaluation.tier_distance))
            table.insert(tokens, {text='  ', pen=COLOR_DARKGREY})
            table.insert(tokens, {text=is_low and '[-] ' or '[+] ', pen=direction_pen})
            table.insert(tokens, {text=('%-' .. MATCHED_FILTER_LABEL_WIDTH .. 's'):format(
                truncate(criterion.label, MATCHED_FILTER_LABEL_WIDTH)), pen=label_pen})
            table.insert(tokens, {text=('%' .. MATCHED_FILTER_VALUE_WIDTH .. 's'):format(
                format_evaluation_value(criterion, evaluation)), pen=value_pen})
            table.insert(tokens, NEWLINE)
        end
    end

    table.insert(tokens, NEWLINE)
end

---@param result SoulSearchResult|nil
---@return table[]
local function stats_header_for_result(result)
    local tokens = {}
    if not result or not result.row then
        table.insert(tokens, {text='No resident selected.', pen=COLOR_DARKGREY})
        return tokens
    end

    table.insert(tokens, {text=result.name or 'Unknown resident', pen=COLOR_WHITE})
    table.insert(tokens, NEWLINE)
    table.insert(tokens, {text=result.profession or '', pen=COLOR_DARKGREY})
    table.insert(tokens, NEWLINE)
    table.insert(tokens, NEWLINE)
    add_selected_filter_section(tokens, result.filter_criteria, result.unit)
    return tokens
end

---@param result SoulSearchResult|nil
---@param sort_key string|nil
---@param sort_reverse boolean
---@return table[]|string
local function stats_for_result(result, sort_key, sort_reverse)
    if not result or not result.row then
        return ''
    end

    local tokens = {}
    add_stats_column_header(tokens, sort_key, sort_reverse)

    if sort_key then
        local records = {}
        collect_attribute_records(records, COLOR_LIGHTGREEN, 'physical_attribute', result.row.physical_attributes, result.unit)
        collect_attribute_records(records, COLOR_LIGHTBLUE, 'mental_attribute', result.row.mental_attributes, result.unit)
        collect_attribute_records(records, COLOR_LIGHTMAGENTA, 'trait', result.row.traits, result.unit)
        sort_attribute_records(records, sort_key, sort_reverse)
        for _, record in ipairs(records) do
            add_attribute_record(tokens, record)
        end
        return tokens
    end

    local has_previous_section = false
    local function append_section(pen, kind, values)
        local records = {}
        if not collect_attribute_records(records, pen, kind, values, result.unit) then
            return
        end
        if has_previous_section then
            table.insert(tokens, NEWLINE)
        end
        for _, record in ipairs(records) do
            add_attribute_record(tokens, record)
        end
        has_previous_section = true
    end

    append_section(COLOR_LIGHTGREEN, 'physical_attribute', result.row.physical_attributes)
    append_section(COLOR_LIGHTBLUE, 'mental_attribute', result.row.mental_attributes)
    append_section(COLOR_LIGHTMAGENTA, 'trait', result.row.traits)

    return tokens
end

---@param window widgets.Window
local function normalize_frame_for_drag(window)
    window.frame = {
        l=window.frame_rect.x1,
        t=window.frame_rect.y1,
        w=window.frame_rect.width,
        h=window.frame_rect.height,
    }
end

---@param dc gui.Painter
local function draw_section_dividers(dc)
    local y2 = math.max(2, dc.height)
    for _, x in ipairs(SECTION_DIVIDER_XS) do
        for y = 2, y2 do
            dc:seek(x, y):char('|', SECTION_DIVIDER_PEN)
        end
    end
end

---@class SoulSearchWindow: widgets.Window
---@field rows SoulSearchResidentRow[]
---@field results SoulSearchResult[]
---@field query string
---@field attribute_query string
---@field skill_query string
---@field stats_sort_key string|nil
---@field stats_sort_reverse boolean
---@field stats_sort_phase integer
---@field add_filter_open boolean
---@field add_skill_open boolean
---@field filter_catalog SoulSearchFilterCatalog
---@field filter_descriptors SoulSearchFilterDescriptor[]
---@field attribute_filter_descriptors SoulSearchFilterDescriptor[]
---@field skill_filter_descriptors SoulSearchFilterDescriptor[]
---@field selected_filters SoulSearchSelectedFilter[]
---@field selected_filter_modes table<string, SoulSearchFilterDirection>
---@field selected_filter_order string[]
SoulSearchWindow = defclass(SoulSearchWindow, widgets.Window)
SoulSearchWindow.ATTRS {
    frame_title='SoulSearch',
    frame={w=150, h=45, xalign=0.5, yalign=0.5},
    resizable=true,
    resize_min={w=120, h=30},
}

---Creates controls and loads the initial resident/filter data.
function SoulSearchWindow:init()
    self.rows = {}
    self.results = {}
    self.query = ''
    self.attribute_query = ''
    self.skill_query = ''
    self.stats_sort_key = nil
    self.stats_sort_reverse = false
    self.stats_sort_phase = 0
    self.add_filter_open = false
    self.add_skill_open = false
    local filter_catalog = descriptors.get_catalog()
    local filter_descriptor_groups = filter_catalog.groups
    self.filter_catalog = filter_catalog
    self.filter_descriptors = filter_catalog.flat
    self.attribute_filter_descriptors = {}
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.physical_attributes)
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.mental_attributes)
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.traits)
    self.skill_filter_descriptors = filter_descriptor_groups.skills or {}
    self.selected_filters = {}
    self.selected_filter_modes = self:get_valid_filter_modes(saved_filter_modes)
    self.selected_filter_order = self:get_valid_filter_order(saved_filter_order)

    self:addviews{
        widgets.EditField{
            view_id='search_field',
            frame={l=41, t=4, w=64, h=1},
            label_text='Search: ',
            key='CUSTOM_F',
            modal=true,
            on_change=function(text)
                self.query = text
                self:update_results()
            end,
        },
        widgets.Label{
            frame={l=1, t=2, w=38, h=1},
            text='Search filters',
            text_pen=COLOR_WHITE,
        },
        widgets.Label{
            frame={l=1, t=3, w=38, h=1},
            text=get_title_underline('Search filters'),
            text_pen=TITLE_UNDERLINE_PEN,
        },
        widgets.HotkeyLabel{
            view_id='add_filter_button',
            frame={l=1, t=4, w=25, h=1},
            key='CUSTOM_A',
            label=ADD_FILTER_LABEL,
            on_activate=function() self:toggle_add_filter_dropdown() end,
        },
        widgets.HotkeyLabel{
            view_id='add_skill_button',
            frame={l=1, t=5, w=25, h=1},
            key='CUSTOM_S',
            label='Add skill filter',
            on_activate=function() self:toggle_add_skill_dropdown() end,
        },
        widgets.HotkeyLabel{
            view_id='clear_filters_button',
            frame={l=1, t=6, w=20, h=1},
            key='CUSTOM_C',
            label='Clear filters',
            on_activate=function() self:clear_filters() end,
        },
        widgets.List{
            view_id='filter_list',
            frame={l=1, t=8, w=38, b=0},
            visible=function() return not self.add_filter_open and not self.add_skill_open end,
        },
        widgets.Window{
            view_id='available_filter_window',
            frame={l=1, t=7, w=38, b=0},
            frame_title='Select attribute/trait',
            draggable=false,
            visible=function() return self.add_filter_open end,
            subviews={
                widgets.HotkeyLabel{
                    view_id='close_filter_picker_button',
                    frame={r=0, t=0, w=3, h=1},
                    label='[X]',
                    on_activate=function() self:close_add_filter_dropdown() end,
                },
                widgets.EditField{
                    view_id='attribute_search_field',
                    frame={l=0, t=0, r=4, h=1},
                    label_text='Search: ',
                    key='CUSTOM_T',
                    on_change=function(text)
                        self.attribute_query = text
                        self:update_available_filter_choices()
                    end,
                },
                widgets.List{
                    view_id='available_filter_list',
                    frame={l=0, t=2, r=0, b=0},
                    on_submit=function(index, choice)
                        if choice and choice.descriptor then
                            self:add_filter(choice.descriptor.id)
                        end
                    end,
                },
            },
        },
        widgets.Window{
            view_id='available_skill_window',
            frame={l=1, t=7, w=38, b=0},
            frame_title='Select skill',
            draggable=false,
            visible=function() return self.add_skill_open end,
            subviews={
                widgets.HotkeyLabel{
                    view_id='close_skill_picker_button',
                    frame={r=0, t=0, w=3, h=1},
                    label='[X]',
                    on_activate=function() self:close_add_filter_dropdown() end,
                },
                widgets.EditField{
                    view_id='skill_search_field',
                    frame={l=0, t=0, r=4, h=1},
                    label_text='Search: ',
                    key='CUSTOM_K',
                    on_change=function(text)
                        self.skill_query = text
                        self:update_available_skill_choices()
                    end,
                },
                widgets.List{
                    view_id='available_skill_list',
                    frame={l=0, t=2, r=0, b=0},
                    on_submit=function(index, choice)
                        if choice and choice.descriptor then
                            self:add_filter(choice.descriptor.id)
                        end
                    end,
                },
            },
        },
        widgets.Label{
            view_id='result_header',
            frame={l=41, t=2, w=64, h=1},
            text='Results',
            text_pen=COLOR_WHITE,
        },
        widgets.Label{
            view_id='result_header_underline',
            frame={l=41, t=3, w=64, h=1},
            text=get_title_underline('Results'),
            text_pen=TITLE_UNDERLINE_PEN,
        },
        widgets.List{
            view_id='result_list',
            frame={l=41, t=6, w=64, b=0},
            on_select=function(index, choice)
                self:update_stats(choice and choice.result or nil)
            end,
            on_submit=function(index, choice)
                self:zoom_to_result(choice and choice.result or nil)
            end,
        },
        widgets.Label{
            frame={l=107, t=2, r=1, h=1},
            text='Stats',
            text_pen=COLOR_WHITE,
        },
        widgets.Label{
            frame={l=107, t=3, r=1, h=1},
            text=get_title_underline('Stats'),
            text_pen=TITLE_UNDERLINE_PEN,
        },
        widgets.Label{
            view_id='stats_header',
            frame={l=107, t=4, r=1, b=0},
            auto_height=false,
            text='No resident selected.',
        },
        widgets.Label{
            view_id='stats',
            frame={l=107, t=5, r=1, b=0},
            auto_height=false,
            text='',
        },
        widgets.HotkeyLabel{
            view_id='close_button',
            frame={r=1, t=0, w=16, h=1},
            key='LEAVESCREEN',
            label='Close',
            on_activate=function() self.parent_view:dismiss() end,
        },
    }

    self:refresh_residents()
    self:update_filter_choices()
    self:update_available_filter_choices()
    self:update_available_skill_choices()
end

---Normalizes the frame after a drag begins so resizing remains stable.
function SoulSearchWindow:onDragBegin()
    SoulSearchWindow.super.onDragBegin(self)
    normalize_frame_for_drag(self)
end

---Draws the main window body and section dividers.
---@param dc gui.Painter
function SoulSearchWindow:onRenderBody(dc)
    SoulSearchWindow.super.onRenderBody(self, dc)
    draw_section_dividers(dc)
end

---@return string|nil
function SoulSearchWindow:get_filter_action_tooltip()
    if self.add_filter_open or self.add_skill_open then
        return nil
    end

    local filter_list = self.subviews.filter_list
    if not filter_list or not filter_list:getIdxUnderMouse() then
        return nil
    end

    local x = filter_list:getMousePos()
    local action = get_filter_action_at_x(x)
    return action and FILTER_ACTION_TOOLTIPS[action] or nil
end

---@return string|nil
function SoulSearchWindow:get_stats_header_column()
    local stats = self.subviews.stats
    if not stats then
        return nil
    end

    local x, y = stats:getMousePos()
    if not x or y ~= 0 then
        return nil
    end
    if x >= 2 and x < 2 + STATS_LABEL_WIDTH then
        return STATS_SORT_LABEL
    end
    if x >= STATS_VALUE_COLUMN_X and x < STATS_VALUE_COLUMN_X + STATS_VALUE_HEADER_WIDTH then
        return STATS_SORT_VALUE
    end
    return nil
end

---@return string|nil
function SoulSearchWindow:get_stats_header_tooltip()
    local column = self:get_stats_header_column()
    return column and STATS_HEADER_TOOLTIPS[column] or nil
end

---@return string
function SoulSearchWindow:get_tooltip_text()
    local control_tooltips = {
        {id='add_filter_button', text='Add attribute filter'},
        {id='add_skill_button', text='Add skill filter'},
        {id='clear_filters_button', text='Clear filters'},
        {id='close_filter_picker_button', text='Close'},
        {id='close_skill_picker_button', text='Close'},
        {id='close_button', text='Close'},
    }

    for _, tooltip in ipairs(control_tooltips) do
        if is_mouse_over(self.subviews[tooltip.id]) then
            return tooltip.text
        end
    end

    return self:get_filter_action_tooltip() or self:get_stats_header_tooltip() or ''
end

---@return SoulSearchSelectedFilter[]
function SoulSearchWindow:get_selected_filters()
    local selected_filters = {}
    for _, filter_id in ipairs(self.selected_filter_order) do
        local mode = self.selected_filter_modes[filter_id]
        if mode then
            table.insert(selected_filters, {
                id=filter_id,
                direction=mode,
            })
        end
    end
    return selected_filters
end

---@param filter_id string
---@return SoulSearchFilterDescriptor|nil
function SoulSearchWindow:get_filter_descriptor_by_id(filter_id)
    return self.filter_catalog.by_id[filter_id]
end

---@param filter_modes table<string, SoulSearchFilterDirection>|nil
---@return table<string, SoulSearchFilterDirection>
function SoulSearchWindow:get_valid_filter_modes(filter_modes)
    local valid_modes = {}
    for filter_id, mode in pairs(filter_modes or {}) do
        if self:get_filter_descriptor_by_id(filter_id) then
            valid_modes[filter_id] = mode
        end
    end
    return valid_modes
end

---@param filter_order string[]|nil
---@return string[]
function SoulSearchWindow:get_valid_filter_order(filter_order)
    local valid_order = {}
    for _, filter_id in ipairs(filter_order or {}) do
        if self.selected_filter_modes[filter_id] and self:get_filter_descriptor_by_id(filter_id) then
            table.insert(valid_order, filter_id)
        end
    end
    return valid_order
end

---Persists the current filter mode and priority state for future windows.
function SoulSearchWindow:save_filter_state()
    saved_filter_modes = copy_filter_modes(self.selected_filter_modes)
    saved_filter_order = copy_filter_order(self.selected_filter_order)
end

---@param filter_id string
---@return integer|nil
function SoulSearchWindow:get_filter_priority(filter_id)
    for index, ordered_filter_id in ipairs(self.selected_filter_order) do
        if ordered_filter_id == filter_id then
            return index
        end
    end
    return nil
end

---@return SoulSearchFilterDescriptor[]
function SoulSearchWindow:get_active_filter_descriptors()
    local descriptors = {}

    for _, filter_id in ipairs(self.selected_filter_order) do
        local descriptor = self:get_filter_descriptor_by_id(filter_id)
        if descriptor then
            table.insert(descriptors, descriptor)
        end
    end

    return descriptors
end

---@param filter_id string
---@return integer
function SoulSearchWindow:get_filter_choice_index(filter_id)
    for index, descriptor in ipairs(self:get_active_filter_descriptors()) do
        if descriptor.id == filter_id then
            return index
        end
    end
    return 1
end

---@param selected integer|nil
function SoulSearchWindow:update_filter_choices(selected)
    local choices = {}
    local priority_count = #self.selected_filter_order
    for _, descriptor in ipairs(self:get_active_filter_descriptors()) do
        table.insert(choices, {
            text=format_active_filter_choice(
                descriptor,
                self.selected_filter_modes[descriptor.id],
                self:get_filter_priority(descriptor.id),
                priority_count),
            descriptor=descriptor,
            search_key=descriptor.label,
        })
    end
    if #choices == 0 then
        table.insert(choices, {text='Use Add attribute/trait or Add skill.'})
    end
    self.subviews.filter_list:setChoices(choices, selected)
end

---@param selected integer|nil
function SoulSearchWindow:update_available_filter_choices(selected)
    local choices = {}
    for _, descriptor in ipairs(self.attribute_filter_descriptors) do
        if not self.selected_filter_modes[descriptor.id] and
                contains_text(descriptor.label, self.attribute_query) then
            table.insert(choices, {
                text=format_available_filter_choice(descriptor),
                descriptor=descriptor,
                search_key=descriptor.label,
            })
        end
    end
    if #choices == 0 then
        table.insert(choices, {text='No matching attributes.'})
    end
    self.subviews.available_filter_list:setChoices(choices, selected)
end

---@param selected integer|nil
function SoulSearchWindow:update_available_skill_choices(selected)
    local choices = {}
    local choices_by_category = {}
    for _, descriptor in ipairs(self.skill_filter_descriptors) do
        if not self.selected_filter_modes[descriptor.id] and
                contains_text(descriptor.label, self.skill_query) then
            local category = descriptor.category or 'Other Skills'
            choices_by_category[category] = choices_by_category[category] or {}
            table.insert(choices_by_category[category], {
                text=format_available_skill_choice(descriptor),
                descriptor=descriptor,
                search_key=descriptor.label,
            })
        end
    end
    for _, category in ipairs(skill_categories.get_order()) do
        local category_choices = choices_by_category[category]
        if category_choices and #category_choices > 0 then
            table.insert(choices, {
                text=format_skill_category_choice(category),
                search_key=category,
            })
            for _, choice in ipairs(category_choices) do
                table.insert(choices, choice)
            end
        end
    end
    if #choices == 0 then
        table.insert(choices, {text='No matching skills.'})
    end
    self.subviews.available_skill_list:setChoices(choices, selected)
end

---Applies the current query and filters, then refreshes result choices.
function SoulSearchWindow:update_results()
    self:save_filter_state()
    self.selected_filters = self:get_selected_filters()
    self.results = search.apply(self.rows, {
        query=self.query,
        selected_filters=self.selected_filters,
    })

    local choices = {}
    for _, result in ipairs(self.results) do
        table.insert(choices, {
            text=format_result_choice(result),
            result=result,
            search_key=result.name,
        })
    end

    local result_header = ('Results (%d)'):format(#choices)
    self.subviews.result_header:setText(result_header)
    self.subviews.result_header_underline:setText(get_title_underline(result_header))
    self.subviews.result_list:setChoices(choices, 1)
    local _, choice = self.subviews.result_list:getSelected()
    self:update_stats(choice and choice.result or nil)
end

---@param result SoulSearchResult|nil
function SoulSearchWindow:update_stats(result)
    local header = self.subviews.stats_header
    local body = self.subviews.stats
    header:setText(stats_header_for_result(result))
    body:setText(stats_for_result(result, self.stats_sort_key, self.stats_sort_reverse))

    local header_top = 4
    local available_height = math.max(1, (self.frame_body and self.frame_body.height or 45) - header_top)
    local header_height = math.min(header:getTextHeight(), math.max(1, available_height - 1))
    local body_top = header_top + header_height

    header.frame = {l=107, t=header_top, r=1, h=header_height}
    body.frame = {l=107, t=body_top, r=1, b=0}
    if self.frame_body then
        header:updateLayout(self.frame_body)
        body:updateLayout(self.frame_body)
    end
end

---@return boolean
function SoulSearchWindow:handle_stats_header_click()
    local column = self:get_stats_header_column()
    if not column then
        return false
    end

    if self.stats_sort_key == column then
        self.stats_sort_phase = self.stats_sort_phase + 1
    else
        self.stats_sort_key = column
        self.stats_sort_phase = 1
    end

    if self.stats_sort_phase >= 3 then
        self.stats_sort_key = nil
        self.stats_sort_reverse = false
        self.stats_sort_phase = 0
    elseif self.stats_sort_phase == 1 then
        self.stats_sort_reverse = column == STATS_SORT_VALUE
    else
        self.stats_sort_reverse = column ~= STATS_SORT_VALUE
    end

    self:update_stats(self:get_selected_result())
    return true
end

---@return SoulSearchResult|nil
function SoulSearchWindow:get_selected_result()
    local _, choice = self.subviews.result_list:getSelected()
    return choice and choice.result or nil
end

---Centers the map on the currently selected result when possible.
function SoulSearchWindow:zoom_to_selected_result()
    self:zoom_to_result(self:get_selected_result())
end

---@param result SoulSearchResult|nil
function SoulSearchWindow:zoom_to_result(result)
    if not result then
        print('SoulSearch: no resident selected.')
        return
    end

    local pos = get_live_position(result)
    if not pos then
        print(('SoulSearch: %s does not have a valid map position.'):format(result.name))
        return
    end

    dfhack.gui.revealInDwarfmodeMap(pos, true, true)
end

---@param filter_id string
---@return boolean
function SoulSearchWindow:is_filter_active(filter_id)
    return self.selected_filter_modes[filter_id] ~= nil
end

---@param filter_id string
function SoulSearchWindow:add_filter(filter_id)
    if not self:is_filter_active(filter_id) then
        self.selected_filter_modes[filter_id] = FILTER_HIGH
        table.insert(self.selected_filter_order, filter_id)
    end
    self.add_filter_open = false
    self.add_skill_open = false
    self:update_add_filter_button()
    self:update_add_skill_button()
    self:update_filter_choices(self:get_filter_choice_index(filter_id))
    self:update_available_filter_choices()
    self:update_available_skill_choices()
    self:update_results()
end

---@param filter_id string
function SoulSearchWindow:remove_filter(filter_id)
    self.selected_filter_modes[filter_id] = nil
    local selected = self:get_filter_priority(filter_id) or 1
    for index, ordered_filter_id in ipairs(self.selected_filter_order) do
        if ordered_filter_id == filter_id then
            table.remove(self.selected_filter_order, index)
            break
        end
    end
    self:update_filter_choices(math.max(1, math.min(selected, #self.selected_filter_order)))
    self:update_available_filter_choices()
    self:update_available_skill_choices()
    self:update_results()
end

---@return boolean
function SoulSearchWindow:clear_filters()
    if #self.selected_filter_order == 0 then
        return false
    end

    self.selected_filter_modes = {}
    self.selected_filter_order = {}
    self.add_filter_open = false
    self.add_skill_open = false
    self:update_add_filter_button()
    self:update_add_skill_button()
    self:update_filter_choices(1)
    self:update_available_filter_choices()
    self:update_available_skill_choices()
    self:update_results()
    return true
end

---@param filter_id string
---@param direction SoulSearchFilterDirection
function SoulSearchWindow:set_filter_direction(filter_id, direction)
    if not self:is_filter_active(filter_id) then
        self:add_filter(filter_id)
        self.selected_filter_modes[filter_id] = direction
    else
        self.selected_filter_modes[filter_id] = direction
    end
    local selected = self:get_filter_choice_index(filter_id)
    self:update_filter_choices(selected)
    self:update_available_filter_choices()
    self:update_available_skill_choices()
    self:update_results()
end

---Opens or closes the attribute/trait filter picker.
function SoulSearchWindow:toggle_add_filter_dropdown()
    self.add_filter_open = not self.add_filter_open
    if self.add_filter_open then
        self.add_skill_open = false
    end
    self:update_add_filter_button()
    self:update_add_skill_button()
    self:update_available_filter_choices()
    self:update_available_skill_choices()
end

---Opens or closes the skill filter picker.
function SoulSearchWindow:toggle_add_skill_dropdown()
    self.add_skill_open = not self.add_skill_open
    if self.add_skill_open then
        self.add_filter_open = false
    end
    self:update_add_filter_button()
    self:update_add_skill_button()
    self:update_available_filter_choices()
    self:update_available_skill_choices()
end

---@return boolean
function SoulSearchWindow:close_add_filter_dropdown()
    if not self.add_filter_open and not self.add_skill_open then
        return false
    end

    self.add_filter_open = false
    self.add_skill_open = false
    self:update_add_filter_button()
    self:update_add_skill_button()
    self:update_available_filter_choices()
    self:update_available_skill_choices()
    return true
end

---Refreshes the add attribute filter button label.
function SoulSearchWindow:update_add_filter_button()
    self.subviews.add_filter_button:setLabel(ADD_FILTER_LABEL)
end

---Refreshes the add skill filter button label.
function SoulSearchWindow:update_add_skill_button()
    self.subviews.add_skill_button:setLabel(ADD_SKILL_LABEL)
end

---@param delta integer
---@return boolean
function SoulSearchWindow:move_selected_filter_priority(delta)
    local _, choice = self.subviews.filter_list:getSelected()
    local filter_id = choice and choice.descriptor and choice.descriptor.id
    if not filter_id or not self.selected_filter_modes[filter_id] then
        return false
    end

    local index = self:get_filter_priority(filter_id)
    local new_index = index and math.max(1, math.min(#self.selected_filter_order, index + delta))
    if not new_index or new_index == index then
        return false
    end

    table.remove(self.selected_filter_order, index)
    table.insert(self.selected_filter_order, new_index, filter_id)
    self:update_filter_choices(new_index)
    self:update_results()
    return true
end

---@return boolean
function SoulSearchWindow:handle_filter_action_click()
    if self.add_filter_open or self.add_skill_open then
        return false
    end

    local filter_list = self.subviews.filter_list
    local index = filter_list:getIdxUnderMouse()
    if not index then
        return false
    end

    filter_list:setSelected(index)
    local x = filter_list:getMousePos()
    local _, choice = filter_list:getSelected()
    local filter_id = choice and choice.descriptor and choice.descriptor.id
    local action = get_filter_action_at_x(x)
    if not filter_id or not action then
        return false
    end

    if action == FILTER_ACTION_PLUS then
        self:set_filter_direction(filter_id, FILTER_HIGH)
    elseif action == FILTER_ACTION_MINUS then
        self:set_filter_direction(filter_id, FILTER_LOW)
    elseif action == FILTER_ACTION_REMOVE then
        self:remove_filter(filter_id)
    elseif action == FILTER_ACTION_UP then
        self:move_selected_filter_priority(-1)
    elseif action == FILTER_ACTION_DOWN then
        self:move_selected_filter_priority(1)
    end
    return true
end

---Reloads resident rows from the current fortress map.
function SoulSearchWindow:refresh_residents()
    local rows, err = residents.collect_residents()
    if not rows then
        print(err)
        self.rows = {}
    else
        self.rows = rows
    end
    self:update_results()
end

---@param delta integer
function SoulSearchWindow:move_result_cursor(delta)
    self.subviews.result_list:moveCursor(delta)
end

---@param keys table
---@return boolean
function SoulSearchWindow:onInput(keys)
    if is_backspace_key(keys) and self:close_add_filter_dropdown() then
        return true
    end
    if keys._MOUSE_L and self:handle_filter_action_click() then
        return true
    end
    if keys._MOUSE_L and self:handle_stats_header_click() then
        return true
    end
    if keys.CUSTOM_R then
        self:refresh_residents()
        return true
    end
    if keys.CUSTOM_Z then
        self:zoom_to_selected_result()
        return true
    end
    if keys.CUSTOM_U and self:move_selected_filter_priority(-1) then
        return true
    end
    if keys.CUSTOM_D and self:move_selected_filter_priority(1) then
        return true
    end
    if keys.KEYBOARD_CURSOR_UP then
        self:move_result_cursor(-1)
        return true
    end
    if keys.KEYBOARD_CURSOR_DOWN then
        self:move_result_cursor(1)
        return true
    end
    if keys.KEYBOARD_CURSOR_UP_FAST then
        self:move_result_cursor(-10)
        return true
    end
    if keys.KEYBOARD_CURSOR_DOWN_FAST then
        self:move_result_cursor(10)
        return true
    end
    return SoulSearchWindow.super.onInput(self, keys)
end

---@class SoulSearchScreen: gui.ZScreen
---@field window SoulSearchWindow
SoulSearchScreen = defclass(SoulSearchScreen, gui.ZScreen)
SoulSearchScreen.ATTRS {
    focus_path='soulsearch',
}

---Creates the main SoulSearch window and tooltip overlay.
function SoulSearchScreen:init()
    self.window = SoulSearchWindow{}
    self:addviews{
        self.window,
        SoulSearchTooltip{owner=self.window},
    }
end

---Clears the cached screen reference when the screen closes.
function SoulSearchScreen:onDismiss()
    view = nil
end

---Opens or raises the SoulSearch screen.
---@param ... any
function open(...)
    local err = residents.get_unavailable_reason()
    if err then
        print(err)
        return
    end

    view = view and view:raise() or SoulSearchScreen{}:show()
end
