--@ module=true

---@class SoulSearchRaceDescriptor
---@field id string
---@field kind 'race'
---@field behavior 'candidate'
---@field key string
---@field label string

local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS
local RACE = filter_constants.race

local COMPOUNDS = {
    -- Humanoids: caste has both [CAN_LEARN] and [CAN_SPEAK].
    {key=RACE.group.HUMANOIDS, label='Humanoids'},
    -- Tameable: caste has [PET] or [PET_EXOTIC].
    {key=RACE.group.TAMEABLE_ANIMALS, label='Tameable Animals'},
    -- Work: caste has [TRAINABLE_HUNTING] or [TRAINABLE_WAR].
    {key=RACE.group.WORK_ANIMALS, label='Work Animals'},
    -- Domestic: caste has [COMMON_DOMESTIC] and an ownership role: [PET],
    -- [PACK_ANIMAL], [WAGON_PULLER], or [MOUNT].
    {key=RACE.group.DOMESTIC_ANIMALS, label='Domestic Animals'},
    -- Wild: caste has [NATURAL] but is not humanoid.
    {key=RACE.group.WILD_ANIMALS, label='Wild Animals'},
    -- Megabeasts: caste has [MEGABEAST] or [SEMIMEGABEAST].
    {key=RACE.group.MEGABEASTS, label='Megabeasts'},
    -- Vermin: caste has one of the game's VERMIN_* flags.
    {key=RACE.group.VERMIN, label='Vermin'},
}

local VERMIN_FLAGS = {
    'VERMIN_GOBBLER',
    'VERMIN_HATEABLE',
    'VERMIN_MICRO',
    'VERMIN_NOFISH',
    'VERMIN_NOROAM',
    'VERMIN_NOTRAP',
    'VERMIN_FISH',
    'VERMIN_GROUNDER',
    'VERMIN_SOIL',
    'VERMIN_SOIL_COLONY',
    'VERMIN_ROTTER',
}

---@param value any
---@return string|nil
local function nonempty_string(value)
    return type(value) == 'string' and value ~= '' and value or nil
end

---@param value string
---@return string
local function title_case(value)
    local words = {}
    for word in value:gmatch('[^_]+') do
        local lower = word:lower()
        table.insert(words, lower:sub(1, 1):upper() .. lower:sub(2))
    end
    return table.concat(words, ' ')
end

---@param flags any
---@param flag string
---@return boolean
local function has_flag(flags, flag)
    if not flags then return false end
    local ok, value = pcall(function() return flags[flag] end)
    return ok and value == true
end

---@param raw df.creature_raw|nil
---@param caste df.caste_raw|nil
---@param flag string
---@return boolean
local function has_caste_flag(raw, caste, flag)
    return has_flag(caste and caste.flags, flag) or has_flag(raw and raw.flags, flag)
end

---@param raw df.creature_raw|nil
---@param caste df.caste_raw|nil
---@return boolean
local function is_humanoid(raw, caste)
    return has_caste_flag(raw, caste, 'CAN_LEARN') and
        has_caste_flag(raw, caste, 'CAN_SPEAK')
end

---@param raw df.creature_raw|nil
---@param caste df.caste_raw|nil
---@param flags string[]
---@return boolean
local function has_any_caste_flag(raw, caste, flags)
    for _, flag in ipairs(flags) do
        if has_caste_flag(raw, caste, flag) then return true end
    end
    return false
end

---@param raw df.creature_raw|nil
---@param caste df.caste_raw|nil
---@param key string
---@return boolean
local function matches_compound(raw, caste, key)
    if key == RACE.group.HUMANOIDS then return is_humanoid(raw, caste) end
    if key == RACE.group.TAMEABLE_ANIMALS then
        return has_any_caste_flag(raw, caste, {'PET', 'PET_EXOTIC'})
    end
    if key == RACE.group.WORK_ANIMALS then
        return has_any_caste_flag(raw, caste, {
            'TRAINABLE_HUNTING', 'TRAINABLE_WAR',
        })
    end
    if key == RACE.group.DOMESTIC_ANIMALS then
        return has_caste_flag(raw, caste, 'COMMON_DOMESTIC') and
            has_any_caste_flag(raw, caste, {
                'PET', 'PACK_ANIMAL', 'WAGON_PULLER', 'MOUNT',
            })
    end
    if key == RACE.group.WILD_ANIMALS then
        return has_caste_flag(raw, caste, 'NATURAL') and
            not is_humanoid(raw, caste)
    end
    if key == RACE.group.MEGABEASTS then
        return has_any_caste_flag(raw, caste, {'MEGABEAST', 'SEMIMEGABEAST'})
    end
    if key == RACE.group.VERMIN then
        return has_any_caste_flag(raw, caste, VERMIN_FLAGS)
    end
    return false
end

---@param raw df.creature_raw|nil
---@return string|nil
local function get_creature_id(raw)
    return raw and nonempty_string(raw.creature_id) or nil
end

---@param raw df.creature_raw
---@return string
local function get_label(raw)
    local name = raw.name and nonempty_string(raw.name[0])
    if name then return name:gsub('^%l', string.upper) end
    return title_case(assert(get_creature_id(raw)))
end

---@param left SoulSearchRaceDescriptor
---@param right SoulSearchRaceDescriptor
---@return boolean
local function compare_descriptors(left, right)
    if left.label ~= right.label then return left.label < right.label end
    return left.id < right.id
end

---@return SoulSearchRaceDescriptor[]
local function build_descriptors()
    local result = {}
    for _, compound in ipairs(COMPOUNDS) do
        table.insert(result, {
            id=RACE.group_id_prefix .. compound.key,
            kind=filter_constants.kind.RACE,
            behavior=filter_constants.behavior.CANDIDATE,
            key=compound.key,
            label=compound.label,
        })
    end

    local individual = {}
    local seen_ids = {}
    local raws = df.global and df.global.world and df.global.world.raws
    for _, raw in ipairs(raws and raws.creatures and raws.creatures.all or {}) do
        local creature_id = get_creature_id(raw)
        if creature_id then
            assert(not seen_ids[creature_id],
                'duplicate SoulSearch creature ID: ' .. creature_id)
            seen_ids[creature_id] = true
            table.insert(individual, {
                id=RACE.raw_id_prefix .. creature_id,
                kind=filter_constants.kind.RACE,
                behavior=filter_constants.behavior.CANDIDATE,
                key=creature_id,
                label=get_label(raw),
            })
        end
    end
    table.sort(individual, compare_descriptors)
    for _, descriptor in ipairs(individual) do table.insert(result, descriptor) end
    return result
end

local descriptors

---Returns ordered immutable race metadata for this loaded world generation.
---@return SoulSearchRaceDescriptor[]
function get_descriptors()
    if not descriptors then descriptors = build_descriptors() end
    return descriptors
end

---@param unit df.unit|nil
---@return df.creature_raw|nil raw
---@return df.caste_raw|nil caste
local function get_unit_raws(unit)
    if not unit or type(unit.race) ~= 'number' or type(unit.caste) ~= 'number' then
        return nil, nil
    end
    local raws = df.global and df.global.world and df.global.world.raws
    local raw = raws and raws.creatures and raws.creatures.all[unit.race]
    return raw, raw and raw.caste and raw.caste[unit.caste] or nil
end

---Tests a descriptor against a concrete unit's race and caste raw data.
---@param descriptor SoulSearchRaceDescriptor|nil
---@param unit df.unit|nil
---@return boolean
function matches_unit(descriptor, unit)
    if not descriptor or descriptor.kind ~= filter_constants.kind.RACE then
        return false
    end
    local raw, caste = get_unit_raws(unit)
    if not raw then return false end
    if descriptor.id:sub(1, #RACE.raw_id_prefix) == RACE.raw_id_prefix then
        return descriptor.key == get_creature_id(raw)
    end
    if descriptor.id:sub(1, #RACE.group_id_prefix) == RACE.group_id_prefix then
        -- Compound tags are caste-level. A missing caste must never create an
        -- accidental match from similarly named creature-level flags.
        return caste ~= nil and matches_compound(raw, caste, descriptor.key)
    end
    return false
end

---Clears race metadata after a world boundary before a new search pass.
function reset_cache()
    descriptors = nil
end
