--@ module=true

local ui_format = reqscript('internal/soulsearch/ui_format')
local filter_constants = reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

local RACE_GROUP_ID_PREFIX = 'race_group:'

local function matches(text, query)
    return tostring(text):lower():find(tostring(query):lower(), 1, true) ~= nil
end

local function selected_by_id(descriptors, filters)
    local behavior_by_id = {}
    for _, descriptor in ipairs(descriptors or {}) do
        behavior_by_id[descriptor.id] = descriptor.behavior
    end
    local selected, priority = {}, 0
    for _, filter in ipairs(filters) do
        selected[filter.id] = filter.direction
        if behavior_by_id[filter.id] ~= filter_constants.behavior.CANDIDATE then
            priority = priority + 1
            selected[filter.id .. ':priority'] = priority
        end
    end
    return selected, priority
end

---@param descriptors SoulSearchFilterDescriptor[]
---@param filters SoulSearchSelectedFilter[]
---@return table[]
function present_active(descriptors, filters)
    local selected, priority_count = selected_by_id(descriptors, filters)
    local choices = {}
    for _, descriptor in ipairs(descriptors) do
        local direction = selected[descriptor.id]
        if direction then table.insert(choices, {
            text=ui_format.format_active_filter_choice(descriptor, direction,
                selected[descriptor.id .. ':priority'], priority_count),
            descriptor=descriptor, search_key=descriptor.label}) end
    end
    if #choices == 0 then table.insert(choices, {
        text='Use Add attribute, Add skill, or Add race.'}) end
    return choices
end

---@param descriptors SoulSearchFilterDescriptor[]
---@param filters SoulSearchSelectedFilter[]
---@param query string
---@param empty_text string
---@return table[]
function present_available(descriptors, filters, query, empty_text)
    local selected = selected_by_id(descriptors, filters)
    local choices = {}
    for _, descriptor in ipairs(descriptors) do
        if matches(descriptor.label, query) then
            local is_selected = selected[descriptor.id] ~= nil
            table.insert(choices, {text=ui_format.format_available_filter_choice(
                descriptor, is_selected), descriptor=descriptor,
                selected=is_selected, search_key=descriptor.label})
        end
    end
    if #choices == 0 then table.insert(choices, {text=empty_text}) end
    return choices
end

---@param descriptors SoulSearchFilterDescriptor[]
---@param filters SoulSearchSelectedFilter[]
---@param query string
---@param categories string[]
---@return table[]
function present_skills(descriptors, filters, query, categories)
    local selected = selected_by_id(descriptors, filters)
    local groups = {}
    for _, descriptor in ipairs(descriptors) do
        if matches(descriptor.label, query) then
            local is_selected = selected[descriptor.id] ~= nil
            local category = descriptor.category or 'Other Skills'
            groups[category] = groups[category] or {}
            table.insert(groups[category], {text=ui_format.format_available_skill_choice(
                descriptor, is_selected), descriptor=descriptor,
                selected=is_selected, search_key=descriptor.label})
        end
    end
    local choices = {}
    for _, category in ipairs(categories) do
        if groups[category] then
            table.insert(choices, {text=ui_format.format_skill_category_choice(category), search_key=category})
            for _, choice in ipairs(groups[category]) do table.insert(choices, choice) end
        end
    end
    if #choices == 0 then table.insert(choices, {text='No matching skills.'}) end
    return choices
end

---@param descriptors SoulSearchFilterDescriptor[]
---@param filters SoulSearchSelectedFilter[]
---@param query string
---@return table[]
function present_races(descriptors, filters, query)
    local choices, selected = {}, selected_by_id(descriptors, filters)
    local saw_group, gap = false, false
    for _, descriptor in ipairs(descriptors) do
        if matches(descriptor.label, query) then
            local is_selected = selected[descriptor.id] ~= nil
            local group = descriptor.id:sub(1, #RACE_GROUP_ID_PREFIX) == RACE_GROUP_ID_PREFIX
            if not group and saw_group and not gap then table.insert(choices, {text=''}); gap = true end
            table.insert(choices, {text=ui_format.format_available_filter_choice(
                descriptor, is_selected), descriptor=descriptor,
                selected=is_selected, search_key=descriptor.label})
            saw_group = saw_group or group
        end
    end
    if #choices == 0 then table.insert(choices, {text='No matching races.'}) end
    return choices
end

---@param saved string[]
---@param roles table[]
---@param combat table[]
---@param defaults table[]
---@param query string
---@return table[]
function present_presets(saved, roles, combat, defaults, query)
    local choices = {}
    local function section(title, values, field)
        local matching = {}
        for _, value in ipairs(values) do
            local label = type(value) == 'string' and value or value.label
            if matches(label, query) then table.insert(matching, value) end
        end
        if #matching == 0 then return end
        table.insert(choices, {text=title})
        for _, value in ipairs(matching) do
            local label = type(value) == 'string' and value or value.label
            local choice = {text='  ' .. label, search_key=label}
            choice[field] = type(value) == 'string' and value or value.id
            table.insert(choices, choice)
        end
    end
    section('Custom presets', saved, 'name')
    section('Role presets', roles, 'role_id')
    section('Combat presets', combat, 'role_id')
    section('Skill presets', defaults, 'default_id')
    if #choices == 0 then table.insert(choices, {text='No matching presets.'}) end
    return choices
end
