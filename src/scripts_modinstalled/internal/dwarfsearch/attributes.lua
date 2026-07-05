--@ module=true

local personality = reqscript('modtools/set-personality')

local FILTER_LOW = 'low'
local DEFAULT_TRAIT_BASELINE = 50
local DEFAULT_ATTRIBUTE_BASELINE = 1000
local ATTRIBUTE_TIER_WIDTH = 250
local ATTRIBUTE_SCORE_SCALE = 5000

local median_cache = {}

local function split_colon(text)
    local parts = {}
    for part in tostring(text):gmatch('[^:]+') do
        table.insert(parts, part)
    end
    return parts
end

local function get_attribute_tier(value, baseline)
    local delta = value - baseline
    if delta >= 0 then
        return math.floor(delta / ATTRIBUTE_TIER_WIDTH)
    end
    return -math.floor(math.abs(delta) / ATTRIBUTE_TIER_WIDTH)
end

local function set_attribute_median(medians, kind, raw_value)
    local parts = split_colon(raw_value)
    local key = parts[2]
    if not key then
        return
    end
    medians[kind][key] = tonumber(parts[6]) or medians[kind][key]
end

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
            value=value,
            baseline=baseline,
            deviation=deviation,
            tier_distance=math.abs(value_tier - baseline_tier),
            high_score_scale=math.max(100 - baseline, 1),
            low_score_scale=math.max(baseline, 1),
        }
    end

    local race_id = unit and unit.race
    local medians = get_race_medians(race_id)
    local baseline = medians[kind] and medians[kind][key] or DEFAULT_ATTRIBUTE_BASELINE
    local deviation = value - baseline
    return {
        value=value,
        baseline=baseline,
        deviation=deviation,
        tier_distance=math.abs(get_attribute_tier(value, baseline)),
        high_score_scale=ATTRIBUTE_SCORE_SCALE,
        low_score_scale=ATTRIBUTE_SCORE_SCALE,
    }
end

function matches_direction(evaluation, direction)
    if not evaluation then
        return false
    end
    if direction == FILTER_LOW then
        return evaluation.deviation < 0
    end
    return evaluation.deviation > 0
end

function score_direction(evaluation, direction)
    if not matches_direction(evaluation, direction) then
        return 0
    end

    local magnitude = evaluation.deviation
    local score_scale = evaluation.high_score_scale
    if direction == FILTER_LOW then
        magnitude = -magnitude
        score_scale = evaluation.low_score_scale
    end

    return math.min(magnitude / math.max(score_scale or 1, 1), 1)
end
