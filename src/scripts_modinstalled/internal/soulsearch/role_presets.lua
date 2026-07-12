--@ module=true

---@class SoulSearchRolePreset
---@field id string
---@field label string
---@field category 'role'|'combat'
---@field filters SoulSearchSelectedFilter[]

local descriptors = reqscript('internal/soulsearch/descriptors')

-- Skill key fallbacks cover the small naming differences between DF versions.
-- Attributes are ordered by the Wiki's A, then B, then C priority columns.
local COMBAT_ATTRIBUTES = {
    'physical_attribute:STRENGTH', 'physical_attribute:AGILITY',
    'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:TOUGHNESS',
    'mental_attribute:WILLPOWER', 'mental_attribute:SPATIAL_SENSE',
    'physical_attribute:ENDURANCE',
}

local ROLE_ROWS = {
    {id='manager', label='Manager', skills={{'ORGANIZATION'}}, attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:CREATIVITY'}},
    {id='bookkeeper', label='Bookkeeper', skills={{'RECORD_KEEPING'}}, attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:MEMORY', 'mental_attribute:FOCUS'}},
    {id='broker', label='Broker', skills={{'APPRAISAL'}, {'JUDGING_INTENT'}, {'NEGOTIATION'}}, attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:MEMORY', 'mental_attribute:INTUITION', 'mental_attribute:EMPATHY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:LINGUISTIC_ABILITY'}},
    {id='chief_medical_dwarf', label='Chief Medical Dwarf', skills={{'DIAGNOSE', 'DIAGNOSIS'}}, attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:MEMORY', 'mental_attribute:INTUITION'}},
    {id='interrogator', label='Interrogator', skills={{'JUDGING_INTENT'}}, attributes={'mental_attribute:EMPATHY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:INTUITION'}},
    {id='doctor', label='Doctor', skills={{'DIAGNOSE', 'DIAGNOSIS'}, {'SURGERY'}, {'SET_BONE', 'BONE_SETTING'}}, attributes={'mental_attribute:ANALYTICAL_ABILITY', 'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:MEMORY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:FOCUS', 'mental_attribute:INTUITION'}},
    {id='animal_trainer', label='Animal Trainer', skills={{'ANIMALTRAIN'}}, attributes={'physical_attribute:AGILITY', 'mental_attribute:EMPATHY', 'physical_attribute:TOUGHNESS', 'mental_attribute:PATIENCE', 'physical_attribute:ENDURANCE', 'mental_attribute:INTUITION'}},
}

local COMBAT_ROWS = {
    {id='soldier', label='Soldier', skills={{'MELEE_COMBAT'}, {'DODGING'}, {'SHIELD'}, {'ARMOR'}, {'DISCIPLINE'}}, attributes=COMBAT_ATTRIBUTES},
    {id='axedwarf', label='Axedwarf', skills={{'AXE'}, {'MELEE_COMBAT'}, {'DODGING'}, {'SHIELD'}, {'ARMOR'}}, attributes=COMBAT_ATTRIBUTES},
    {id='swordsdwarf', label='Swordsdwarf', skills={{'SWORD'}, {'MELEE_COMBAT'}, {'DODGING'}, {'SHIELD'}, {'ARMOR'}}, attributes=COMBAT_ATTRIBUTES},
    {id='knife_user', label='Knife User', skills={{'DAGGER'}, {'MELEE_COMBAT'}, {'DODGING'}, {'SHIELD'}, {'ARMOR'}}, attributes=COMBAT_ATTRIBUTES},
    {id='macedwarf', label='Macedwarf', skills={{'MACE'}, {'MELEE_COMBAT'}, {'DODGING'}, {'SHIELD'}, {'ARMOR'}}, attributes=COMBAT_ATTRIBUTES},
    {id='hammerdwarf', label='Hammerdwarf', skills={{'HAMMER'}, {'MELEE_COMBAT'}, {'DODGING'}, {'SHIELD'}, {'ARMOR'}}, attributes=COMBAT_ATTRIBUTES},
    {id='speardwarf', label='Speardwarf', skills={{'SPEAR'}, {'MELEE_COMBAT'}, {'DODGING'}, {'SHIELD'}, {'ARMOR'}}, attributes=COMBAT_ATTRIBUTES},
    {id='pikedwarf', label='Pikedwarf', skills={{'PIKE'}, {'MELEE_COMBAT'}, {'DODGING'}, {'SHIELD'}, {'ARMOR'}}, attributes=COMBAT_ATTRIBUTES},
    {id='lasher', label='Lasher', skills={{'WHIP'}, {'MELEE_COMBAT'}, {'DODGING'}, {'SHIELD'}, {'ARMOR'}}, attributes=COMBAT_ATTRIBUTES},
    {id='wrestler', label='Wrestler', skills={{'WRESTLING'}, {'MELEE_COMBAT'}, {'DODGING'}, {'SHIELD'}, {'ARMOR'}}, attributes=COMBAT_ATTRIBUTES},
    {id='marksdwarf', label='Marksdwarf', skills={{'CROSSBOW'}, {'ARCHERY'}, {'HAMMER'}, {'DODGING'}, {'SHIELD'}, {'ARMOR'}}, attributes={'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:FOCUS'}},
    {id='hunter', label='Hunter', skills={{'SNEAK'}, {'CROSSBOW'}, {'ARCHERY'}, {'DODGING'}}, attributes={'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:FOCUS'}},
    {id='hammerer', label='Hammerer', skills={{'HAMMER'}, {'DODGING'}}, attributes=COMBAT_ATTRIBUTES},
}

---@param catalog SoulSearchFilterCatalog
---@param keys string[]
---@return string|nil
local function find_skill_id(catalog, keys)
    for _, key in ipairs(keys) do
        local id = 'skill:' .. key
        if catalog.by_id[id] then return id end
    end
end

---@param row table
---@param catalog SoulSearchFilterCatalog
---@return SoulSearchSelectedFilter[]
local function build_filters(row, catalog)
    local filters = {}
    for _, keys in ipairs(row.skills) do
        local id = find_skill_id(catalog, keys)
        if id then table.insert(filters, {id=id, direction='high'}) end
    end
    for _, id in ipairs(row.attributes) do
        if catalog.by_id[id] then table.insert(filters, {id=id, direction='high'}) end
    end
    return filters
end

---@param rows table[]
---@param category 'role'|'combat'
---@param catalog SoulSearchFilterCatalog
---@return SoulSearchRolePreset[]
local function build_presets(rows, category, catalog)
    local presets = {}
    for _, row in ipairs(rows) do
        table.insert(presets, {id=row.id, label=row.label, category=category,
            filters=build_filters(row, catalog)})
    end
    return presets
end

---@return SoulSearchRolePreset[]
function get_all()
    local catalog = descriptors.get_catalog()
    local presets = build_presets(ROLE_ROWS, 'role', catalog)
    for _, preset in ipairs(build_presets(COMBAT_ROWS, 'combat', catalog)) do
        table.insert(presets, preset)
    end
    return presets
end

---@return SoulSearchRolePreset[]
function get_role_presets()
    return build_presets(ROLE_ROWS, 'role', descriptors.get_catalog())
end

---@return SoulSearchRolePreset[]
function get_combat_presets()
    return build_presets(COMBAT_ROWS, 'combat', descriptors.get_catalog())
end

---@param id string
---@return SoulSearchSelectedFilter[]|nil
function get(id)
    local catalog = descriptors.get_catalog()
    for _, row in ipairs(ROLE_ROWS) do
        if row.id == id then return build_filters(row, catalog) end
    end
    for _, row in ipairs(COMBAT_ROWS) do
        if row.id == id then return build_filters(row, catalog) end
    end
end
