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
---@type {id: string, label: string, attributes: string[]}[]
local WIKI_ROWS = {
    {id='miner', label='Miner', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:TOUGHNESS', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:WILLPOWER'}},
    {id='wood_cutter', label='Wood cutter', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:WILLPOWER'}},
    {id='carpenter', label='Carpenter', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:CREATIVITY'}},
    {id='engraver', label='Engraver', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:CREATIVITY'}},
    {id='mason', label='Mason', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:CREATIVITY'}},
    {id='animal_trainer', label='Animal trainer', attributes={'physical_attribute:AGILITY', 'mental_attribute:EMPATHY', 'physical_attribute:TOUGHNESS', 'mental_attribute:PATIENCE', 'physical_attribute:ENDURANCE', 'mental_attribute:INTUITION'}},
    {id='animal_caretaker', label='Animal caretaker', attributes={'physical_attribute:AGILITY', 'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:MEMORY', 'mental_attribute:EMPATHY'}},
    {id='fish_dissector', label='Fish dissector', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE'}},
    {id='animal_dissector', label='Animal dissector', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE'}},
    {id='fish_cleaner', label='Fish cleaner', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:ENDURANCE'}},
    {id='butcher', label='Butcher', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'physical_attribute:ENDURANCE'}},
    {id='trapper', label='Trapper', attributes={'physical_attribute:AGILITY', 'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:CREATIVITY', 'mental_attribute:SPATIAL_SENSE'}},
    {id='tanner', label='Tanner', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE'}},
    {id='weaver', label='Weaver', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:CREATIVITY'}},
    {id='brewer', label='Brewer', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY'}},
    {id='clothier', label='Clothier', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:CREATIVITY'}},
    {id='miller', label='Miller', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'physical_attribute:ENDURANCE'}},
    {id='thresher', label='Thresher', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH', 'physical_attribute:ENDURANCE'}},
    {id='cheese_maker', label='Cheese maker', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:ANALYTICAL_ABILITY', 'physical_attribute:ENDURANCE', 'mental_attribute:CREATIVITY'}},
    {id='milker', label='Milker', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'physical_attribute:ENDURANCE'}},
    {id='cook', label='Cook', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:CREATIVITY'}},
    {id='planter', label='Planter', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'physical_attribute:ENDURANCE'}},
    {id='herbalist', label='Herbalist', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:MEMORY'}},
    {id='fisherdwarf', label='Fisherdwarf', attributes={'physical_attribute:AGILITY', 'mental_attribute:FOCUS', 'physical_attribute:STRENGTH', 'mental_attribute:PATIENCE', 'mental_attribute:KINESTHETIC_SENSE'}},
    {id='furnace_operator', label='Furnace operator', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:TOUGHNESS', 'mental_attribute:ANALYTICAL_ABILITY', 'physical_attribute:ENDURANCE'}},
    {id='strand_extractor', label='Strand extractor', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:ANALYTICAL_ABILITY', 'physical_attribute:ENDURANCE'}},
    {id='weaponsmith', label='Weaponsmith', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:CREATIVITY'}},
    {id='armorsmith', label='Armorsmith', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:CREATIVITY'}},
    {id='blacksmith', label='Blacksmith', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:CREATIVITY'}},
    {id='gem_cutter', label='Gem cutter', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:ANALYTICAL_ABILITY'}},
    {id='gem_setter', label='Gem setter', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:CREATIVITY'}},
    {id='wood_crafter', label='Wood crafter', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:CREATIVITY'}},
    {id='stone_crafter', label='Stone crafter', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:CREATIVITY'}},
    {id='metal_crafter', label='Metal crafter', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:CREATIVITY'}},
    {id='glassmaker', label='Glassmaker', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:CREATIVITY'}},
    {id='leatherworker', label='Leatherworker', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:CREATIVITY'}},
    {id='bone_carver', label='Bone carver', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:CREATIVITY'}},
    {id='axeman', label='Axeman', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:WILLPOWER', 'physical_attribute:TOUGHNESS', 'mental_attribute:SPATIAL_SENSE'}},
    {id='swordsman', label='Swordsman', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:WILLPOWER', 'physical_attribute:TOUGHNESS', 'mental_attribute:SPATIAL_SENSE'}},
    {id='knife_user', label='Knife user', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:WILLPOWER', 'physical_attribute:TOUGHNESS', 'mental_attribute:SPATIAL_SENSE'}},
    {id='maceman', label='Maceman', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:WILLPOWER', 'physical_attribute:TOUGHNESS', 'mental_attribute:SPATIAL_SENSE'}},
    {id='hammerman', label='Hammerman', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:WILLPOWER', 'physical_attribute:TOUGHNESS', 'mental_attribute:SPATIAL_SENSE'}},
    {id='spearman', label='Spearman', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:WILLPOWER', 'physical_attribute:TOUGHNESS', 'mental_attribute:SPATIAL_SENSE'}},
    {id='crossbowman', label='Crossbowman', attributes={'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:FOCUS'}},
    {id='shield_user', label='Shield user', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:WILLPOWER', 'physical_attribute:TOUGHNESS', 'mental_attribute:SPATIAL_SENSE'}},
    {id='armor_user', label='Armor user', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:TOUGHNESS', 'mental_attribute:WILLPOWER', 'physical_attribute:ENDURANCE'}},
    {id='siege_engineer', label='Siege engineer', attributes={'physical_attribute:STRENGTH', 'mental_attribute:ANALYTICAL_ABILITY', 'physical_attribute:AGILITY', 'mental_attribute:CREATIVITY', 'physical_attribute:ENDURANCE', 'mental_attribute:SPATIAL_SENSE'}},
    {id='siege_operator', label='Siege operator', attributes={'physical_attribute:STRENGTH', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:TOUGHNESS', 'mental_attribute:ANALYTICAL_ABILITY', 'physical_attribute:ENDURANCE', 'mental_attribute:FOCUS'}},
    {id='bowyer', label='Bowyer', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:CREATIVITY'}},
    {id='pikeman', label='Pikeman', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:WILLPOWER', 'physical_attribute:TOUGHNESS', 'mental_attribute:SPATIAL_SENSE'}},
    {id='lasher', label='Lasher', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:WILLPOWER', 'physical_attribute:TOUGHNESS', 'mental_attribute:SPATIAL_SENSE'}},
    {id='bowman', label='Bowman', attributes={'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:FOCUS'}},
    {id='blowgunner', label='Blowgunner', attributes={'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:FOCUS'}},
    {id='thrower', label='Thrower', attributes={'physical_attribute:STRENGTH', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:TOUGHNESS', 'mental_attribute:WILLPOWER'}},
    {id='mechanic', label='Mechanic', attributes={'physical_attribute:AGILITY', 'mental_attribute:ANALYTICAL_ABILITY', 'physical_attribute:STRENGTH', 'mental_attribute:CREATIVITY', 'physical_attribute:ENDURANCE', 'mental_attribute:SPATIAL_SENSE'}},
    {id='druid', label='Druid', attributes={'physical_attribute:ENDURANCE', 'mental_attribute:EMPATHY', 'physical_attribute:AGILITY', 'mental_attribute:WILLPOWER', 'physical_attribute:TOUGHNESS', 'mental_attribute:FOCUS'}},
    {id='ambusher', label='Ambusher', attributes={'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:FOCUS'}},
    {id='wound_dresser', label='Wound dresser', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:EMPATHY'}},
    {id='diagnostician', label='Diagnostician', attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:MEMORY', 'mental_attribute:INTUITION'}},
    {id='surgeon', label='Surgeon', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:FOCUS'}},
    {id='bone_doctor', label='Bone doctor', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:FOCUS'}},
    {id='suturer', label='Suturer', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:FOCUS'}},
    {id='crutch_walker', label='Crutch-walker', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:WILLPOWER'}},
    {id='wood_burner', label='Wood burner', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:TOUGHNESS', 'physical_attribute:ENDURANCE'}},
    {id='lye_maker', label='Lye maker', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:TOUGHNESS', 'physical_attribute:ENDURANCE'}},
    {id='soaper', label='Soaper', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:TOUGHNESS', 'physical_attribute:ENDURANCE'}},
    {id='potash_maker', label='Potash maker', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:TOUGHNESS', 'physical_attribute:ENDURANCE'}},
    {id='dyer', label='Dyer', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'physical_attribute:ENDURANCE'}},
    {id='pump_operator', label='Pump operator', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:TOUGHNESS', 'mental_attribute:WILLPOWER', 'physical_attribute:ENDURANCE'}},
    {id='swimmer', label='Swimmer', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:WILLPOWER'}},
    {id='persuader', label='Persuader', attributes={'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:EMPATHY'}},
    {id='negotiator', label='Negotiator', attributes={'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:EMPATHY'}},
    {id='judge_of_intent', label='Judge of intent', attributes={'mental_attribute:EMPATHY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:INTUITION'}},
    {id='appraiser', label='Appraiser', attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:MEMORY', 'mental_attribute:INTUITION'}},
    {id='organizer', label='Organizer', attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:CREATIVITY'}},
    {id='record_keeper', label='Record keeper', attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:MEMORY', 'mental_attribute:FOCUS'}},
    {id='liar', label='Liar', attributes={'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:CREATIVITY'}},
    {id='intimidator', label='Intimidator', attributes={'physical_attribute:STRENGTH', 'mental_attribute:LINGUISTIC_ABILITY', 'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE'}},
    {id='conversationalist', label='Conversationalist', attributes={'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:EMPATHY'}},
    {id='comedian', label='Comedian', attributes={'physical_attribute:AGILITY', 'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:CREATIVITY', 'mental_attribute:KINESTHETIC_SENSE'}},
    {id='flatterer', label='Flatterer', attributes={'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:EMPATHY'}},
    {id='consoler', label='Consoler', attributes={'mental_attribute:EMPATHY', 'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:SOCIAL_AWARENESS'}},
    {id='pacifier', label='Pacifier', attributes={'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:EMPATHY'}},
    {id='tracker', label='Tracker', attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:INTUITION', 'mental_attribute:SPATIAL_SENSE'}},
    {id='student', label='Student', attributes={'mental_attribute:MEMORY', 'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:FOCUS'}},
    {id='concentration', label='Concentration', attributes={'mental_attribute:FOCUS', 'mental_attribute:PATIENCE', 'mental_attribute:WILLPOWER'}},
    {id='discipline', label='Discipline', attributes={'mental_attribute:WILLPOWER', 'mental_attribute:FOCUS'}},
    {id='observer', label='Observer', attributes={'mental_attribute:SPATIAL_SENSE', 'mental_attribute:FOCUS', 'mental_attribute:INTUITION'}},
    {id='wordsmith', label='Wordsmith', attributes={'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:CREATIVITY', 'mental_attribute:INTUITION'}},
    {id='writer', label='Writer', attributes={'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:CREATIVITY', 'mental_attribute:INTUITION'}},
    {id='poet', label='Poet', attributes={'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:CREATIVITY', 'mental_attribute:INTUITION'}},
    {id='reader', label='Reader', attributes={'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:FOCUS', 'mental_attribute:MEMORY'}},
    {id='speaker', label='Speaker', attributes={'mental_attribute:LINGUISTIC_ABILITY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:EMPATHY'}},
    {id='coordination', label='Coordination', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE'}},
    {id='balance', label='Balance', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH'}},
    {id='leader', label='Leader', attributes={'mental_attribute:EMPATHY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:LINGUISTIC_ABILITY'}},
    {id='teacher', label='Teacher', attributes={'mental_attribute:EMPATHY', 'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:LINGUISTIC_ABILITY'}},
    {id='fighter', label='Fighter', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:TOUGHNESS', 'mental_attribute:WILLPOWER'}},
    {id='archer', label='Archer', attributes={'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:FOCUS'}},
    {id='wrestler', label='Wrestler', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:WILLPOWER'}},
    {id='biter', label='Biter', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:TOUGHNESS', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:WILLPOWER'}},
    {id='striker', label='Striker', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:TOUGHNESS', 'mental_attribute:WILLPOWER'}},
    {id='kicker', label='Kicker', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:TOUGHNESS', 'mental_attribute:WILLPOWER'}},
    {id='dodger', label='Dodger', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:TOUGHNESS', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:WILLPOWER'}},
    {id='misc_object_user', label='Misc. object user', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:TOUGHNESS', 'mental_attribute:WILLPOWER'}},
    {id='knapper', label='Knapper', attributes={'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:KINESTHETIC_SENSE'}},
    {id='tactician', label='Tactician', attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:CREATIVITY', 'mental_attribute:INTUITION'}},
    {id='shearer', label='Shearer', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE'}},
    {id='spinner', label='Spinner', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE'}},
    {id='potter', label='Potter', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:CREATIVITY'}},
    {id='glazer', label='Glazer', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:CREATIVITY'}},
    {id='presser', label='Presser', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'physical_attribute:ENDURANCE'}},
    {id='beekeeper', label='Beekeeper', attributes={'physical_attribute:AGILITY', 'mental_attribute:ANALYTICAL_ABILITY', 'physical_attribute:STRENGTH', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:KINESTHETIC_SENSE'}},
    {id='wax_worker', label='Wax worker', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:CREATIVITY'}},
    {id='climber', label='Climber', attributes={'physical_attribute:ENDURANCE', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:WILLPOWER'}},
    {id='gelder', label='Gelder', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'physical_attribute:ENDURANCE'}},
    {id='dancer', label='Dancer', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:ENDURANCE', 'mental_attribute:SPATIAL_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:MUSICALITY'}},
    {id='musician', label='Musician', attributes={'mental_attribute:MUSICALITY', 'mental_attribute:CREATIVITY', 'mental_attribute:FOCUS'}},
    {id='singer', label='Singer', attributes={'mental_attribute:MUSICALITY', 'mental_attribute:CREATIVITY', 'mental_attribute:FOCUS'}},
    {id='keyboardist', label='Keyboardist', attributes={'physical_attribute:AGILITY', 'mental_attribute:MUSICALITY', 'mental_attribute:CREATIVITY', 'mental_attribute:FOCUS'}},
    {id='stringed_instrumentalist', label='Stringed instrumentalist', attributes={'physical_attribute:AGILITY', 'mental_attribute:MUSICALITY', 'mental_attribute:CREATIVITY', 'mental_attribute:FOCUS'}},
    {id='wind_instrumentalist', label='Wind instrumentalist', attributes={'physical_attribute:AGILITY', 'mental_attribute:MUSICALITY', 'physical_attribute:ENDURANCE', 'mental_attribute:CREATIVITY', 'mental_attribute:FOCUS'}},
    {id='percussionist', label='Percussionist', attributes={'physical_attribute:AGILITY', 'mental_attribute:MUSICALITY', 'physical_attribute:ENDURANCE', 'mental_attribute:CREATIVITY', 'physical_attribute:STRENGTH', 'mental_attribute:FOCUS'}},
    {id='critical_thinker', label='Critical thinker', attributes={'mental_attribute:ANALYTICAL_ABILITY'}},
    {id='logician', label='Logician', attributes={'mental_attribute:ANALYTICAL_ABILITY'}},
    {id='mathematician', label='Mathematician', attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:MEMORY'}},
    {id='astronomer', label='Astronomer', attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:MEMORY'}},
    {id='chemist', label='Chemist', attributes={'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:FOCUS', 'mental_attribute:MEMORY'}},
    {id='geographer', label='Geographer', attributes={'mental_attribute:SPATIAL_SENSE', 'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:MEMORY'}},
    {id='optics_engineer', label='Optics engineer', attributes={'mental_attribute:SPATIAL_SENSE', 'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:FOCUS'}},
    {id='fluid_engineer', label='Fluid engineer', attributes={'mental_attribute:SPATIAL_SENSE', 'mental_attribute:ANALYTICAL_ABILITY', 'mental_attribute:FOCUS'}},
    {id='papermaker', label='Papermaker', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE'}},
    {id='bookbinder', label='Bookbinder', attributes={'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:KINESTHETIC_SENSE'}},
    {id='schemer', label='Schemer', attributes={'mental_attribute:SOCIAL_AWARENESS', 'mental_attribute:INTUITION', 'mental_attribute:CREATIVITY'}},
    {id='rider', label='Rider', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:EMPATHY', 'mental_attribute:WILLPOWER'}},
    {id='stonecutter', label='Stonecutter', attributes={'physical_attribute:STRENGTH', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:PATIENCE'}},
    {id='stone_carver', label='Stone carver', attributes={'physical_attribute:AGILITY', 'mental_attribute:KINESTHETIC_SENSE', 'physical_attribute:STRENGTH', 'mental_attribute:SPATIAL_SENSE', 'mental_attribute:CREATIVITY'}},
}

---@param attributes string[]
---@return SoulSearchSelectedFilter[]
local function build_filters(attributes)
    local filters = {}
    for _, id in ipairs(attributes) do
        table.insert(filters, {id=id, direction=filter_constants.direction.HIGH})
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
