local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local attributes = soulsearch_env.load_attributes(repo_root)

    local attribute_cases = {
        {
            name='physical above race median',
            kind='physical_attribute', key='STRENGTH', value=1500,
            unit={race=1}, baseline=1250, deviation=250, tier_distance=1,
        },
        {
            name='physical at race median',
            kind='physical_attribute', key='STRENGTH', value=1250,
            unit={race=1}, baseline=1250, deviation=0, tier_distance=0,
        },
        {
            name='physical below race median',
            kind='physical_attribute', key='STRENGTH', value=1000,
            unit={race=1}, baseline=1250, deviation=-250, tier_distance=1,
        },
        {
            name='mental above race median',
            kind='mental_attribute', key='FOCUS', value=1150,
            unit={race=1}, baseline=900, deviation=250, tier_distance=1,
        },
        {
            name='mental at race median',
            kind='mental_attribute', key='FOCUS', value=900,
            unit={race=1}, baseline=900, deviation=0, tier_distance=0,
        },
        {
            name='mental below race median',
            kind='mental_attribute', key='FOCUS', value=650,
            unit={race=1}, baseline=900, deviation=-250, tier_distance=1,
        },
    }

    for _, case in ipairs(attribute_cases) do
        add_test('attributes: ' .. case.name, function()
            local evaluation = attributes.evaluate(
                case.kind, case.key, case.value, case.unit)
            luaunit.assertIs(case.baseline, evaluation.baseline)
            luaunit.assertIs(case.deviation, evaluation.deviation)
            luaunit.assertIs(case.tier_distance, evaluation.tier_distance)
        end)
    end

    local tier_cases = {
        {name='positive inside neutral tier', value=1499, expected=0},
        {name='positive tier boundary', value=1500, expected=1},
        {name='negative inside neutral tier', value=1001, expected=0},
        {name='negative tier boundary', value=1000, expected=1},
        {name='second positive tier boundary', value=1750, expected=2},
        {name='second negative tier boundary', value=750, expected=2},
    }
    for _, case in ipairs(tier_cases) do
        add_test('attributes tier: ' .. case.name, function()
            local evaluation = attributes.evaluate(
                'physical_attribute', 'STRENGTH', case.value, {race=1})
            luaunit.assertIs(case.expected, evaluation.tier_distance)
        end)
    end

    add_test('traits: caste-aware baseline and tier distance', function()
        local unit = {trait_baselines={PATIENCE=60}}
        local evaluation = attributes.evaluate('trait', 'PATIENCE', 82, unit)
        luaunit.assertIs(60, evaluation.baseline)
        luaunit.assertIs(22, evaluation.deviation)
        luaunit.assertIs(2, evaluation.tier_distance)
        luaunit.assertIs(40, evaluation.high_score_scale)
        luaunit.assertIs(60, evaluation.low_score_scale)
    end)

    add_test('traits: default baseline fallback', function()
        local evaluation = attributes.evaluate('trait', 'PATIENCE', 40, {})
        luaunit.assertIs(50, evaluation.baseline)
        luaunit.assertIs(-10, evaluation.deviation)
        luaunit.assertIs(1, evaluation.tier_distance)
    end)

    local skill_cases = {
        {name='absent skill', value=0, high=false, low=true, high_score=0, low_score=1},
        {name='dabbling/progress skill', value=1.5, high=true, low=false, high_score=1.5 / 21, low_score=0},
        {name='high skill clamps score', value=25, high=true, low=false, high_score=1, low_score=0},
    }
    for _, case in ipairs(skill_cases) do
        add_test('skills: ' .. case.name, function()
            local evaluation = attributes.evaluate('skill', 'MINING', case.value, {})
            luaunit.assertIs(case.high, attributes.matches_direction(evaluation, 'high'))
            luaunit.assertIs(case.low, attributes.matches_direction(evaluation, 'low'))
            luaunit.assertAlmostEquals(case.high_score, attributes.score_direction(evaluation, 'high'))
            luaunit.assertAlmostEquals(case.low_score, attributes.score_direction(evaluation, 'low'))
        end)
    end

    local direction_cases = {
        {name='physical high', kind='physical_attribute', key='STRENGTH', value=1500, unit={race=1}, direction='high', expected=true},
        {name='physical low', kind='physical_attribute', key='STRENGTH', value=1000, unit={race=1}, direction='low', expected=true},
        {name='mental high', kind='mental_attribute', key='FOCUS', value=1150, unit={race=1}, direction='high', expected=true},
        {name='mental low', kind='mental_attribute', key='FOCUS', value=650, unit={race=1}, direction='low', expected=true},
        {name='trait high', kind='trait', key='PATIENCE', value=70, unit={}, direction='high', expected=true},
        {name='trait low', kind='trait', key='PATIENCE', value=30, unit={}, direction='low', expected=true},
        {name='neutral does not match high', kind='physical_attribute', key='STRENGTH', value=1250, unit={race=1}, direction='high', expected=false},
        {name='neutral does not match low', kind='physical_attribute', key='STRENGTH', value=1250, unit={race=1}, direction='low', expected=false},
    }
    for _, case in ipairs(direction_cases) do
        add_test('directions: ' .. case.name, function()
            local evaluation = attributes.evaluate(
                case.kind, case.key, case.value, case.unit)
            luaunit.assertIs(
                case.expected,
                attributes.matches_direction(evaluation, case.direction))
        end)
    end

    add_test('scores: physical high and low clamp to one', function()
        local high = attributes.evaluate(
            'physical_attribute', 'AGILITY', 7000, {race=1})
        local low = attributes.evaluate(
            'physical_attribute', 'AGILITY', -5000, {race=1})
        luaunit.assertIs(1, attributes.score_direction(high, 'high'))
        luaunit.assertIs(1, attributes.score_direction(low, 'low'))
    end)

    add_test('scores: missing values do not evaluate or match', function()
        luaunit.assertNil(attributes.evaluate('trait', 'PATIENCE', nil, {}))
        luaunit.assertEvalToFalse(attributes.matches_direction(nil, 'high'))
        luaunit.assertIs(0, attributes.score_direction(nil, 'low'))
    end)

return native_tests
