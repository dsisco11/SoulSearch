--@ module=true

---@class SoulSearchStatsRecord
---@field label string
---@field label_key string
---@field deviation number
---@field tier_distance number
---@field pen dfhack.color|dfhack.pen
---@field ordinal integer

local attributes = reqscript('internal/soulsearch/attributes')
local ui_format = reqscript('internal/soulsearch/ui_format')

local CATEGORIES = {
    {kind='physical_attribute', field='physical_attributes', pen=COLOR_LIGHTGREEN},
    {kind='mental_attribute', field='mental_attributes', pen=COLOR_LIGHTBLUE},
    {kind='trait', field='traits', pen=COLOR_LIGHTMAGENTA},
}

---@param key string
---@return string
local function record_label(key)
    return key:gsub('_', ' '):lower():gsub('^%l', string.upper)
end

---@param category table
---@param values table<string, number>|nil
---@param unit df.unit|nil
---@param first_ordinal integer
---@return SoulSearchStatsRecord[]
local function collect_category(category, values, unit, first_ordinal)
    if not values or not unit then return {} end
    local keys = {}
    for key, value in pairs(values) do
        local evaluation = attributes.evaluate(category.kind, key, value, unit)
        if evaluation and evaluation.tier_distance ~= 0 then
            table.insert(keys, key)
        end
    end
    table.sort(keys)

    local records = {}
    for index, key in ipairs(keys) do
        local evaluation = attributes.evaluate(
            category.kind,
            key,
            values[key],
            unit)
        local label = record_label(key)
        table.insert(records, {
            kind=category.kind,
            key=key,
            label=label,
            label_key=label:lower(),
            deviation=evaluation.deviation,
            tier_distance=evaluation.tier_distance,
            pen=category.pen,
            ordinal=first_ordinal + index - 1,
        })
    end
    return records
end

---@param result SoulSearchResult|nil
---@return SoulSearchStatsRecord[][] sections
---@return SoulSearchStatsRecord[] flat
function build_records(result)
    if not result or not result.row or not result.unit then return {}, {} end
    local sections = {}
    local flat = {}
    local ordinal = 1
    for _, category in ipairs(CATEGORIES) do
        local records = collect_category(
            category,
            result.row[category.field],
            result.unit,
            ordinal)
        if #records > 0 then
            table.insert(sections, records)
            for _, record in ipairs(records) do
                table.insert(flat, record)
                ordinal = ordinal + 1
            end
        end
    end
    return sections, flat
end

---@param records SoulSearchStatsRecord[]
---@param sort_key string
---@param sort_reverse boolean
function sort_records(records, sort_key, sort_reverse)
    table.sort(records, function(left, right)
        local left_value = sort_key == 'value' and left.deviation or left.label_key
        local right_value = sort_key == 'value' and right.deviation or right.label_key
        if left_value ~= right_value then
            if sort_reverse then
                return left_value > right_value
            end
            return left_value < right_value
        end
        if left.label_key ~= right.label_key then
            return left.label_key < right.label_key
        end
        return left.ordinal < right.ordinal
    end)
end

---@param result SoulSearchResult|nil
---@return table[]
function header(result)
    return ui_format.format_stats_header(result)
end

---@param sort_key string|nil
---@param sort_reverse boolean
---@return table[]
function column_header(sort_key, sort_reverse)
    local tokens = {}
    ui_format.append_stats_column_header_tokens(tokens, sort_key, sort_reverse)
    return tokens
end

---@param result SoulSearchResult|nil
---@param sort_key string|nil
---@param sort_reverse boolean
---@return SoulSearchStatsRecord[]|false[]
function get_display_records(result, sort_key, sort_reverse)
    if not result or not result.row then return {} end
    local sections, flat = build_records(result)
    if sort_key then
        sort_records(flat, sort_key, sort_reverse)
        return flat
    end
    local rows = {}
    for section_index, records in ipairs(sections) do
        if section_index > 1 then table.insert(rows, false) end
        for _, record in ipairs(records) do table.insert(rows, record) end
    end
    return rows
end

---@param result SoulSearchResult|nil
---@param sort_key string|nil
---@param sort_reverse boolean
---@param columns table|nil
---@return table[]|string
function body(result, sort_key, sort_reverse, columns)
    if not result or not result.row then return '' end
    local tokens = {}
    for _, record in ipairs(get_display_records(result, sort_key, sort_reverse)) do
        if record then
            ui_format.append_attribute_record_tokens(tokens, record, columns)
        else
            table.insert(tokens, NEWLINE)
        end
    end
    return tokens
end
