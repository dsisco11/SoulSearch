--@ module=true

local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

---@class SoulSearchBuiltInFilterPreset
---@field id string
---@field label string
---@field filters SoulSearchSelectedFilter[]

-- Source: https://dwarffortresswiki.org/index.php/Attribute
-- Generated from the wiki's current Skills by associated attributes table.
-- Each marks string has one character for each attribute below: A is primary,
-- followed by B and C secondary priorities.
local ATTRIBUTE_IDS = {
    'physical_attribute:STRENGTH',
    'physical_attribute:AGILITY',
    'physical_attribute:TOUGHNESS',
    'physical_attribute:ENDURANCE',
    'mental_attribute:ANALYTICAL_ABILITY',
    'mental_attribute:FOCUS',
    'mental_attribute:WILLPOWER',
    'mental_attribute:CREATIVITY',
    'mental_attribute:INTUITION',
    'mental_attribute:PATIENCE',
    'mental_attribute:MEMORY',
    'mental_attribute:LINGUISTIC_ABILITY',
    'mental_attribute:SPATIAL_SENSE',
    'mental_attribute:MUSICALITY',
    'mental_attribute:KINESTHETIC_SENSE',
    'mental_attribute:EMPATHY',
    'mental_attribute:SOCIAL_AWARENESS',
}

---@type {label: string, marks: string}[]
local WIKI_ROWS = {
{label='Miner', marks='A.BC..C.....B.A..'},
    {label='Wood cutter', marks='AB.C..C.....B.A..'},
    {label='Carpenter', marks='AB.....C....B.A..'},
    {label='Engraver', marks='.A.....C....B.A..'},
    {label='Mason', marks='AB.C...C....B.A..'},
    {label='Animal trainer', marks='.ABC....CB.....A.'},
    {label='Animal caretaker', marks='.A..A.....B....C.'},
    {label='Fish dissector', marks='.A............A..'},
    {label='Animal dissector', marks='.A............A..'},
    {label='Fish cleaner', marks='.A.B..........A..'},
    {label='Butcher', marks='AB.C..........A..'},
    {label='Trapper', marks='.A..A..B....C....'},
    {label='Tanner', marks='.A............A..'},
    {label='Weaver', marks='.A.....C....B.A..'},
    {label='Brewer', marks='AB............A..'},
    {label='Clothier', marks='.A.....C....B.A..'},
    {label='Miller', marks='AB.C..........A..'},
    {label='Thresher', marks='BA.C..........A..'},
    {label='Cheese maker', marks='BA.CB..C......A..'},
    {label='Milker', marks='AB.C..........A..'},
    {label='Cook', marks='.A..B..C......A..'},
    {label='Planter', marks='AB.C..........A..'},
    {label='Herbalist', marks='.A........B...A..'},
    {label='Fisherdwarf', marks='BA...A...B....C..'},
    {label='Furnace operator', marks='A.BCB.........A..'},
    {label='Strand extractor', marks='BA.CB.........A..'},
    {label='Weaponsmith', marks='AB.C...C....B.A..'},
    {label='Armorsmith', marks='AB.C...C....B.A..'},
    {label='Blacksmith', marks='AB.C...C....B.A..'},
    {label='Gem cutter', marks='.A..C.......B.A..'},
    {label='Gem setter', marks='.A.....C....B.A..'},
    {label='Wood crafter', marks='.A.....C....B.A..'},
    {label='Stone crafter', marks='.A.....C....B.A..'},
    {label='Metal crafter', marks='AB.C...C....B.A..'},
    {label='Glassmaker', marks='AB.C...C....B.A..'},
    {label='Leatherworker', marks='AB.C...C....B.A..'},
    {label='Bone carver', marks='.A.....C....B.A..'},
    {label='Axeman', marks='ABC...B.....C.A..'},
    {label='Swordsman', marks='ABC...B.....C.A..'},
    {label='Knife user', marks='BAC...B.....C.A..'},
    {label='Maceman', marks='ABC...B.....C.A..'},
    {label='Hammerman', marks='ABC...B.....C.A..'},
    {label='Spearman', marks='ABC...B.....C.A..'},
    {label='Crossbowman', marks='.A...C......A.B..'},
    {label='Shield user', marks='ABC...B.....C.A..'},
    {label='Armor user', marks='A.BC..B.......A..'},
    {label='Siege engineer', marks='AB.CA..B....C....'},
    {label='Siege operator', marks='A.BCBC......A....'},
    {label='Bowyer', marks='.A.....C....B.A..'},
    {label='Pikeman', marks='ABC...B.....C.A..'},
    {label='Lasher', marks='BAC...B.....C.A..'},
    {label='Bowman', marks='.A...C......A.B..'},
    {label='Blowgunner', marks='.A...C......A.B..'},
    {label='Thrower', marks='ABC...C.....A.B..'},
    {label='Mechanic', marks='BA.CA..B....C....'},
    {label='Druid', marks='.BCA.CB........A.'},
    {label='Ambusher', marks='.A...C......A.B..'},
    {label='Wound dresser', marks='.A..........B.AC.'},
    {label='Diagnostician', marks='....A...C.B......'},
    {label='Surgeon', marks='.A...C......B.A..'},
    {label='Bone doctor', marks='BA...C......B.A..'},
    {label='Suturer', marks='.A...C......B.A..'},
    {label='Crutch-walker', marks='.A.B..C.....B.A..'},
    {label='Wood burner', marks='A.BC..........A..'},
    {label='Lye maker', marks='A.BC..........A..'},
    {label='Soaper', marks='A.BC..........A..'},
    {label='Potash maker', marks='A.BC..........A..'},
    {label='Dyer', marks='AB.C..........A..'},
    {label='Pump operator', marks='A.BC..B.......A..'},
    {label='Swimmer', marks='AB.C..C.....B.A..'},
    {label='Persuader', marks='...........A...CB'},
    {label='Negotiator', marks='...........A...CB'},
    {label='Judge of intent', marks='........C......AB'},
    {label='Appraiser', marks='....A...C.B......'},
    {label='Organizer', marks='....A..C........B'},
    {label='Record keeper', marks='....AC....B......'},
    {label='Liar', marks='.......C...A....B'},
    {label='Intimidator', marks='AB.........A..B..'},
    {label='Conversationalist', marks='...........A...CB'},
    {label='Comedian', marks='.A.....B...A..C..'},
    {label='Flatterer', marks='...........A...CB'},
    {label='Consoler', marks='...........B...AC'},
    {label='Pacifier', marks='...........A...CB'},
    {label='Tracker', marks='....A...B...C....'},
    {label='Student', marks='....BC....A......'},
    {label='Concentration', marks='.....AC..B.......'},
    {label='Discipline', marks='.....BA..........'},
    {label='Observer', marks='.....B..C...A....'},
    {label='Wordsmith', marks='.......BC..A.....'},
    {label='Writer', marks='.......BC..A.....'},
    {label='Poet', marks='.......BC..A.....'},
    {label='Reader', marks='.....B....CA.....'},
    {label='Speaker', marks='...........A...CB'},
    {label='Coordination', marks='.A..........B.A..'},
    {label='Balance', marks='BA............A..'},
    {label='Leader', marks='...........C...AB'},
    {label='Teacher', marks='...........C...AB'},
    {label='Fighter', marks='BAC...C.....B.A..'},
    {label='Archer', marks='.A...C......A.B..'},
    {label='Wrestler', marks='AB.C..C.....B.A..'},
    {label='Biter', marks='A.BC..C.....B.A..'},
    {label='Striker', marks='ABC...C.....B.A..'},
    {label='Kicker', marks='ABC...C.....B.A..'},
    {label='Dodger', marks='.ABC..C.....B.A..'},
    {label='Misc. object user', marks='ABC...C.....B.A..'},
    {label='Knapper', marks='BA..B.......A.C..'},
    {label='Tactician', marks='....A..BC........'},
    {label='Shearer', marks='BA.C........B.A..'},
    {label='Spinner', marks='BA.C........B.A..'},
    {label='Potter', marks='.A.....C....B.A..'},
    {label='Glazer', marks='.A.....C....B.A..'},
    {label='Presser', marks='AB.C..........A..'},
    {label='Beekeeper', marks='BA.CA.......B.C..'},
    {label='Wax worker', marks='.A.....C....B.A..'},
    {label='Climber', marks='BC.A..C.....B.A..'},
    {label='Gelder', marks='AB.C..........A..'},
    {label='Dancer', marks='CA.B........BCA..'},
    {label='Musician', marks='.....C.B.....A...'},
    {label='Singer', marks='.....C.B.....A...'},
    {label='Keyboardist', marks='.A...C.B.....A...'},
    {label='Stringed instrumentalist', marks='.A...C.B.....A...'},
    {label='Wind instrumentalist', marks='.A.B.C.B.....A...'},
    {label='Percussionist', marks='CA.B.C.B.....A...'},
    {label='Critical thinker', marks='....A............'},
    {label='Logician', marks='....A............'},
    {label='Mathematician', marks='....A.....C.B....'},
    {label='Astronomer', marks='....A.....C.B....'},
    {label='Chemist', marks='....AB....C......'},
    {label='Geographer', marks='....B.....C.A....'},
    {label='Optics engineer', marks='....BC......A....'},
    {label='Fluid engineer', marks='....BC......A....'},
    {label='Papermaker', marks='AB..........B.A..'},
    {label='Bookbinder', marks='.A..........A.B..'},
    {label='Schemer', marks='.......CB.......A'},
    {label='Rider', marks='.A....C.......AB.'},
    {label='Stonecutter', marks='AB.......C..B.A..'},
    {label='Stone carver', marks='BA.....C....B.A..'},
}

---@param label string
---@return string
local function get_id(label)
    return (label:lower():gsub('[^%w]+', '_'):gsub('^_', ''):gsub('_$', ''))
end

---@param marks string
---@return SoulSearchSelectedFilter[]
local function build_filters(marks)
    local filters = {}
    for _, priority in ipairs({'A', 'B', 'C'}) do
        for index, filter_id in ipairs(ATTRIBUTE_IDS) do
            if marks:sub(index, index) == priority then
        table.insert(filters, {
            id=filter_id,
            direction=filter_constants.direction.HIGH,
        })
            end
        end
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
            id=get_id(row.label),
            label=row.label,
            filters=build_filters(row.marks),
        })
    end
    return presets
end

---@param id string
---@return SoulSearchSelectedFilter[]|nil
function get(id)
    for _, row in ipairs(WIKI_ROWS) do
        if get_id(row.label) == id then
            return build_filters(row.marks)
        end
    end
    return nil
end
