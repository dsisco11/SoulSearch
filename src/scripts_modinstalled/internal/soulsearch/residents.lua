--@ module=true

---@class SoulSearchEnumEntry
---@field name string
---@field value integer

---@class SoulSearchResidentRow
---@field unit df.unit
---@field unit_id integer
---@field name string
---@field profession string
---@field traits table<string, number>
---@field mental_attributes table<string, number>
---@field physical_attributes table<string, number>
---@field skills table<string, number>

---@param enum table
---@return SoulSearchEnumEntry[]
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

local skill_name_by_id

---@param skill_id integer
---@return string|nil
local function get_skill_name_by_id(skill_id)
    if not skill_name_by_id then
        skill_name_by_id = {}
        for _, skill in ipairs(enum_keys(df.job_skill)) do
            skill_name_by_id[skill.value] = skill.name
        end
    end
    return skill_name_by_id[skill_id]
end

---@param unit df.unit
---@return table<string, number>
local function get_trait_values(unit)
    local values = {}
    local soul = unit.status and unit.status.current_soul
    local personality = soul and soul.personality
    local traits = personality and personality.traits
    if not traits then
        return values
    end

    for _, trait in ipairs(enum_keys(df.personality_facet_type)) do
        local ok, value = pcall(function() return traits[trait.value] end)
        if ok and value ~= nil then
            values[trait.name] = value
        end
    end
    return values
end

---@param unit df.unit
---@return table<string, number>
local function get_mental_attribute_values(unit)
    local values = {}
    for _, attr in ipairs(enum_keys(df.mental_attribute_type)) do
        local ok, value = pcall(dfhack.units.getMentalAttrValue, unit, attr.value)
        if ok and value ~= nil then
            values[attr.name] = value
        end
    end
    return values
end

---@param unit df.unit
---@return table<string, number>
local function get_physical_attribute_values(unit)
    local values = {}
    for _, attr in ipairs(enum_keys(df.physical_attribute_type)) do
        local ok, value = pcall(dfhack.units.getPhysicalAttrValue, unit, attr.value)
        if ok and value ~= nil then
            values[attr.name] = value
        end
    end
    return values
end

---@param rating number|nil
---@return number
local function get_skill_xp_to_next_level(rating)
    return 500 + math.max(rating or 0, 0) * 100
end

---@param skill df.unit_skill
---@return number
local function get_skill_value(skill)
    local rating = skill.rating or 0
    local experience = math.max(skill.experience or 0, 0)
    local xp_to_next_level = get_skill_xp_to_next_level(rating)
    local progress = math.min(experience / xp_to_next_level, 0.99)
    return rating + 1 + progress
end

---@param unit df.unit
---@return table<string, number>
local function get_skill_values(unit)
    local values = {}
    local soul = unit.status and unit.status.current_soul
    local skills = soul and soul.skills
    if not skills then
        return values
    end

    for _, skill in ipairs(skills) do
        local skill_name = get_skill_name_by_id(skill.id)
        if skill_name then
            values[skill_name] = get_skill_value(skill)
        end
    end
    return values
end

---@param value any
---@return boolean
local function nonempty_string(value)
    return type(value) == 'string' and value ~= ''
end

---@param name df.language_name|nil
---@param in_english boolean
---@return string|nil
local function translate_visible_name(name, in_english)
    if not name then
        return nil
    end

    local ok, translated_name = pcall(dfhack.translation.translateName, name, in_english)
    if ok and nonempty_string(translated_name) then
        return translated_name
    end
    return nil
end

---@param unit df.unit
---@return string
local function get_display_name(unit)
    local visible_name = dfhack.units.getVisibleName(unit)
    local native_name = translate_visible_name(visible_name, false)
    local english_name = translate_visible_name(visible_name, true)

    if native_name and english_name and native_name ~= english_name then
        return ('%s "%s"'):format(native_name, english_name)
    end
    if native_name then
        return native_name
    end
    if english_name then
        return english_name
    end
    return ('Unit #%d'):format(unit.id)
end

---@param unit df.unit
---@return SoulSearchResidentRow
local function build_resident_row(unit)
    return {
        unit=unit,
        unit_id=unit.id,
        name=get_display_name(unit),
        profession=dfhack.units.getProfessionName(unit),
        traits=get_trait_values(unit),
        mental_attributes=get_mental_attribute_values(unit),
        physical_attributes=get_physical_attribute_values(unit),
        skills=get_skill_values(unit),
    }
end

---Gets the reason resident data cannot currently be collected.
---@return string|nil
function get_unavailable_reason()
    if not dfhack.isMapLoaded() then
        return 'SoulSearch requires a loaded fortress map.'
    end
    if not dfhack.world.isFortressMode() then
        return 'SoulSearch only works in fortress mode.'
    end
    return nil
end

---Collects searchable rows for fortress citizens.
---@return SoulSearchResidentRow[]|nil rows
---@return string|nil error
function collect_residents()
    local reason = get_unavailable_reason()
    if reason then
        return nil, reason
    end

    local rows = {}
    for _, unit in ipairs(dfhack.units.getCitizens(false, true)) do
        table.insert(rows, build_resident_row(unit))
    end
    return rows
end
