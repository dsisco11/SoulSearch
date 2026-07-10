local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
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
        test.case('attributes: ' .. case.name, function()
            local evaluation = attributes.evaluate(
                case.kind, case.key, case.value, case.unit)
            test.assert_equal(case.baseline, evaluation.baseline)
            test.assert_equal(case.deviation, evaluation.deviation)
            test.assert_equal(case.tier_distance, evaluation.tier_distance)
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
        test.case('attributes tier: ' .. case.name, function()
            local evaluation = attributes.evaluate(
                'physical_attribute', 'STRENGTH', case.value, {race=1})
            test.assert_equal(case.expected, evaluation.tier_distance)
        end)
    end

    test.case('traits: caste-aware baseline and tier distance', function()
        local unit = {trait_baselines={PATIENCE=60}}
        local evaluation = attributes.evaluate('trait', 'PATIENCE', 82, unit)
        test.assert_equal(60, evaluation.baseline)
        test.assert_equal(22, evaluation.deviation)
        test.assert_equal(2, evaluation.tier_distance)
        test.assert_equal(40, evaluation.high_score_scale)
        test.assert_equal(60, evaluation.low_score_scale)
    end)

    test.case('traits: default baseline fallback', function()
        local evaluation = attributes.evaluate('trait', 'PATIENCE', 40, {})
        test.assert_equal(50, evaluation.baseline)
        test.assert_equal(-10, evaluation.deviation)
        test.assert_equal(1, evaluation.tier_distance)
    end)

    local skill_cases = {
        {name='absent skill', value=0, high=false, low=true, high_score=0, low_score=1},
        {name='dabbling/progress skill', value=1.5, high=true, low=false, high_score=1.5 / 21, low_score=0},
        {name='high skill clamps score', value=25, high=true, low=false, high_score=1, low_score=0},
    }
    for _, case in ipairs(skill_cases) do
        test.case('skills: ' .. case.name, function()
            local evaluation = attributes.evaluate('skill', 'MINING', case.value, {})
            test.assert_equal(case.high, attributes.matches_direction(evaluation, 'high'))
            test.assert_equal(case.low, attributes.matches_direction(evaluation, 'low'))
            test.assert_near(case.high_score, attributes.score_direction(evaluation, 'high'))
            test.assert_near(case.low_score, attributes.score_direction(evaluation, 'low'))
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
        test.case('directions: ' .. case.name, function()
            local evaluation = attributes.evaluate(
                case.kind, case.key, case.value, case.unit)
            test.assert_equal(
                case.expected,
                attributes.matches_direction(evaluation, case.direction))
        end)
    end

    test.case('scores: physical high and low clamp to one', function()
        local high = attributes.evaluate(
            'physical_attribute', 'AGILITY', 7000, {race=1})
        local low = attributes.evaluate(
            'physical_attribute', 'AGILITY', -5000, {race=1})
        test.assert_equal(1, attributes.score_direction(high, 'high'))
        test.assert_equal(1, attributes.score_direction(low, 'low'))
    end)

    test.case('scores: missing values do not evaluate or match', function()
        test.assert_nil(attributes.evaluate('trait', 'PATIENCE', nil, {}))
        test.assert_false(attributes.matches_direction(nil, 'high'))
        test.assert_equal(0, attributes.score_direction(nil, 'low'))
    end)
end
