--@ module=true

---@class SoulSearchSelectedFilter
---@field id string
---@field direction SoulSearchFilterDirection

---@class SoulSearchSelectedDescriptor: SoulSearchFilterDescriptor
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
---@field matched_criteria SoulSearchFilterCriterion[]
---@field matched_count integer
---@field criteria_count integer
---@field match_label string
---@field score number
---@field weighted_score number

---@class SoulSearchApplyOptions
---@field query string|nil
---@field selected_descriptors SoulSearchSelectedDescriptor[]|nil
---@field selected_filters SoulSearchSelectedFilter[]|nil
---@field selected_filter_ids string[]|nil

local attributes = reqscript('internal/soulsearch/attributes')
local descriptors = reqscript('internal/soulsearch/descriptors')

local FILTER_HIGH = 'high'
local MATCHED_FILTER_SCORE = 10
local FILTER_PRIORITY_WEIGHT_BONUS = 0.2

---@param descriptor_id string
---@return SoulSearchFilterDescriptor|nil
local function get_descriptor_by_id(descriptor_id)
    return descriptors.get_catalog().by_id[descriptor_id]
end

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

---@param haystack string
---@param needle string
---@return boolean
local function contains_text(haystack, needle)
    if not needle or needle == '' then
        return true
    end
    return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

---@param selected SoulSearchSelectedDescriptor[]|nil
---@return SoulSearchSelectedDescriptor[]
local function copy_selected_descriptors(selected)
    local result = {}
    for _, descriptor in ipairs(selected or {}) do
        table.insert(result, descriptor)
    end
    return result
end

---@param descriptor SoulSearchFilterDescriptor
---@param direction SoulSearchFilterDirection|nil
---@return SoulSearchSelectedDescriptor
local function make_selected_descriptor(descriptor, direction)
    local selected = {}
    for key, value in pairs(descriptor) do
        selected[key] = value
    end
    selected.direction = direction or FILTER_HIGH
    return selected
end

---@param selected_ids string[]|nil
---@return SoulSearchSelectedDescriptor[]
local function selected_ids_to_descriptors(selected_ids)
    local result = {}
    for _, descriptor_id in ipairs(selected_ids or {}) do
        local descriptor = get_descriptor_by_id(descriptor_id)
        if descriptor then
            table.insert(result, make_selected_descriptor(descriptor, FILTER_HIGH))
        end
    end
    return result
end

---@param selected_filters SoulSearchSelectedFilter[]|nil
---@return SoulSearchSelectedDescriptor[]
local function selected_filters_to_descriptors(selected_filters)
    local result = {}
    for _, selected_filter in ipairs(selected_filters or {}) do
        local descriptor = get_descriptor_by_id(selected_filter.id)
        if descriptor then
            table.insert(result, make_selected_descriptor(
                descriptor,
                selected_filter.direction))
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
---@param selected_descriptors SoulSearchSelectedDescriptor[]
---@return SoulSearchFilterCriterion[] criteria
---@return SoulSearchFilterCriterion[] matched
---@return integer matched_count
---@return number score
---@return number weighted_score
local function score_row(row, selected_descriptors)
    local matched = {}
    local criteria = {}
    local score = 0
    local weighted_score = 0

    for index, descriptor in ipairs(selected_descriptors) do
        local value = get_value(row, descriptor)
        local evaluation = attributes.evaluate(
            descriptor.kind, descriptor.key, value, row.unit)
        local matches = attributes.matches_direction(
            evaluation, descriptor.direction)
        if evaluation then
            if matches then
                local value_score = attributes.score_direction(
                    evaluation, descriptor.direction)
                score = score + value_score
                weighted_score = weighted_score +
                    score_weighted_match(value_score, index)
            end
            local criterion = {
                id=descriptor.id,
                kind=descriptor.kind,
                key=descriptor.key,
                label=descriptor.label,
                direction=descriptor.direction,
                value=value,
                baseline=evaluation.baseline,
                deviation=evaluation.deviation,
                tier_distance=evaluation.tier_distance,
                matched=matches,
            }
            table.insert(criteria, criterion)
            if matches then
                table.insert(matched, criterion)
            end
        end
    end

    return criteria, matched, #matched, score, weighted_score
end

---@param row SoulSearchResidentRow
---@param selected_descriptors SoulSearchSelectedDescriptor[]
---@return SoulSearchResult
local function make_result(row, selected_descriptors)
    local criteria, matched, matched_count, score, weighted_score =
        score_row(row, selected_descriptors)
    return {
        row=row,
        unit=row.unit,
        unit_id=row.unit_id,
        name=row.name,
        profession=row.profession,
        filter_criteria=criteria,
        matched_criteria=matched,
        matched_count=matched_count,
        criteria_count=#selected_descriptors,
        match_label=('%d/%d'):format(matched_count, #selected_descriptors),
        score=score,
        weighted_score=weighted_score,
    }
end

---Filters and ranks resident rows.
---@param rows SoulSearchResidentRow[]|nil
---@param opts SoulSearchApplyOptions|nil
---@return SoulSearchResult[]
function apply(rows, opts)
    opts = opts or {}
    local query = opts.query or ''
    local selected_descriptors = opts.selected_descriptors and
        copy_selected_descriptors(opts.selected_descriptors) or
        opts.selected_filters and selected_filters_to_descriptors(opts.selected_filters) or
        selected_ids_to_descriptors(opts.selected_filter_ids)
    local results = {}

    for _, row in ipairs(rows or {}) do
        if contains_text(row.name or '', query) then
            table.insert(results, make_result(row, selected_descriptors))
        end
    end

    table.sort(results, function(left, right)
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
    end)

    return results
end
