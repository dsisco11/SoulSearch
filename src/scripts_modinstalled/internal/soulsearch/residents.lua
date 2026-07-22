--@ module=true

---@class SoulSearchResidentRow
---Historical name retained for compatibility. Its structure supports any
---compatible df.unit, not only a fortress resident.
---@field unit df.unit
---@field unit_id integer
---@field name string
---@field profession string
---@field traits table<string, number>
---@field mental_attributes table<string, number>
---@field physical_attributes table<string, number>
---@field skills table<string, number>

---@class SoulSearchResidentSnapshot
---@field unit df.unit
---@field unit_id integer
---@field native_name string|nil
---@field english_name string|nil
---@field readable_name string|nil
---@field profession string|nil
---@field traits table<string, number>
---@field mental_attributes table<string, number>
---@field physical_attributes table<string, number>
---@field skills df.unit_skill[]|nil

local df_enums = reqscript('internal/soulsearch/df_enums')
local availability = reqscript('internal/soulsearch/availability')

local skill_name_by_id

---@param skill_id integer
---@return string|nil
local function get_skill_name_by_id(skill_id)
    if not skill_name_by_id then
        skill_name_by_id = df_enums.names_by_value(df.job_skill)
    end
    return skill_name_by_id[skill_id]
end

---@param unit df.unit
---@return table<string, number>
local function read_trait_values(unit)
    local values = {}
    local soul = unit.status and unit.status.current_soul
    local personality = soul and soul.personality
    local traits = personality and personality.traits
    if not traits then
        return values
    end

    for _, trait in ipairs(df_enums.entries(df.personality_facet_type)) do
        local value = traits[trait.value]
        if value ~= nil then
            values[trait.name] = value
        end
    end
    return values
end

---@param unit df.unit
---@return table<string, number>
local function read_mental_attribute_values(unit)
    local values = {}
    for _, attr in ipairs(df_enums.entries(df.mental_attribute_type)) do
        local value = dfhack.units.getMentalAttrValue(unit, attr.value)
        if value ~= nil then
            values[attr.name] = value
        end
    end
    return values
end

---@param unit df.unit
---@return table<string, number>
local function read_physical_attribute_values(unit)
    local values = {}
    for _, attr in ipairs(df_enums.entries(df.physical_attribute_type)) do
        local value = dfhack.units.getPhysicalAttrValue(unit, attr.value)
        if value ~= nil then
            values[attr.name] = value
        end
    end
    return values
end

---@param rating number|nil
---@return number
local function get_skill_xp_to_next_level(rating)
    -- DFHack 53.15's modtools/skill-change.lua defines the next-level cost as
    -- 400 + 100 * (rating + 1), equivalent to 500 + 100 * current rating.
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

---@param skills df.unit_skill[]|nil
---@return table<string, number>
local function get_skill_values(skills)
    local values = {}
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

---@param snapshot SoulSearchResidentSnapshot
---@return string
local function get_display_name(snapshot)
    local native_name = snapshot.native_name
    local english_name = snapshot.english_name

    if native_name and english_name and native_name ~= english_name then
        return ('%s "%s"'):format(native_name, english_name)
    end
    if native_name then
        return native_name
    end
    if english_name then
        return english_name
    end
    if snapshot.readable_name then
        return snapshot.readable_name
    end
    return ('Unit #%d'):format(snapshot.unit_id)
end

---@param name df.language_name|nil
---@param in_english boolean
---@return string|nil
local function translate_visible_name(name, in_english)
    if not name then return nil end
    local translated_name = dfhack.translation.translateName(name, in_english)
    return nonempty_string(translated_name) and translated_name or nil
end

---@param unit df.unit
---@return SoulSearchResidentSnapshot
local function read_resident(unit)
    local visible_name = dfhack.units.getVisibleName(unit)
    local native_name = translate_visible_name(visible_name, false)
    local english_name = translate_visible_name(visible_name, true)
    local readable_name
    if not native_name and not english_name and
            type(dfhack.units.getReadableName) == 'function' then
        local name = dfhack.units.getReadableName(unit)
        readable_name = nonempty_string(name) and name or nil
    end
    local soul = unit.status and unit.status.current_soul
    return {
        unit=unit,
        unit_id=unit.id,
        native_name=native_name,
        english_name=english_name,
        readable_name=readable_name,
        profession=dfhack.units.getProfessionName(unit),
        traits=read_trait_values(unit),
        mental_attributes=read_mental_attribute_values(unit),
        physical_attributes=read_physical_attribute_values(unit),
        skills=soul and soul.skills or nil,
    }
end

---@param snapshot SoulSearchResidentSnapshot
---@return SoulSearchResidentRow
function build_resident_row(snapshot)
    return {
        unit=snapshot.unit,
        unit_id=snapshot.unit_id,
        name=get_display_name(snapshot),
        profession=snapshot.profession or '',
        traits=snapshot.traits or {},
        mental_attributes=snapshot.mental_attributes or {},
        physical_attributes=snapshot.physical_attributes or {},
        skills=get_skill_values(snapshot.skills),
    }
end

---Builds immutable search rows for a provider-selected sequence of units.
---@param units df.unit[]|nil
---@return SoulSearchResidentRow[]
function collect_units(units)
    local rows = {}
    for _, unit in ipairs(units or {}) do
        table.insert(rows, build_resident_row(read_resident(unit)))
    end
    return rows
end

---@param unit any
---@return integer|nil unit_id
---@return string|nil error
function validate_unit_reference(unit)
    if type(unit) ~= 'table' and type(unit) ~= 'userdata' then
        return nil, 'SoulSearch requires a valid unit.'
    end
    local ok, unit_id = pcall(function() return unit.id end)
    if not ok or type(unit_id) ~= 'number' or unit_id < 0 or
            unit_id ~= math.floor(unit_id) then
        return nil, 'SoulSearch requires a valid unit.'
    end
    return unit_id, nil
end

---Collects and snapshots units from an already-scoped candidate provider.
---@param provider SoulSearchCandidateProvider
---@return SoulSearchResidentRow[]|nil rows
---@return string|nil error
function collect_from_provider(provider)
    assert(type(provider) == 'table' and type(provider.get_units) == 'function',
        'SoulSearch resident collection requires a candidate provider')
    local units, err = provider.get_units()
    if not units then return nil, err end
    return collect_units(units)
end

---Clears the job-skill ID/name cache. Lifecycle code calls this between update
---passes, never during resident collection or search evaluation.
function reset_cache()
    skill_name_by_id = nil
end

---Gets the reason resident data cannot currently be collected.
---@return string|nil
function get_unavailable_reason()
    return availability.get_unavailable_reason()
end

---Collects searchable rows for fortress citizens.
---@return SoulSearchResidentRow[]|nil rows
---@return string|nil error
function collect_residents()
    local reason = get_unavailable_reason()
    if reason then
        return nil, reason
    end

    return collect_units(dfhack.units.getCitizens(false, true))
end

---Collects one compatible unit without scanning a candidate scope.
---@param unit any
---@return SoulSearchResidentRow|nil row
---@return string|nil error
function collect_unit(unit)
    local reason = get_unavailable_reason()
    if reason then return nil, reason end
    local unit_id, err = validate_unit_reference(unit)
    if not unit_id then return nil, err end
    local rows = collect_units({unit})
    return rows[1], nil
end
