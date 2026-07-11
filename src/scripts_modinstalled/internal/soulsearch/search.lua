--@ module=true

---@class SoulSearchSelectedFilter
---@field id string
---@field direction SoulSearchFilterDirection

---@class SoulSearchResolvedFilter
---@field descriptor SoulSearchFilterDescriptor
---@field direction SoulSearchFilterDirection

---@class SoulSearchFilterCriterion
---@field id string
---@field kind SoulSearchStatKind
---@field key string
---@field label string
---@field direction SoulSearchFilterDirection
---@field value number
---@field baseline number
---@field deviation number
---@field tier_distance number
---@field matched boolean

---@class SoulSearchResult
---@field row SoulSearchResidentRow
---@field unit df.unit
---@field unit_id integer
---@field name string
---@field profession string
---@field filter_criteria SoulSearchFilterCriterion[]
---@field matched_count integer
---@field score number
---@field weighted_score number

---@class SoulSearchApplyOptions
---@field query string|nil
---@field selected_filters SoulSearchSelectedFilter[]|nil

local attributes = reqscript('internal/soulsearch/attributes')
local descriptors = reqscript('internal/soulsearch/descriptors')
local text_match = reqscript('internal/soulsearch/text_match')

local FILTER_HIGH = 'high'
local FILTER_LOW = 'low'
local MATCHED_FILTER_SCORE = 10
local FILTER_PRIORITY_WEIGHT_BONUS = 0.2
local VALID_FILTER_DIRECTIONS = {
    [FILTER_HIGH]=true,
    [FILTER_LOW]=true,
}

---@param row SoulSearchResidentRow
---@param descriptor SoulSearchFilterDescriptor
---@return number|nil
local function get_value(row, descriptor)
    if descriptor.kind == 'trait' then
        return row.traits and row.traits[descriptor.key]
    end
    if descriptor.kind == 'mental_attribute' then
        return row.mental_attributes and row.mental_attributes[descriptor.key]
    end
    if descriptor.kind == 'physical_attribute' then
        return row.physical_attributes and row.physical_attributes[descriptor.key]
    end
    if descriptor.kind == 'skill' then
        return row.skills and row.skills[descriptor.key] or 0
    end
    return nil
end

---Resolves the ordered public filter state through the immutable catalog.
---Malformed entries, invalid directions, and unknown IDs are ignored. For a
---duplicate ID, the first valid entry wins and retains its priority position.
---@param selected_filters SoulSearchSelectedFilter[]|nil
---@return SoulSearchResolvedFilter[]
local function resolve_selected_filters(selected_filters)
    local result = {}
    local seen = {}
    for _, selected_filter in ipairs(selected_filters or {}) do
        if type(selected_filter) == 'table' and
                type(selected_filter.id) == 'string' and
                not seen[selected_filter.id] and
                VALID_FILTER_DIRECTIONS[selected_filter.direction] then
            local descriptor = descriptors.get_catalog().by_id[selected_filter.id]
            if descriptor then
                seen[selected_filter.id] = true
                table.insert(result, {
                    descriptor=descriptor,
                    direction=selected_filter.direction,
                })
            end
        end
    end
    return result
end

---@param priority_index integer|nil
---@return number
local function get_priority_weight(priority_index)
    return 1 + FILTER_PRIORITY_WEIGHT_BONUS / math.max(priority_index or 1, 1)
end

---@param value_score number
---@param priority_index integer
---@return number
local function score_weighted_match(value_score, priority_index)
    return (MATCHED_FILTER_SCORE + value_score) * get_priority_weight(priority_index)
end

---@param row SoulSearchResidentRow
---@param resolved_filters SoulSearchResolvedFilter[]
---@return SoulSearchFilterCriterion[] criteria
---@return integer matched_count
---@return number score
---@return number weighted_score
local function score_row(row, resolved_filters)
    local criteria = {}
    local matched_count = 0
    local score = 0
    local weighted_score = 0

    for index, resolved_filter in ipairs(resolved_filters) do
        local descriptor = resolved_filter.descriptor
        local value = get_value(row, descriptor)
        local evaluation = attributes.evaluate(
            descriptor.kind, descriptor.key, value, row.unit)
        local matches = attributes.matches_direction(
            evaluation, resolved_filter.direction)
        if evaluation then
            if matches then
                local value_score = attributes.score_direction(
                    evaluation, resolved_filter.direction)
                matched_count = matched_count + 1
                score = score + value_score
                weighted_score = weighted_score +
                    score_weighted_match(value_score, index)
            end
            local criterion = {
                id=descriptor.id,
                kind=descriptor.kind,
                key=descriptor.key,
                label=descriptor.label,
                direction=resolved_filter.direction,
                value=value,
                baseline=evaluation.baseline,
                deviation=evaluation.deviation,
                tier_distance=evaluation.tier_distance,
                matched=matches,
            }
            table.insert(criteria, criterion)
        end
    end

    return criteria, matched_count, score, weighted_score
end

---@param row SoulSearchResidentRow
---@param resolved_filters SoulSearchResolvedFilter[]
---@return SoulSearchResult
local function make_result(row, resolved_filters)
    local criteria, matched_count, score, weighted_score =
        score_row(row, resolved_filters)
    return {
        row=row,
        unit=row.unit,
        unit_id=row.unit_id,
        name=row.name,
        profession=row.profession,
        filter_criteria=criteria,
        matched_count=matched_count,
        score=score,
        weighted_score=weighted_score,
    }
end

---Orders results by relevance, then stable resident identity fields.
---@param left SoulSearchResult
---@param right SoulSearchResult
---@return boolean
function compare_results(left, right)
    if left.matched_count ~= right.matched_count then
        return left.matched_count > right.matched_count
    end
    if left.weighted_score ~= right.weighted_score then
        return left.weighted_score > right.weighted_score
    end
    if left.score ~= right.score then
        return left.score > right.score
    end
    if left.name ~= right.name then
        return left.name < right.name
    end
    return left.unit_id < right.unit_id
end

---Filters and ranks resident rows.
---`selected_filters` is the only filter input. It is evaluated in array order;
---invalid entries are ignored according to `resolve_selected_filters()`.
---@param rows SoulSearchResidentRow[]|nil
---@param opts SoulSearchApplyOptions|nil
---@return SoulSearchResult[]
function apply(rows, opts)
    opts = opts or {}
    local query = opts.query or ''
    local resolved_filters = resolve_selected_filters(opts.selected_filters)
    local results = {}

    for _, row in ipairs(rows or {}) do
        if text_match.contains(row.name, query) then
            table.insert(results, make_result(row, resolved_filters))
        end
    end

    table.sort(results, compare_results)

    return results
end
