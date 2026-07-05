--@ module=true

local TRAIT_MATCH_MINIMUM = 50
local MENTAL_ATTRIBUTE_MATCH_MINIMUM = 1000
local PHYSICAL_ATTRIBUTE_MATCH_MINIMUM = 1000
local TRAIT_SCORE_SCALE = 100
local MENTAL_ATTRIBUTE_SCORE_SCALE = 5000
local PHYSICAL_ATTRIBUTE_SCORE_SCALE = 5000

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

local function make_descriptor(kind, key, label, match_minimum, score_scale)
    return {
        id=kind .. ':' .. key,
        kind=kind,
        key=key,
        label=label,
        match_minimum=match_minimum,
        score_scale=score_scale,
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
            title_case_enum_name(trait.name),
            TRAIT_MATCH_MINIMUM,
            TRAIT_SCORE_SCALE))
    end
    return sort_descriptors_by_label(descriptors)
end

local function get_mental_attribute_descriptors()
    local descriptors = {}
    for _, attr in ipairs(enum_keys(df.mental_attribute_type)) do
        table.insert(descriptors, make_descriptor(
            'mental_attribute',
            attr.name,
            title_case_enum_name(attr.name),
            MENTAL_ATTRIBUTE_MATCH_MINIMUM,
            MENTAL_ATTRIBUTE_SCORE_SCALE))
    end
    return sort_descriptors_by_label(descriptors)
end

local function get_physical_attribute_descriptors()
    local descriptors = {}
    for _, attr in ipairs(enum_keys(df.physical_attribute_type)) do
        table.insert(descriptors, make_descriptor(
            'physical_attribute',
            attr.name,
            title_case_enum_name(attr.name),
            PHYSICAL_ATTRIBUTE_MATCH_MINIMUM,
            PHYSICAL_ATTRIBUTE_SCORE_SCALE))
    end
    return sort_descriptors_by_label(descriptors)
end

local function flatten_descriptors(descriptors)
    local flattened = {}
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

local function selected_ids_to_descriptors(selected_ids)
    local descriptors = {}
    for _, descriptor_id in ipairs(selected_ids or {}) do
        local descriptor = get_descriptor_by_id(descriptor_id)
        if descriptor then
            table.insert(descriptors, descriptor)
        end
    end
    return descriptors
end

local function score_row(row, selected_descriptors)
    local matched = {}
    local score = 0

    for _, descriptor in ipairs(selected_descriptors) do
        local value = get_value(row, descriptor)
        if value and value >= descriptor.match_minimum then
            table.insert(matched, {
                id=descriptor.id,
                kind=descriptor.kind,
                key=descriptor.key,
                label=descriptor.label,
                value=value,
            })
            score = score + math.min(value / descriptor.score_scale, 1)
        end
    end

    return matched, #matched, score
end

local function make_result(row, selected_descriptors)
    local matched, matched_count, score = score_row(row, selected_descriptors)
    return {
        row=row,
        unit=row.unit,
        unit_id=row.unit_id,
        name=row.name,
        profession=row.profession,
        position=row.position,
        matched_criteria=matched,
        matched_count=matched_count,
        criteria_count=#selected_descriptors,
        match_label=('%d/%d'):format(matched_count, #selected_descriptors),
        score=score,
    }
end

function get_filter_descriptors()
    return {
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
