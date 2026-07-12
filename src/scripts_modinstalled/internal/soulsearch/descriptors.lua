--@ module=true

---@class SoulSearchFilterDescriptor
---@field id string
---@field kind SoulSearchFilterKind
---@field behavior SoulSearchFilterBehavior
---@field key string
---@field label string
---@field category string|nil

---@class SoulSearchFilterDescriptorGroups
---@field skills SoulSearchFilterDescriptor[]
---@field traits SoulSearchFilterDescriptor[]
---@field mental_attributes SoulSearchFilterDescriptor[]
---@field physical_attributes SoulSearchFilterDescriptor[]
---@field races SoulSearchFilterDescriptor[]

---@class SoulSearchFilterCatalog
---@field groups SoulSearchFilterDescriptorGroups
---@field flat SoulSearchFilterDescriptor[]
---@field by_id table<string, SoulSearchFilterDescriptor>

local df_enums = reqscript('internal/soulsearch/df_enums')
local skill_categories = reqscript('internal/soulsearch/skill_categories')
local race_catalog = reqscript('internal/soulsearch/race_catalog')
local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

---@alias SoulSearchFilterBehavior 'candidate'|'ranking'
---@alias SoulSearchFilterKind SoulSearchStatKind|'race'

---@param name string
---@return string
local function title_case_enum_name(name)
    local words = {}
    for word in name:gmatch('[^_]+') do
        local lower = word:lower()
        table.insert(words, lower:sub(1, 1):upper() .. lower:sub(2))
    end
    return table.concat(words, ' ')
end

---@param name any
---@return string|nil
local function title_case_display_name(name)
    if type(name) ~= 'string' or name == '' then
        return nil
    end
    return name:gsub('^%l', string.upper)
end

---@param enum table
---@param key string
---@param value integer
---@return table|nil
local function get_enum_attr(enum, key, value)
    local attrs = enum.attrs
    if not attrs then
        return nil
    end
    return attrs[value] or attrs[key]
end

---@param attr table
---@param field string
---@return string|nil
local function get_attr_string(attr, field)
    local ok, value = pcall(function() return attr[field] end)
    if ok and type(value) == 'string' and value ~= '' then
        return value
    end
    return nil
end

---@param skill SoulSearchEnumEntry
---@return string
local function get_skill_label(skill)
    local attrs = get_enum_attr(df.job_skill, skill.name, skill.value)
    if attrs then
        local caption = get_attr_string(attrs, 'caption') or
            get_attr_string(attrs, 'caption_noun')
        local label = title_case_display_name(caption)
        if label then
            return label
        end
    end
    return title_case_enum_name(skill.name)
end

---@param kind SoulSearchStatKind
---@param key string
---@param label string
---@return SoulSearchFilterDescriptor
local function make_descriptor(kind, key, label)
    return {
        id=kind .. ':' .. key,
        kind=kind,
        behavior=filter_constants.behavior.RANKING,
        key=key,
        label=label,
    }
end

---@param descriptor_list SoulSearchFilterDescriptor[]
---@return SoulSearchFilterDescriptor[]
local function sort_by_label(descriptor_list)
    table.sort(descriptor_list, function(left, right)
        if left.label ~= right.label then
            return left.label < right.label
        end
        return left.id < right.id
    end)
    return descriptor_list
end

---@param kind SoulSearchStatKind
---@param enum table
---@return SoulSearchFilterDescriptor[]
local function make_enum_descriptors(kind, enum)
    local result = {}
    for _, entry in ipairs(df_enums.entries(enum)) do
        table.insert(result, make_descriptor(
            kind,
            entry.name,
            title_case_enum_name(entry.name)))
    end
    return sort_by_label(result)
end

---@return SoulSearchFilterDescriptor[]
local function make_skill_descriptors()
    local result = {}
    for _, skill in ipairs(df_enums.entries(df.job_skill)) do
        local descriptor = make_descriptor(
            'skill',
            skill.name,
            get_skill_label(skill))
        descriptor.category = skill_categories.get_category(skill.name)
        table.insert(result, descriptor)
    end
    return sort_by_label(result)
end

---@param flat SoulSearchFilterDescriptor[]
---@param by_id table<string, SoulSearchFilterDescriptor>
---@param descriptor_list SoulSearchFilterDescriptor[]
local function index_descriptors(flat, by_id, descriptor_list)
    for _, descriptor in ipairs(descriptor_list) do
        assert(not by_id[descriptor.id],
            'duplicate SoulSearch filter descriptor id: ' .. descriptor.id)
        by_id[descriptor.id] = descriptor
        table.insert(flat, descriptor)
    end
end

---@return SoulSearchFilterCatalog
local function build_catalog()
    local groups = {
        skills=make_skill_descriptors(),
        traits=make_enum_descriptors('trait', df.personality_facet_type),
        mental_attributes=make_enum_descriptors(
            'mental_attribute', df.mental_attribute_type),
        physical_attributes=make_enum_descriptors(
            'physical_attribute', df.physical_attribute_type),
        races=race_catalog.get_descriptors(),
    }
    local flat = {}
    local by_id = {}

    -- Preserve the established flat ordering used by UI validation and saved
    -- filter state. Tables in the returned catalog are shared immutable metadata.
    index_descriptors(flat, by_id, groups.skills)
    index_descriptors(flat, by_id, groups.physical_attributes)
    index_descriptors(flat, by_id, groups.mental_attributes)
    index_descriptors(flat, by_id, groups.traits)
    index_descriptors(flat, by_id, groups.races)

    return {groups=groups, flat=flat, by_id=by_id}
end

local catalog

---Clears immutable descriptor metadata between module/world generations.
---Callers must invoke this only between UI/search passes.
function reset_cache()
    catalog = nil
end

---Returns the descriptor catalog for this loaded script environment.
---DF enum metadata is stable for that lifetime; reloading this module creates a
---new environment and catalog, so lookup/search never rebuilds it implicitly.
---@return SoulSearchFilterCatalog
function get_catalog()
    if not catalog then
        catalog = build_catalog()
    end
    return catalog
end
