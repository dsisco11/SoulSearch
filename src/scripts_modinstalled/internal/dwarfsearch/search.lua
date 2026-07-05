--@ module=true

local attributes = reqscript('internal/dwarfsearch/attributes')

local FILTER_HIGH = 'high'
local MATCHED_FILTER_SCORE = 10
local FILTER_PRIORITY_WEIGHT_BONUS = 0.2

local function enum_keys(enum)
    local keys = {}
    for index, name in ipairs(enum) do
        if name ~= 'NONE' then
            table.insert(keys, {name=name, value=enum[name] or index})
        end
    end
    table.sort(keys, function(a, b) return a.value < b.value end)
    return keys
end

local function title_case_enum_name(name)
    local words = {}
    for word in name:gmatch('[^_]+') do
        local lower = word:lower()
        table.insert(words, lower:sub(1, 1):upper() .. lower:sub(2))
    end
    return table.concat(words, ' ')
end

local function make_descriptor(kind, key, label)
    return {
        id=kind .. ':' .. key,
        kind=kind,
        key=key,
        label=label,
    }
end

local function sort_descriptors_by_label(descriptors)
    table.sort(descriptors, function(a, b)
        if a.label ~= b.label then
            return a.label < b.label
        end
        return a.id < b.id
    end)
    return descriptors
end

local function get_trait_descriptors()
    local descriptors = {}
    for _, trait in ipairs(enum_keys(df.personality_facet_type)) do
        table.insert(descriptors, make_descriptor(
            'trait',
            trait.name,
            title_case_enum_name(trait.name)))
    end
    return sort_descriptors_by_label(descriptors)
end

local function get_mental_attribute_descriptors()
    local descriptors = {}
    for _, attr in ipairs(enum_keys(df.mental_attribute_type)) do
        table.insert(descriptors, make_descriptor(
            'mental_attribute',
            attr.name,
            title_case_enum_name(attr.name)))
    end
    return sort_descriptors_by_label(descriptors)
end

local function get_physical_attribute_descriptors()
    local descriptors = {}
    for _, attr in ipairs(enum_keys(df.physical_attribute_type)) do
        table.insert(descriptors, make_descriptor(
            'physical_attribute',
            attr.name,
            title_case_enum_name(attr.name)))
    end
    return sort_descriptors_by_label(descriptors)
end

local function get_skill_descriptors()
    local descriptors = {}
    for _, skill in ipairs(enum_keys(df.job_skill)) do
        table.insert(descriptors, make_descriptor(
            'skill',
            skill.name,
            title_case_enum_name(skill.name)))
    end
    return sort_descriptors_by_label(descriptors)
end

local function flatten_descriptors(descriptors)
    local flattened = {}
    for _, descriptor in ipairs(descriptors.skills or {}) do
        table.insert(flattened, descriptor)
    end
    for _, descriptor in ipairs(descriptors.physical_attributes or {}) do
        table.insert(flattened, descriptor)
    end
    for _, descriptor in ipairs(descriptors.mental_attributes or {}) do
        table.insert(flattened, descriptor)
    end
    for _, descriptor in ipairs(descriptors.traits or {}) do
        table.insert(flattened, descriptor)
    end
    return flattened
end

local function get_descriptor_by_id(descriptor_id)
    for _, descriptor in ipairs(flatten_descriptors(get_filter_descriptors())) do
        if descriptor.id == descriptor_id then
            return descriptor
        end
    end
    return nil
end

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

local function contains_text(haystack, needle)
    if not needle or needle == '' then
        return true
    end
    return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

local function copy_selected_descriptors(selected)
    local descriptors = {}
    for _, descriptor in ipairs(selected or {}) do
        table.insert(descriptors, descriptor)
    end
    return descriptors
end

local function make_selected_descriptor(descriptor, direction)
    local selected = {}
    for key, value in pairs(descriptor) do
        selected[key] = value
    end
    selected.direction = direction or FILTER_HIGH
    return selected
end

local function selected_ids_to_descriptors(selected_ids)
    local descriptors = {}
    for _, descriptor_id in ipairs(selected_ids or {}) do
        local descriptor = get_descriptor_by_id(descriptor_id)
        if descriptor then
            table.insert(descriptors, make_selected_descriptor(descriptor, FILTER_HIGH))
        end
    end
    return descriptors
end

local function selected_filters_to_descriptors(selected_filters)
    local descriptors = {}
    for _, selected_filter in ipairs(selected_filters or {}) do
        local descriptor = get_descriptor_by_id(selected_filter.id)
        if descriptor then
            table.insert(descriptors, make_selected_descriptor(
                descriptor,
                selected_filter.direction))
        end
    end
    return descriptors
end

local function get_priority_weight(priority_index)
    return 1 + FILTER_PRIORITY_WEIGHT_BONUS / math.max(priority_index or 1, 1)
end

local function score_weighted_match(value_score, priority_index)
    return (MATCHED_FILTER_SCORE + value_score) * get_priority_weight(priority_index)
end

local function score_row(row, selected_descriptors)
    local matched = {}
    local criteria = {}
    local score = 0
    local weighted_score = 0

    for index, descriptor in ipairs(selected_descriptors) do
        local value = get_value(row, descriptor)
        local evaluation = attributes.evaluate(descriptor.kind, descriptor.key, value, row.unit)
        local matches = attributes.matches_direction(evaluation, descriptor.direction)
        if evaluation then
            if matches then
                local value_score = attributes.score_direction(evaluation, descriptor.direction)
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

local function make_result(row, selected_descriptors)
    local criteria, matched, matched_count, score, weighted_score = score_row(row, selected_descriptors)
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

function get_filter_descriptors()
    return {
        skills=get_skill_descriptors(),
        traits=get_trait_descriptors(),
        mental_attributes=get_mental_attribute_descriptors(),
        physical_attributes=get_physical_attribute_descriptors(),
    }
end

function get_flat_filter_descriptors()
    return flatten_descriptors(get_filter_descriptors())
end

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

    table.sort(results, function(a, b)
        if a.matched_count ~= b.matched_count then
            return a.matched_count > b.matched_count
        end
        if a.weighted_score ~= b.weighted_score then
            return a.weighted_score > b.weighted_score
        end
        if a.score ~= b.score then
            return a.score > b.score
        end
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.unit_id < b.unit_id
    end)

    return results
end
