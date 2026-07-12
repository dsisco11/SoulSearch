--@ module=true

---@class SoulSearchRolePreset
---@field id string
---@field label string
---@field category 'role'|'combat'
---@field filters SoulSearchSelectedFilter[]

local descriptors = reqscript('internal/soulsearch/descriptors')
local filter_defaults = reqscript('internal/soulsearch/filter_defaults')

-- Skill key fallbacks cover the small naming differences between DF versions.
-- Attributes are ordered by the Wiki's A, then B, then C priority columns.
local COMBAT_ATTRIBUTES = {
    'physical_attribute:STRENGTH', 'physical_attribute:AGILITY',
    'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:TOUGHNESS',
    'mental_attribute:WILLPOWER', 'mental_attribute:SPATIAL_SENSE',
    'physical_attribute:ENDURANCE',
}

local SOCIAL_ATTRIBUTES = {
    'mental_attribute:EMPATHY', 'mental_attribute:SOCIAL_AWARENESS',
    'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:INTUITION',
    'mental_attribute:MEMORY',
}

local LEADER_ATTRIBUTES = {
    'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:WILLPOWER',
    'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:EMPATHY',
    'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:MEMORY',
}

local ROLE_ROWS = {
    {id='manager', label='Manager', skills={{'ORGANIZATION'}}, attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:CREATIVITY'}},
    {id='bookkeeper', label='Bookkeeper', skills={{'RECORD_KEEPING'}}, attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:MEMORY', 'mental_attribute:FOCUS'}},
    {id='broker', label='Broker', skills={{'APPRAISAL'}, {'JUDGING_INTENT'}, {'NEGOTIATION'}}, attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:MEMORY', 'mental_attribute:INTUITION', 'mental_attribute:EMPATHY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:LINGUISTIC_ABILITY'}},
    {id='chief_medical_dwarf', label='Chief Medical Dwarf', skills={{'DIAGNOSE', 'DIAGNOSIS'}}, attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:MEMORY', 'mental_attribute:INTUITION'}},
    {id='interrogator', label='Interrogator', skills={{'JUDGING_INTENT'}}, attributes={'mental_attribute:EMPATHY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:INTUITION'}},
    {id='doctor', label='Doctor', skills={{'DIAGNOSE', 'DIAGNOSIS'}, {'SURGERY'}, {'SET_BONE', 'BONE_SETTING'}, {'SUTURE', 'SUTURER'}, {'DRESS_WOUNDS', 'WOUND_DRESSER'}}, attributes={'mental_attribute:ANALYTICAL_ABILITY', 'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:MEMORY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:FOCUS', 'mental_attribute:INTUITION'}},
    {id='animal_trainer', label='Animal Trainer', skills={{'ANIMALTRAIN'}}, attributes={'physical_attribute:AGILITY', 'mental_attribute:EMPATHY', 'physical_attribute:TOUGHNESS', 'mental_attribute:PATIENCE', 'physical_attribute:ENDURANCE', 'mental_attribute:INTUITION'}},
    {id='trader', label='Trader', skills={{'APPRAISAL'}, {'JUDGING_INTENT'}, {'NEGOTIATION'}, {'LYING'}}, attributes=SOCIAL_ATTRIBUTES},
    {id='mayor', label='Mayor', skills={{'LEADERSHIP'}, {'ORGANIZATION'}, {'JUDGING_INTENT'}, {'PERSUASION'}, {'CONVERSATION'}}, attributes=LEADER_ATTRIBUTES},
    {id='expedition_leader', label='Expedition Leader', skills={{'LEADERSHIP'}, {'ORGANIZATION'}, {'JUDGING_INTENT'}, {'PERSUASION'}, {'CONVERSATION'}}, attributes=LEADER_ATTRIBUTES},
    {id='baron', label='Baron', skills={{'LEADERSHIP'}, {'NEGOTIATION'}, {'JUDGING_INTENT'}, {'CONVERSATION'}}, attributes=LEADER_ATTRIBUTES},
    {id='count', label='Count', skills={{'LEADERSHIP'}, {'NEGOTIATION'}, {'JUDGING_INTENT'}, {'CONVERSATION'}}, attributes=LEADER_ATTRIBUTES},
    {id='duke', label='Duke', skills={{'LEADERSHIP'}, {'NEGOTIATION'}, {'JUDGING_INTENT'}, {'CONVERSATION'}}, attributes=LEADER_ATTRIBUTES},
    {id='sheriff', label='Sheriff', skills={{'JUDGING_INTENT'}, {'INTIMIDATION'}, {'PERSUASION'}}, attributes=SOCIAL_ATTRIBUTES},
    {id='captain_of_the_guard', label='Captain of the Guard', skills={{'LEADERSHIP'}, {'MILITARY_TACTICS'}, {'JUDGING_INTENT'}, {'INTIMIDATION'}, {'PERSUASION'}}, attributes=LEADER_ATTRIBUTES},
    {id='scholar', label='Scholar', skills={{'CRITICAL_THINKING'}, {'LOGIC'}, {'READING'}, {'WRITING'}, {'TEACHING'}}, attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:CREATIVITY', 'mental_attribute:MEMORY', 'mental_attribute:FOCUS', 'mental_attribute:LINGUISTIC_ABILITY'}},
    {id='scribe', label='Scribe', skills={{'WRITING'}, {'READING'}}, attributes={'mental_attribute:CREATIVITY', 'mental_attribute:MEMORY', 'mental_attribute:FOCUS', 'mental_attribute:LINGUISTIC_ABILITY'}},
    {id='performer', label='Performer', skills={{'POETRY'}, {'DANCE'}, {'MAKE_MUSIC'}, {'SING_MUSIC'}, {'SPEAKING'}}, attributes={'mental_attribute:CREATIVITY', 'mental_attribute:MUSICALITY', 'mental_attribute:EMPATHY', 'mental_attribute:SOCIAL_AWARENESS', 'physical_attribute:AGILITY'}},
    {id='tavern_keeper', label='Tavern Keeper', skills={{'SPEAKING'}, {'CONVERSATION'}, {'JUDGING_INTENT'}}, attributes=SOCIAL_ATTRIBUTES},
    {id='dungeon_master', label='Dungeon Master', skills={{'ANIMALTRAIN'}, {'ORGANIZATION'}, {'JUDGING_INTENT'}}, attributes=LEADER_ATTRIBUTES},
    {id='champion', label='Champion', skills={{'MELEE_COMBAT'}, {'DODGING'}, {'SHIELD'}, {'ARMOR'}, {'LEADERSHIP'}}, attributes=COMBAT_ATTRIBUTES},
    {id='messenger', label='Messenger', skills={{'CONVERSATION'}, {'JUDGING_INTENT'}, {'PERSUASION'}}, attributes=SOCIAL_ATTRIBUTES},
}

local COMBAT_ROWS = {
    {id='militia_commander', label='Militia Commander', skills={{'LEADERSHIP'}, {'MILITARY_TACTICS'}, {'ORGANIZATION'}, {'AMBUSHER'}}, attributes=LEADER_ATTRIBUTES},
    {id='militia_captain', label='Militia Captain', skills={{'LEADERSHIP'}, {'MILITARY_TACTICS'}, {'ORGANIZATION'}}, attributes=LEADER_ATTRIBUTES},
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

-- These IDs intentionally reuse the wiki-backed skill preset mappings rather
-- than duplicating the associated mental/physical attribute data here.
local SKILL_DEFAULTS = {
    ORGANIZATION='organizer', RECORD_KEEPING='record_keeper',
    APPRAISAL='appraiser', JUDGING_INTENT='judge_of_intent',
    NEGOTIATION='negotiator', DIAGNOSE='diagnostician', DIAGNOSIS='diagnostician',
    SURGERY='surgeon', SET_BONE='bone_doctor', BONE_SETTING='bone_doctor',
    SUTURE='suturer', SUTURER='suturer', DRESS_WOUNDS='wound_dresser',
    WOUND_DRESSER='wound_dresser',
    ANIMALTRAIN='animal_trainer', AXE='axeman', SWORD='swordsman',
    DAGGER='knife_user', MACE='maceman', HAMMER='hammerman', SPEAR='spearman',
    PIKE='pikeman', WHIP='lasher', WRESTLING='wrestler',
    CROSSBOW='crossbowman', ARCHERY='archer', SNEAK='ambusher',
    MELEE_COMBAT='fighter', DODGING='dodger', SHIELD='shield_user',
    ARMOR='armor_user', DISCIPLINE='discipline',
    LYING='liar', PERSUASION='persuader', INTIMIDATION='intimidator',
    CONVERSATION='conversationalist', WRITING='writer', READING='reader',
    TEACHING='teacher', CRITICAL_THINKING='critical_thinker', LOGIC='logician',
    POETRY='poet', DANCE='dancer', MAKE_MUSIC='musician', SING_MUSIC='musician',
    SPEAKING='speaker',
}

---@param catalog SoulSearchFilterCatalog
---@param keys string[]
---@return string|nil, string|nil
local function find_skill_id(catalog, keys)
    for _, key in ipairs(keys) do
        local id = 'skill:' .. key
        if catalog.by_id[id] then return id, key end
    end
end

---@param row table
---@param catalog SoulSearchFilterCatalog
---@return SoulSearchSelectedFilter[]
local function build_filters(row, catalog)
    local filters = {}
    local seen = {}
    local skill_keys = {}
    for _, keys in ipairs(row.skills) do
        local id, key = find_skill_id(catalog, keys)
        if id then
            table.insert(filters, {id=id, direction='high'})
            seen[id] = true
            table.insert(skill_keys, key)
        end
    end
    for _, id in ipairs(row.attributes) do
        if catalog.by_id[id] and not seen[id] then
            table.insert(filters, {id=id, direction='high'})
            seen[id] = true
        end
    end
    for _, skill_key in ipairs(skill_keys) do
        local default_id = SKILL_DEFAULTS[skill_key]
        local defaults = default_id and filter_defaults.get(default_id)
        if defaults then
            for _, filter in ipairs(defaults) do
                if catalog.by_id[filter.id] and not seen[filter.id] then
                    table.insert(filters, {id=filter.id, direction=filter.direction})
                    seen[filter.id] = true
                end
            end
        end
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
