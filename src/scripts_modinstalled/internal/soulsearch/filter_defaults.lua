--@ module=true

local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

---@class SoulSearchBuiltInFilterPreset
---@field id string
---@field label string
---@field filters SoulSearchSelectedFilter[]

-- Source: https://dwarffortresswiki.org/index.php/Attribute
-- Generated from the wiki's current Skills by associated attributes table.
-- Attributes are listed in the Wiki's A, then B, then C priority order.
-- Entries use the catalog's physical:/mental: filter-ID prefixes.
---@type {id: string, label: string, attributes: string[]}[]
local WIKI_ROWS = {
    {id='miner', label='Miner', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:TOUGHNESS', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:WILLPOWER'}},
    {id='wood_cutter', label='Wood cutter', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:WILLPOWER'}},
    {id='carpenter', label='Carpenter', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'mental:CREATIVITY'}},
    {id='engraver', label='Engraver', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:CREATIVITY'}},
    {id='mason', label='Mason', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:CREATIVITY'}},
    {id='animal_trainer', label='Animal trainer', attributes={'physical:AGILITY', 'mental:EMPATHY', 'physical:TOUGHNESS', 'mental:PATIENCE', 'physical:ENDURANCE', 'mental:INTUITION'}},
    {id='animal_caretaker', label='Animal caretaker', attributes={'physical:AGILITY', 'mental:ANALYTICAL_ABILITY', 'mental:MEMORY', 'mental:EMPATHY'}},
    {id='fish_dissector', label='Fish dissector', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE'}},
    {id='animal_dissector', label='Animal dissector', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE'}},
    {id='fish_cleaner', label='Fish cleaner', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:ENDURANCE'}},
    {id='butcher', label='Butcher', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'physical:ENDURANCE'}},
    {id='trapper', label='Trapper', attributes={'physical:AGILITY', 'mental:ANALYTICAL_ABILITY', 'mental:CREATIVITY', 'mental:SPATIAL_SENSE'}},
    {id='tanner', label='Tanner', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE'}},
    {id='weaver', label='Weaver', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:CREATIVITY'}},
    {id='brewer', label='Brewer', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY'}},
    {id='clothier', label='Clothier', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:CREATIVITY'}},
    {id='miller', label='Miller', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'physical:ENDURANCE'}},
    {id='thresher', label='Thresher', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:STRENGTH', 'physical:ENDURANCE'}},
    {id='cheese_maker', label='Cheese maker', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:STRENGTH', 'mental:ANALYTICAL_ABILITY', 'physical:ENDURANCE', 'mental:CREATIVITY'}},
    {id='milker', label='Milker', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'physical:ENDURANCE'}},
    {id='cook', label='Cook', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:ANALYTICAL_ABILITY', 'mental:CREATIVITY'}},
    {id='planter', label='Planter', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'physical:ENDURANCE'}},
    {id='herbalist', label='Herbalist', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:MEMORY'}},
    {id='fisherdwarf', label='Fisherdwarf', attributes={'physical:AGILITY', 'mental:FOCUS', 'physical:STRENGTH', 'mental:PATIENCE', 'mental:KINESTHETIC_SENSE'}},
    {id='furnace_operator', label='Furnace operator', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:TOUGHNESS', 'mental:ANALYTICAL_ABILITY', 'physical:ENDURANCE'}},
    {id='strand_extractor', label='Strand extractor', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:STRENGTH', 'mental:ANALYTICAL_ABILITY', 'physical:ENDURANCE'}},
    {id='weaponsmith', label='Weaponsmith', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:CREATIVITY'}},
    {id='armorsmith', label='Armorsmith', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:CREATIVITY'}},
    {id='blacksmith', label='Blacksmith', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:CREATIVITY'}},
    {id='gem_cutter', label='Gem cutter', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:ANALYTICAL_ABILITY'}},
    {id='gem_setter', label='Gem setter', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:CREATIVITY'}},
    {id='wood_crafter', label='Wood crafter', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:CREATIVITY'}},
    {id='stone_crafter', label='Stone crafter', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:CREATIVITY'}},
    {id='metal_crafter', label='Metal crafter', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:CREATIVITY'}},
    {id='glassmaker', label='Glassmaker', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:CREATIVITY'}},
    {id='leatherworker', label='Leatherworker', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:CREATIVITY'}},
    {id='bone_carver', label='Bone carver', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:CREATIVITY'}},
    {id='axeman', label='Axeman', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:WILLPOWER', 'physical:TOUGHNESS', 'mental:SPATIAL_SENSE'}},
    {id='swordsman', label='Swordsman', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:WILLPOWER', 'physical:TOUGHNESS', 'mental:SPATIAL_SENSE'}},
    {id='knife_user', label='Knife user', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:STRENGTH', 'mental:WILLPOWER', 'physical:TOUGHNESS', 'mental:SPATIAL_SENSE'}},
    {id='maceman', label='Maceman', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:WILLPOWER', 'physical:TOUGHNESS', 'mental:SPATIAL_SENSE'}},
    {id='hammerman', label='Hammerman', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:WILLPOWER', 'physical:TOUGHNESS', 'mental:SPATIAL_SENSE'}},
    {id='spearman', label='Spearman', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:WILLPOWER', 'physical:TOUGHNESS', 'mental:SPATIAL_SENSE'}},
    {id='crossbowman', label='Crossbowman', attributes={'physical:AGILITY', 'mental:SPATIAL_SENSE', 'mental:KINESTHETIC_SENSE', 'mental:FOCUS'}},
    {id='shield_user', label='Shield user', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:WILLPOWER', 'physical:TOUGHNESS', 'mental:SPATIAL_SENSE'}},
    {id='armor_user', label='Armor user', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:TOUGHNESS', 'mental:WILLPOWER', 'physical:ENDURANCE'}},
    {id='siege_engineer', label='Siege engineer', attributes={'physical:STRENGTH', 'mental:ANALYTICAL_ABILITY', 'physical:AGILITY', 'mental:CREATIVITY', 'physical:ENDURANCE', 'mental:SPATIAL_SENSE'}},
    {id='siege_operator', label='Siege operator', attributes={'physical:STRENGTH', 'mental:SPATIAL_SENSE', 'physical:TOUGHNESS', 'mental:ANALYTICAL_ABILITY', 'physical:ENDURANCE', 'mental:FOCUS'}},
    {id='bowyer', label='Bowyer', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:CREATIVITY'}},
    {id='pikeman', label='Pikeman', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:WILLPOWER', 'physical:TOUGHNESS', 'mental:SPATIAL_SENSE'}},
    {id='lasher', label='Lasher', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:STRENGTH', 'mental:WILLPOWER', 'physical:TOUGHNESS', 'mental:SPATIAL_SENSE'}},
    {id='bowman', label='Bowman', attributes={'physical:AGILITY', 'mental:SPATIAL_SENSE', 'mental:KINESTHETIC_SENSE', 'mental:FOCUS'}},
    {id='blowgunner', label='Blowgunner', attributes={'physical:AGILITY', 'mental:SPATIAL_SENSE', 'mental:KINESTHETIC_SENSE', 'mental:FOCUS'}},
    {id='thrower', label='Thrower', attributes={'physical:STRENGTH', 'mental:SPATIAL_SENSE', 'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:TOUGHNESS', 'mental:WILLPOWER'}},
    {id='mechanic', label='Mechanic', attributes={'physical:AGILITY', 'mental:ANALYTICAL_ABILITY', 'physical:STRENGTH', 'mental:CREATIVITY', 'physical:ENDURANCE', 'mental:SPATIAL_SENSE'}},
    {id='druid', label='Druid', attributes={'physical:ENDURANCE', 'mental:EMPATHY', 'physical:AGILITY', 'mental:WILLPOWER', 'physical:TOUGHNESS', 'mental:FOCUS'}},
    {id='ambusher', label='Ambusher', attributes={'physical:AGILITY', 'mental:SPATIAL_SENSE', 'mental:KINESTHETIC_SENSE', 'mental:FOCUS'}},
    {id='wound_dresser', label='Wound dresser', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:EMPATHY'}},
    {id='diagnostician', label='Diagnostician', attributes={'mental:ANALYTICAL_ABILITY', 'mental:MEMORY', 'mental:INTUITION'}},
    {id='surgeon', label='Surgeon', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:FOCUS'}},
    {id='bone_doctor', label='Bone doctor', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:STRENGTH', 'mental:SPATIAL_SENSE', 'mental:FOCUS'}},
    {id='suturer', label='Suturer', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:FOCUS'}},
    {id='crutch_walker', label='Crutch-walker', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:ENDURANCE', 'mental:SPATIAL_SENSE', 'mental:WILLPOWER'}},
    {id='wood_burner', label='Wood burner', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:TOUGHNESS', 'physical:ENDURANCE'}},
    {id='lye_maker', label='Lye maker', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:TOUGHNESS', 'physical:ENDURANCE'}},
    {id='soaper', label='Soaper', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:TOUGHNESS', 'physical:ENDURANCE'}},
    {id='potash_maker', label='Potash maker', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:TOUGHNESS', 'physical:ENDURANCE'}},
    {id='dyer', label='Dyer', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'physical:ENDURANCE'}},
    {id='pump_operator', label='Pump operator', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:TOUGHNESS', 'mental:WILLPOWER', 'physical:ENDURANCE'}},
    {id='swimmer', label='Swimmer', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:WILLPOWER'}},
    {id='persuader', label='Persuader', attributes={'mental:LINGUISTIC_ABILITY', 'mental:SOCIAL_AWARENESS', 'mental:EMPATHY'}},
    {id='negotiator', label='Negotiator', attributes={'mental:LINGUISTIC_ABILITY', 'mental:SOCIAL_AWARENESS', 'mental:EMPATHY'}},
    {id='judge_of_intent', label='Judge of intent', attributes={'mental:EMPATHY', 'mental:SOCIAL_AWARENESS', 'mental:INTUITION'}},
    {id='appraiser', label='Appraiser', attributes={'mental:ANALYTICAL_ABILITY', 'mental:MEMORY', 'mental:INTUITION'}},
    {id='organizer', label='Organizer', attributes={'mental:ANALYTICAL_ABILITY', 'mental:SOCIAL_AWARENESS', 'mental:CREATIVITY'}},
    {id='record_keeper', label='Record keeper', attributes={'mental:ANALYTICAL_ABILITY', 'mental:MEMORY', 'mental:FOCUS'}},
    {id='liar', label='Liar', attributes={'mental:LINGUISTIC_ABILITY', 'mental:SOCIAL_AWARENESS', 'mental:CREATIVITY'}},
    {id='intimidator', label='Intimidator', attributes={'physical:STRENGTH', 'mental:LINGUISTIC_ABILITY', 'physical:AGILITY', 'mental:KINESTHETIC_SENSE'}},
    {id='conversationalist', label='Conversationalist', attributes={'mental:LINGUISTIC_ABILITY', 'mental:SOCIAL_AWARENESS', 'mental:EMPATHY'}},
    {id='comedian', label='Comedian', attributes={'physical:AGILITY', 'mental:LINGUISTIC_ABILITY', 'mental:CREATIVITY', 'mental:KINESTHETIC_SENSE'}},
    {id='flatterer', label='Flatterer', attributes={'mental:LINGUISTIC_ABILITY', 'mental:SOCIAL_AWARENESS', 'mental:EMPATHY'}},
    {id='consoler', label='Consoler', attributes={'mental:EMPATHY', 'mental:LINGUISTIC_ABILITY', 'mental:SOCIAL_AWARENESS'}},
    {id='pacifier', label='Pacifier', attributes={'mental:LINGUISTIC_ABILITY', 'mental:SOCIAL_AWARENESS', 'mental:EMPATHY'}},
    {id='tracker', label='Tracker', attributes={'mental:ANALYTICAL_ABILITY', 'mental:INTUITION', 'mental:SPATIAL_SENSE'}},
    {id='student', label='Student', attributes={'mental:MEMORY', 'mental:ANALYTICAL_ABILITY', 'mental:FOCUS'}},
    {id='concentration', label='Concentration', attributes={'mental:FOCUS', 'mental:PATIENCE', 'mental:WILLPOWER'}},
    {id='discipline', label='Discipline', attributes={'mental:WILLPOWER', 'mental:FOCUS'}},
    {id='observer', label='Observer', attributes={'mental:SPATIAL_SENSE', 'mental:FOCUS', 'mental:INTUITION'}},
    {id='wordsmith', label='Wordsmith', attributes={'mental:LINGUISTIC_ABILITY', 'mental:CREATIVITY', 'mental:INTUITION'}},
    {id='writer', label='Writer', attributes={'mental:LINGUISTIC_ABILITY', 'mental:CREATIVITY', 'mental:INTUITION'}},
    {id='poet', label='Poet', attributes={'mental:LINGUISTIC_ABILITY', 'mental:CREATIVITY', 'mental:INTUITION'}},
    {id='reader', label='Reader', attributes={'mental:LINGUISTIC_ABILITY', 'mental:FOCUS', 'mental:MEMORY'}},
    {id='speaker', label='Speaker', attributes={'mental:LINGUISTIC_ABILITY', 'mental:SOCIAL_AWARENESS', 'mental:EMPATHY'}},
    {id='coordination', label='Coordination', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE'}},
    {id='balance', label='Balance', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:STRENGTH'}},
    {id='leader', label='Leader', attributes={'mental:EMPATHY', 'mental:SOCIAL_AWARENESS', 'mental:LINGUISTIC_ABILITY'}},
    {id='teacher', label='Teacher', attributes={'mental:EMPATHY', 'mental:SOCIAL_AWARENESS', 'mental:LINGUISTIC_ABILITY'}},
    {id='fighter', label='Fighter', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:STRENGTH', 'mental:SPATIAL_SENSE', 'physical:TOUGHNESS', 'mental:WILLPOWER'}},
    {id='archer', label='Archer', attributes={'physical:AGILITY', 'mental:SPATIAL_SENSE', 'mental:KINESTHETIC_SENSE', 'mental:FOCUS'}},
    {id='wrestler', label='Wrestler', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:WILLPOWER'}},
    {id='biter', label='Biter', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:TOUGHNESS', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:WILLPOWER'}},
    {id='striker', label='Striker', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:TOUGHNESS', 'mental:WILLPOWER'}},
    {id='kicker', label='Kicker', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:TOUGHNESS', 'mental:WILLPOWER'}},
    {id='dodger', label='Dodger', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:TOUGHNESS', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:WILLPOWER'}},
    {id='misc_object_user', label='Misc. object user', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:TOUGHNESS', 'mental:WILLPOWER'}},
    {id='knapper', label='Knapper', attributes={'physical:AGILITY', 'mental:SPATIAL_SENSE', 'physical:STRENGTH', 'mental:ANALYTICAL_ABILITY', 'mental:KINESTHETIC_SENSE'}},
    {id='tactician', label='Tactician', attributes={'mental:ANALYTICAL_ABILITY', 'mental:CREATIVITY', 'mental:INTUITION'}},
    {id='shearer', label='Shearer', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:STRENGTH', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE'}},
    {id='spinner', label='Spinner', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:STRENGTH', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE'}},
    {id='potter', label='Potter', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:CREATIVITY'}},
    {id='glazer', label='Glazer', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:CREATIVITY'}},
    {id='presser', label='Presser', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'physical:ENDURANCE'}},
    {id='beekeeper', label='Beekeeper', attributes={'physical:AGILITY', 'mental:ANALYTICAL_ABILITY', 'physical:STRENGTH', 'mental:SPATIAL_SENSE', 'physical:ENDURANCE', 'mental:KINESTHETIC_SENSE'}},
    {id='wax_worker', label='Wax worker', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:SPATIAL_SENSE', 'mental:CREATIVITY'}},
    {id='climber', label='Climber', attributes={'physical:ENDURANCE', 'mental:KINESTHETIC_SENSE', 'physical:STRENGTH', 'mental:SPATIAL_SENSE', 'physical:AGILITY', 'mental:WILLPOWER'}},
    {id='gelder', label='Gelder', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'physical:ENDURANCE'}},
    {id='dancer', label='Dancer', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:ENDURANCE', 'mental:SPATIAL_SENSE', 'physical:STRENGTH', 'mental:MUSICALITY'}},
    {id='musician', label='Musician', attributes={'mental:MUSICALITY', 'mental:CREATIVITY', 'mental:FOCUS'}},
    {id='singer', label='Singer', attributes={'mental:MUSICALITY', 'mental:CREATIVITY', 'mental:FOCUS'}},
    {id='keyboardist', label='Keyboardist', attributes={'physical:AGILITY', 'mental:MUSICALITY', 'mental:CREATIVITY', 'mental:FOCUS'}},
    {id='stringed_instrumentalist', label='Stringed instrumentalist', attributes={'physical:AGILITY', 'mental:MUSICALITY', 'mental:CREATIVITY', 'mental:FOCUS'}},
    {id='wind_instrumentalist', label='Wind instrumentalist', attributes={'physical:AGILITY', 'mental:MUSICALITY', 'physical:ENDURANCE', 'mental:CREATIVITY', 'mental:FOCUS'}},
    {id='percussionist', label='Percussionist', attributes={'physical:AGILITY', 'mental:MUSICALITY', 'physical:ENDURANCE', 'mental:CREATIVITY', 'physical:STRENGTH', 'mental:FOCUS'}},
    {id='critical_thinker', label='Critical thinker', attributes={'mental:ANALYTICAL_ABILITY'}},
    {id='logician', label='Logician', attributes={'mental:ANALYTICAL_ABILITY'}},
    {id='mathematician', label='Mathematician', attributes={'mental:ANALYTICAL_ABILITY', 'mental:SPATIAL_SENSE', 'mental:MEMORY'}},
    {id='astronomer', label='Astronomer', attributes={'mental:ANALYTICAL_ABILITY', 'mental:SPATIAL_SENSE', 'mental:MEMORY'}},
    {id='chemist', label='Chemist', attributes={'mental:ANALYTICAL_ABILITY', 'mental:FOCUS', 'mental:MEMORY'}},
    {id='geographer', label='Geographer', attributes={'mental:SPATIAL_SENSE', 'mental:ANALYTICAL_ABILITY', 'mental:MEMORY'}},
    {id='optics_engineer', label='Optics engineer', attributes={'mental:SPATIAL_SENSE', 'mental:ANALYTICAL_ABILITY', 'mental:FOCUS'}},
    {id='fluid_engineer', label='Fluid engineer', attributes={'mental:SPATIAL_SENSE', 'mental:ANALYTICAL_ABILITY', 'mental:FOCUS'}},
    {id='papermaker', label='Papermaker', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE'}},
    {id='bookbinder', label='Bookbinder', attributes={'physical:AGILITY', 'mental:SPATIAL_SENSE', 'mental:KINESTHETIC_SENSE'}},
    {id='schemer', label='Schemer', attributes={'mental:SOCIAL_AWARENESS', 'mental:INTUITION', 'mental:CREATIVITY'}},
    {id='rider', label='Rider', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'mental:EMPATHY', 'mental:WILLPOWER'}},
    {id='stonecutter', label='Stonecutter', attributes={'physical:STRENGTH', 'mental:KINESTHETIC_SENSE', 'physical:AGILITY', 'mental:SPATIAL_SENSE', 'mental:PATIENCE'}},
    {id='stone_carver', label='Stone carver', attributes={'physical:AGILITY', 'mental:KINESTHETIC_SENSE', 'physical:STRENGTH', 'mental:SPATIAL_SENSE', 'mental:CREATIVITY'}},
}

---@param attributes string[]
---@return SoulSearchSelectedFilter[]
local function build_filters(attributes)
    local filters = {}
    for _, id in ipairs(attributes) do
        table.insert(filters, {
            id=id,
            direction=filter_constants.direction.HIGH,
        })
    end
    return filters
end

---@param filters SoulSearchSelectedFilter[]
---@return SoulSearchSelectedFilter[]
local function copy_filters(filters)
    local copy = {}
    for _, filter in ipairs(filters) do
        table.insert(copy, {id=filter.id, direction=filter.direction})
    end
    return copy
end

---@return SoulSearchBuiltInFilterPreset[]
function get_all()
    local presets = {}
    for _, row in ipairs(WIKI_ROWS) do
        table.insert(presets, {
            id=row.id,
            label=row.label,
            filters=build_filters(row.attributes),
        })
    end
    return presets
end

---@param id string
---@return SoulSearchSelectedFilter[]|nil
function get(id)
    for _, row in ipairs(WIKI_ROWS) do
        if row.id == id then
            return build_filters(row.attributes)
        end
    end
    return nil
end
