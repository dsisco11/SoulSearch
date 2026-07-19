local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('attributes', function()

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
        it('attributes: ' .. case.name, function()
            local evaluation = attributes.evaluate(
                case.kind, case.key, case.value, case.unit)
            assert.are.equal(case.baseline, evaluation.baseline)
            assert.are.equal(case.deviation, evaluation.deviation)
            assert.are.equal(case.tier_distance, evaluation.tier_distance)
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
        it('attributes tier: ' .. case.name, function()
            local evaluation = attributes.evaluate(
                'physical_attribute', 'STRENGTH', case.value, {race=1})
            assert.are.equal(case.expected, evaluation.tier_distance)
        end)
    end

    it('traits: caste-aware baseline and tier distance', function()
        local unit = {trait_baselines={PATIENCE=60}}
        local evaluation = attributes.evaluate('trait', 'PATIENCE', 82, unit)
        assert.are.equal(60, evaluation.baseline)
        assert.are.equal(22, evaluation.deviation)
        assert.are.equal(2, evaluation.tier_distance)
        assert.are.equal(40, evaluation.high_score_scale)
        assert.are.equal(60, evaluation.low_score_scale)
    end)

    it('traits: default baseline fallback', function()
        local evaluation = attributes.evaluate('trait', 'PATIENCE', 40, {})
        assert.are.equal(50, evaluation.baseline)
        assert.are.equal(-10, evaluation.deviation)
        assert.are.equal(1, evaluation.tier_distance)
    end)

    local skill_cases = {
        {name='absent skill', value=0, high=false, low=true, high_score=0, low_score=1},
        {name='dabbling/progress skill', value=1.5, high=true, low=false, high_score=1.5 / 21, low_score=0},
        {name='high skill clamps score', value=25, high=true, low=false, high_score=1, low_score=0},
    }
    for _, case in ipairs(skill_cases) do
        it('skills: ' .. case.name, function()
            local evaluation = attributes.evaluate('skill', 'MINING', case.value, {})
            assert.are.equal(case.high, attributes.matches_direction(evaluation, 'high'))
            assert.are.equal(case.low, attributes.matches_direction(evaluation, 'low'))
            assert.near(case.high_score, attributes.score_direction(evaluation, 'high'), 2^-52)
            assert.near(case.low_score, attributes.score_direction(evaluation, 'low'), 2^-52)
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
        it('directions: ' .. case.name, function()
            local evaluation = attributes.evaluate(
                case.kind, case.key, case.value, case.unit)
            assert.are.equal(
                case.expected,
                attributes.matches_direction(evaluation, case.direction))
        end)
    end

    it('scores: physical high and low clamp to one', function()
        local high = attributes.evaluate(
            'physical_attribute', 'AGILITY', 7000, {race=1})
        local low = attributes.evaluate(
            'physical_attribute', 'AGILITY', -5000, {race=1})
        assert.are.equal(1, attributes.score_direction(high, 'high'))
        assert.are.equal(1, attributes.score_direction(low, 'low'))
    end)

    it('scores: missing values do not evaluate or match', function()
        assert.is_nil(attributes.evaluate('trait', 'PATIENCE', nil, {}))
        assert.is_falsy(attributes.matches_direction(nil, 'high'))
        assert.are.equal(0, attributes.score_direction(nil, 'low'))
    end)

end)