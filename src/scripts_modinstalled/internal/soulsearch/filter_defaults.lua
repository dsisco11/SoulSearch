--@ module=true

---@class SoulSearchBuiltInFilterPreset
---@field id string
---@field label string
---@field filters SoulSearchSelectedFilter[]

local HIGH = 'high'

---@param id string
---@return SoulSearchSelectedFilter
local function high(id)
    return {id=id, direction=HIGH}
end

---@type SoulSearchBuiltInFilterPreset[]
local PRESETS = {
    -- Source: https://dwarffortresswiki.org/index.php/Attributes
    -- The wiki's Skills by associated attributes table labels primary
    -- attributes A, then secondary attributes B and C. Ordering follows that
    -- priority so SoulSearch's ranked results use the same importance order.
    {
        id='miner', label='Miner',
        filters={
            high('physical_attribute:STRENGTH'),
            high('mental_attribute:KINESTHETIC_SENSE'),
            high('physical_attribute:TOUGHNESS'),
            high('mental_attribute:SPATIAL_SENSE'),
            high('physical_attribute:ENDURANCE'),
            high('mental_attribute:WILLPOWER'),
        },
    },
    {
        id='marksdwarf', label='Marksdwarf',
        -- Crossbowman: Agility and Spatial Sense A; Kinesthetic Sense B;
        -- Focus C. The current game calls this military role a marksdwarf.
        filters={
            high('physical_attribute:AGILITY'),
            high('mental_attribute:SPATIAL_SENSE'),
            high('mental_attribute:KINESTHETIC_SENSE'),
            high('mental_attribute:FOCUS'),
        },
    },
    {
        id='scholar', label='Scholar',
        -- Critical Thinker and Logician are Analytical Ability A. The
        -- Mathematician row adds Memory B and Intuition C.
        filters={
            high('mental_attribute:ANALYTICAL_ABILITY'),
            high('mental_attribute:MEMORY'),
            high('mental_attribute:INTUITION'),
        },
    },
    {
        id='sheriff', label='Sheriff',
        -- Sheriff is a law-enforcement role rather than a skill-table row, so
        -- this uses Fighter: Agility, Spatial Sense, and Kinesthetic Sense A;
        -- Strength and Willpower B; Toughness and Endurance C.
        filters={
            high('physical_attribute:AGILITY'),
            high('mental_attribute:SPATIAL_SENSE'),
            high('mental_attribute:KINESTHETIC_SENSE'),
            high('physical_attribute:STRENGTH'),
            high('mental_attribute:WILLPOWER'),
            high('physical_attribute:TOUGHNESS'),
            high('physical_attribute:ENDURANCE'),
        },
    },
    {
        id='manager', label='Manager',
        -- Organizer: Analytical Ability A, Memory B, Intuition C.
        filters={
            high('mental_attribute:ANALYTICAL_ABILITY'),
            high('mental_attribute:MEMORY'),
            high('mental_attribute:INTUITION'),
        },
    },
}

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
    local copy = {}
    for _, preset in ipairs(PRESETS) do
        table.insert(copy, {
            id=preset.id,
            label=preset.label,
            filters=copy_filters(preset.filters),
        })
    end
    return copy
end

---@param id string
---@return SoulSearchSelectedFilter[]|nil
function get(id)
    for _, preset in ipairs(PRESETS) do
        if preset.id == id then return copy_filters(preset.filters) end
    end
    return nil
end
