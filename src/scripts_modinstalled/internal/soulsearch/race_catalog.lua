--@ module=true

---@class SoulSearchRaceDescriptor
---@field id string
---@field kind 'race'
---@field behavior 'candidate'
---@field key string
---@field label string

local COMPOUNDS = {
    -- Humanoids: caste has both [CAN_LEARN] and [CAN_SPEAK].
    {key='HUMANOIDS', label='Humanoids'},
    -- Trainable: caste has [PET], [PET_EXOTIC], [TRAINABLE_HUNTING], or
    -- [TRAINABLE_WAR].
    {key='TRAINABLE_ANIMALS', label='Trainable Animals'},
    -- Domestic: caste has [COMMON_DOMESTIC] and an ownership role: [PET],
    -- [PACK_ANIMAL], [WAGON_PULLER], or [MOUNT].
    {key='DOMESTIC_ANIMALS', label='Domestic Animals'},
    -- Wild: caste has [NATURAL] but is not humanoid.
    {key='WILD_ANIMALS', label='Wild Animals'},
    -- Megabeasts: caste has [MEGABEAST] or [SEMIMEGABEAST].
    {key='MEGABEASTS', label='Megabeasts'},
    -- Vermin: caste has one of the game's VERMIN_* flags.
    {key='VERMIN', label='Vermin'},
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
    if key == 'HUMANOIDS' then return is_humanoid(raw, caste) end
    if key == 'TRAINABLE_ANIMALS' then
        return has_any_caste_flag(raw, caste, {
            'PET', 'PET_EXOTIC', 'TRAINABLE_HUNTING', 'TRAINABLE_WAR',
        })
    end
    if key == 'DOMESTIC_ANIMALS' then
        return has_caste_flag(raw, caste, 'COMMON_DOMESTIC') and
            has_any_caste_flag(raw, caste, {
                'PET', 'PACK_ANIMAL', 'WAGON_PULLER', 'MOUNT',
            })
    end
    if key == 'WILD_ANIMALS' then
        return has_caste_flag(raw, caste, 'NATURAL') and
            not is_humanoid(raw, caste)
    end
    if key == 'MEGABEASTS' then
        return has_any_caste_flag(raw, caste, {'MEGABEAST', 'SEMIMEGABEAST'})
    end
    if key == 'VERMIN' then
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
            id='race:group:' .. compound.key,
            kind='race',
            behavior='candidate',
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
                id='race:raw:' .. creature_id,
                kind='race',
                behavior='candidate',
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
    if not descriptor or descriptor.kind ~= 'race' then return false end
    local raw, caste = get_unit_raws(unit)
    if not raw then return false end
    if descriptor.id:sub(1, 9) == 'race:raw:' then
        return descriptor.key == get_creature_id(raw)
    end
    if descriptor.id:sub(1, 11) == 'race:group:' then
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
