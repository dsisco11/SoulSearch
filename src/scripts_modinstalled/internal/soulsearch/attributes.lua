--@ module=true

---@alias SoulSearchStatKind 'trait'|'skill'|'physical_attribute'|'mental_attribute'
---@alias SoulSearchFilterDirection 'high'|'low'

---@class SoulSearchAttributeMedians
---@field physical_attribute table<string, number>
---@field mental_attribute table<string, number>

---@class SoulSearchEvaluation
---@field kind SoulSearchStatKind
---@field value number
---@field baseline number
---@field deviation number
---@field tier_distance number
---@field high_score_scale number
---@field low_score_scale number

local personality = reqscript('modtools/set-personality')

local FILTER_LOW = 'low'
local DEFAULT_TRAIT_BASELINE = 50
local DEFAULT_ATTRIBUTE_BASELINE = 1000
local ATTRIBUTE_TIER_WIDTH = 250
local ATTRIBUTE_SCORE_SCALE = 5000
local SKILL_SCORE_SCALE = 21

local median_cache = {}

---@param text any
---@return string[]
local function split_colon(text)
    local parts = {}
    for part in tostring(text):gmatch('[^:]+') do
        table.insert(parts, part)
    end
    return parts
end

---@param value number
---@param baseline number
---@return integer
local function get_attribute_tier(value, baseline)
    local delta = value - baseline
    if delta >= 0 then
        return math.floor(delta / ATTRIBUTE_TIER_WIDTH)
    end
    return -math.floor(math.abs(delta) / ATTRIBUTE_TIER_WIDTH)
end

---@param medians SoulSearchAttributeMedians
---@param kind 'physical_attribute'|'mental_attribute'
---@param raw_value string
local function set_attribute_median(medians, kind, raw_value)
    -- Supported DF 0.53 creature raws encode seven percentile values after the
    -- attribute key. The fourth numeric value (split field 6) is the documented
    -- median; vanilla dwarven STRENGTH, for example, is 1250.
    local parts = split_colon(raw_value)
    local key = parts[2]
    if not key then
        return
    end
    medians[kind][key] = tonumber(parts[6]) or medians[kind][key]
end

---Clears race median data between world/module lifecycle generations. Callers
---own the boundary and must not reset during an evaluation/search pass.
function reset_cache()
    median_cache = {}
end

---Gets physical and mental attribute medians for a creature race.
---@param race_id integer|nil
---@return SoulSearchAttributeMedians
function get_race_medians(race_id)
    local cache_key = race_id or false
    if median_cache[cache_key] then
        return median_cache[cache_key]
    end

    local medians = {
        physical_attribute={},
        mental_attribute={},
    }

    for _, name in ipairs(df.physical_attribute_type) do
        medians.physical_attribute[name] = DEFAULT_ATTRIBUTE_BASELINE
    end
    for _, name in ipairs(df.mental_attribute_type) do
        medians.mental_attribute[name] = DEFAULT_ATTRIBUTE_BASELINE
    end

    local creature = race_id and df.global.world.raws.creatures.all[race_id]
    if creature then
        for _, raw in ipairs(creature.raws) do
            local raw_value = raw.value or ''
            if raw_value:match('PHYS_ATT_RANGE') then
                set_attribute_median(medians, 'physical_attribute', raw_value)
            elseif raw_value:match('MENT_ATT_RANGE') then
                set_attribute_median(medians, 'mental_attribute', raw_value)
            end
        end
    end

    median_cache[cache_key] = medians
    return medians
end

---Gets the race/caste-aware neutral value for a personality trait.
---@param unit df.unit|nil
---@param key string
---@return number
function get_trait_baseline(unit, key)
    if not unit then
        return DEFAULT_TRAIT_BASELINE
    end

    local ok, range = pcall(personality.getUnitCasteTraitRange, unit, key)
    if ok and range and range.mid then
        return range.mid
    end
    return DEFAULT_TRAIT_BASELINE
end

---Compares a stat value against the appropriate neutral baseline.
---@param kind SoulSearchStatKind
---@param key string
---@param value number|nil
---@param unit df.unit|nil
---@return SoulSearchEvaluation|nil
function evaluate(kind, key, value, unit)
    if type(value) ~= 'number' then
        return nil
    end

    if kind == 'trait' then
        local baseline = get_trait_baseline(unit, key)
        local deviation = value - baseline
        local baseline_tier = personality.getTraitTier(baseline)
        local value_tier = personality.getTraitTier(value)
        return {
            kind=kind,
            value=value,
            baseline=baseline,
            deviation=deviation,
            tier_distance=math.abs(value_tier - baseline_tier),
            high_score_scale=math.max(100 - baseline, 1),
            low_score_scale=math.max(baseline, 1),
        }
    end

    if kind == 'skill' then
        return {
            kind=kind,
            value=value,
            baseline=0,
            deviation=value,
            tier_distance=value,
            high_score_scale=SKILL_SCORE_SCALE,
            low_score_scale=1,
        }
    end

    local race_id = unit and unit.race
    local medians = get_race_medians(race_id)
    local baseline = medians[kind] and medians[kind][key] or DEFAULT_ATTRIBUTE_BASELINE
    local deviation = value - baseline
    return {
        kind=kind,
        value=value,
        baseline=baseline,
        deviation=deviation,
        tier_distance=math.abs(get_attribute_tier(value, baseline)),
        high_score_scale=ATTRIBUTE_SCORE_SCALE,
        low_score_scale=ATTRIBUTE_SCORE_SCALE,
    }
end

---Checks whether an evaluated value satisfies a high/low filter direction.
---@param evaluation SoulSearchEvaluation|nil
---@param direction SoulSearchFilterDirection
---@return boolean
function matches_direction(evaluation, direction)
    if not evaluation then
        return false
    end
    if evaluation.kind == 'skill' then
        if direction == FILTER_LOW then
            return evaluation.value <= 0
        end
        return evaluation.value > 0
    end
    if direction == FILTER_LOW then
        return evaluation.deviation < 0
    end
    return evaluation.deviation > 0
end

---Scores how strongly an evaluated value satisfies a high/low direction.
---@param evaluation SoulSearchEvaluation|nil
---@param direction SoulSearchFilterDirection
---@return number
function score_direction(evaluation, direction)
    if not matches_direction(evaluation, direction) then
        return 0
    end

    if evaluation.kind == 'skill' then
        if direction == FILTER_LOW then
            return 1
        end
        return math.min(evaluation.value / SKILL_SCORE_SCALE, 1)
    end

    local magnitude = evaluation.deviation
    local score_scale = evaluation.high_score_scale
    if direction == FILTER_LOW then
        magnitude = -magnitude
        score_scale = evaluation.low_score_scale
    end

    return math.min(magnitude / math.max(score_scale or 1, 1), 1)
end
