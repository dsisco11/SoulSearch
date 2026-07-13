--@ module=true

local layout = reqscript('internal/soulsearch/ui_layout')
local glyphs = reqscript('internal/soulsearch/ui_glyphs')
local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

local FILTER_HIGH = filter_constants.direction.HIGH
local FILTER_LOW = filter_constants.direction.LOW
local MATCHED_FILTER_LABEL_WIDTH = 24
local MATCHED_FILTER_VALUE_WIDTH = 6
local RESULT_NAME_WIDTH = layout.RESULT_NAME_WIDTH
local RESULT_UNIT_ID_WIDTH = layout.RESULT_UNIT_ID_WIDTH
local RESULT_PROFESSION_WIDTH = layout.RESULT_PROFESSION_WIDTH

---@param text any
---@param width integer
---@return string
function truncate_text(text, width)
    text = tostring(text or '')
    if width <= 0 or #text <= width then
        return text
    end
    if width <= 3 then
        return text:sub(1, width)
    end
    return text:sub(1, width - 3) .. '...'
end

---@param text any
---@param width integer
---@return string[]
function wrap_text(text, width)
    local lines = {}
    local line = ''
    for word in tostring(text or ''):gmatch('%S+') do
        if line == '' then
            line = word
        elseif #line + 1 + #word <= width then
            line = line .. ' ' .. word
        else
            table.insert(lines, line)
            line = word
        end
    end
    if line ~= '' then table.insert(lines, line) end
    return #lines > 0 and lines or {''}
end

---@param result SoulSearchResult
---@return string
function format_result_choice(result)
    return ('%-' .. RESULT_NAME_WIDTH .. 's %-' .. RESULT_PROFESSION_WIDTH ..
        's %-' .. RESULT_UNIT_ID_WIDTH .. 's'):format(
        truncate_text(result.name, RESULT_NAME_WIDTH),
        truncate_text(result.profession or '', RESULT_PROFESSION_WIDTH),
        truncate_text('#' .. tostring(result.unit_id), RESULT_UNIT_ID_WIDTH))
end

---@param sort_key string|nil
---@param sort_reverse boolean
---@return string
function format_result_columns(sort_key, sort_reverse)
    local function marker(column)
        if sort_key ~= column then return '' end
        return ' ' .. (sort_reverse and glyphs.CP437_ARROW_DOWN or
            glyphs.CP437_ARROW_UP)
    end
    return ('%-' .. RESULT_NAME_WIDTH .. 's %-' .. RESULT_PROFESSION_WIDTH ..
        's %-' .. RESULT_UNIT_ID_WIDTH .. 's'):format(
        'Name' .. marker('name'),
        'Profession' .. marker('profession'),
        'Unit ID' .. marker('unit_id'))
end

---@param label string
---@return string
function format_unit_scope_control(label)
    return 'Include: ' .. label
end

---@param label string
---@param selected boolean
---@return string
function format_unit_scope_choice(label, selected)
    return (selected and glyphs.CP437_ARROW_RIGHT or ' ') .. ' ' .. label
end

---@param descriptor SoulSearchFilterDescriptor|SoulSearchFilterCriterion
---@return dfhack.color|dfhack.pen
function get_category_pen(descriptor)
    if descriptor.kind == filter_constants.kind.RACE then
        return COLOR_LIGHTCYAN
    end
    if descriptor.kind == 'skill' then return COLOR_YELLOW end
    if descriptor.kind == 'physical_attribute' then return COLOR_LIGHTGREEN end
    if descriptor.kind == 'mental_attribute' then return COLOR_LIGHTBLUE end
    return COLOR_LIGHTMAGENTA
end

---@param deviation number
---@param tier_distance number
---@return dfhack.color|dfhack.pen
function get_deviation_pen(deviation, tier_distance)
    if deviation < 0 then
        return tier_distance >= 2 and COLOR_LIGHTRED or COLOR_RED
    end
    return tier_distance >= 2 and COLOR_LIGHTGREEN or COLOR_GREEN
end

---@param value number
---@return string
function format_deviation(value)
    return value > 0 and ('+%d'):format(value) or tostring(value)
end

---@param value number|nil
---@return string
function format_skill_value(value)
    value = math.floor((value or 0) * 10) / 10
    return ('%.1f'):format(value)
end

---@param criterion SoulSearchFilterCriterion
---@return string
function format_evaluation_value(criterion)
    if criterion.kind == 'skill' then
        return format_skill_value(criterion.value)
    end
    return format_deviation(criterion.deviation)
end

---@param title any
---@return string
function get_title_underline(title)
    return glyphs.CP437_HORIZONTAL_LINE:rep(#tostring(title or ''))
end

---@param tokens table[]
---@param title string
---@param pen dfhack.color|dfhack.pen
function append_underlined_title_tokens(tokens, title, pen)
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
function format_active_filter_choice(
        descriptor, mode, priority_index, priority_count)
    local is_race = descriptor.kind == filter_constants.kind.RACE
    local state = {
        high_selected=mode == FILTER_HIGH,
        low_selected=mode == FILTER_LOW,
        can_move_up=priority_index and priority_index > 1,
        can_move_down=priority_index and priority_index < priority_count,
    }
    local label = truncate_text(
        descriptor.label,
        layout.ACTIVE_FILTER_BUTTON_START_X - 1)
    local tokens = {
        {text=label, pen=get_category_pen(descriptor)},
        {
            text=(' '):rep(math.max(
                1,
                layout.ACTIVE_FILTER_BUTTON_START_X - #label)),
            pen=COLOR_DARKGREY,
        },
    }
    for _, action in ipairs(layout.FILTER_ACTIONS) do
        local pen = COLOR_DARKGREY
        local label = action.label
        if is_race then
            if action.callback == 'move_up' or action.callback == 'move_down' then
                label = '   '
            end
        end
        if action.pen_rule == 'high_selected' and state.high_selected then
            pen = COLOR_LIGHTGREEN
        elseif action.pen_rule == 'low_selected' and state.low_selected then
            pen = COLOR_LIGHTRED
        elseif not is_race and action.pen_rule == 'enabled' and
                state[action.enabled_rule] then
            pen = COLOR_WHITE
        elseif action.pen_rule == 'remove' then
            pen = COLOR_LIGHTRED
        end
        table.insert(tokens, {text=label, pen=pen})
    end
    return tokens
end

---@param descriptor SoulSearchFilterDescriptor
---@return table[]
function format_available_filter_choice(descriptor)
    return {{text=descriptor.label, pen=get_category_pen(descriptor)}}
end

---@param descriptor SoulSearchFilterDescriptor
---@return table[]
function format_available_skill_choice(descriptor)
    return {
        {text=glyphs.CP437_ARROW_RIGHT .. ' ', pen=COLOR_DARKGREY},
        {text=descriptor.label, pen=get_category_pen(descriptor)},
    }
end

---@param category string
---@return table[]
function format_skill_category_choice(category)
    return {{text=category, pen=COLOR_WHITE}}
end

---@param tokens table[]
---@param sort_key string|nil
---@param sort_reverse boolean
function append_stats_column_header_tokens(tokens, sort_key, sort_reverse)
    local function marker(active_key)
        if sort_key ~= active_key then return '' end
        return ' ' .. (sort_reverse and glyphs.CP437_ARROW_DOWN or
            glyphs.CP437_ARROW_UP)
    end
    local label_header = 'Stat' .. marker('label')
    local value_header = 'Delta' .. marker('value')
    table.insert(tokens, {
        text=('%-' .. layout.STATS_VALUE_COLUMN_X .. 's'):format(label_header),
        pen=COLOR_GREY,
    })
    table.insert(tokens, {text=value_header, pen=COLOR_GREY})
    table.insert(tokens, NEWLINE)
    table.insert(tokens, {
        text=glyphs.CP437_HORIZONTAL_LINE:rep(layout.STATS_LABEL_WIDTH),
        pen=COLOR_DARKGREY,
    })
    table.insert(tokens, {
        text=(' '):rep(layout.STATS_VALUE_COLUMN_X - layout.STATS_LABEL_WIDTH),
        pen=COLOR_DARKGREY,
    })
    table.insert(tokens, {
        text=glyphs.CP437_HORIZONTAL_LINE:rep(5), pen=COLOR_DARKGREY})
    table.insert(tokens, NEWLINE)
end

---@param tokens table[]
---@param record SoulSearchStatsRecord
function append_attribute_record_tokens(tokens, record)
    table.insert(tokens, {
        text=('  %-' .. layout.STATS_LABEL_WIDTH .. 's '):format(record.label),
        pen=record.pen,
    })
    table.insert(tokens, {
        text=format_deviation(record.deviation),
        pen=get_deviation_pen(record.deviation, record.tier_distance),
    })
    table.insert(tokens, NEWLINE)
end

---@param tokens table[]
---@param filter_criteria SoulSearchFilterCriterion[]|nil
function append_selected_filter_section_tokens(tokens, filter_criteria)
    if not filter_criteria or #filter_criteria == 0 then return end
    append_underlined_title_tokens(tokens, 'Selected filters', COLOR_WHITE)
    for _, criterion in ipairs(filter_criteria) do
        local is_low = criterion.direction == FILTER_LOW
        local function matched_pen(pen)
            return criterion.matched and pen or COLOR_DARKGREY
        end
        table.insert(tokens, {text='  ', pen=COLOR_DARKGREY})
        table.insert(tokens, {
            text=is_low and '[-] ' or '[+] ',
            pen=matched_pen(is_low and COLOR_LIGHTRED or COLOR_LIGHTGREEN),
        })
        table.insert(tokens, {
            text=('%-' .. MATCHED_FILTER_LABEL_WIDTH .. 's'):format(
                truncate_text(criterion.label, MATCHED_FILTER_LABEL_WIDTH)),
            pen=matched_pen(get_category_pen(criterion)),
        })
        table.insert(tokens, {
            text=('%' .. MATCHED_FILTER_VALUE_WIDTH .. 's'):format(
                format_evaluation_value(criterion)),
            pen=matched_pen(get_deviation_pen(
                criterion.deviation,
                criterion.tier_distance)),
        })
        table.insert(tokens, NEWLINE)
    end
    table.insert(tokens, NEWLINE)
end

---@param result SoulSearchResult|nil
---@return table[]
function format_stats_header(result)
    local tokens = {}
    if not result or not result.row then
        return {{text='No resident selected.', pen=COLOR_DARKGREY}}
    end
    table.insert(tokens, {text=result.name or 'Unknown resident', pen=COLOR_WHITE})
    table.insert(tokens, NEWLINE)
    table.insert(tokens, {text=result.profession or '', pen=COLOR_DARKGREY})
    table.insert(tokens, NEWLINE)
    table.insert(tokens, NEWLINE)
    append_selected_filter_section_tokens(tokens, result.filter_criteria)
    return tokens
end
