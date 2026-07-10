local soulsearch_env = require('support.soulsearch_env')

local function descriptor(kind, key, direction)
    return {
        id=kind .. ':' .. key,
        kind=kind,
        key=key,
        label=key,
        direction=direction or 'high',
    }
end

local function resident(id, name, values)
    values = values or {}
    return {
        unit=values.unit or {race=values.race},
        unit_id=id,
        name=name,
        profession=values.profession or 'Peasant',
        traits=values.traits or {},
        mental_attributes=values.mental_attributes or {},
        physical_attributes=values.physical_attributes or {},
        skills=values.skills or {},
    }
end

local function result_names(results)
    local names = {}
    for _, result in ipairs(results) do
        table.insert(names, result.name)
    end
    return names
end

return function(test, repo_root)
    local attributes = soulsearch_env.load_attributes(repo_root)
    local search = soulsearch_env.load_search(repo_root, attributes)

    test.case('search query: empty includes all and uses name then unit ID', function()
        local rows = {
            resident(3, 'Beta'),
            resident(2, 'Alpha'),
            resident(1, 'Alpha'),
        }
        local results = search.apply(rows, {query='', selected_descriptors={}})
        test.assert_sequence({'Alpha', 'Alpha', 'Beta'}, result_names(results))
        test.assert_equal(1, results[1].unit_id)
        test.assert_equal(2, results[2].unit_id)
    end)

    local query_cases = {
        {name='matching query', query='Urist', expected={'Urist McMiner'}},
        {name='case-insensitive query', query='urist', expected={'Urist McMiner'}},
        {name='nonmatching query', query='Zon', expected={}},
    }
    for _, case in ipairs(query_cases) do
        test.case('search query: ' .. case.name, function()
            local rows = {
                resident(1, 'Urist McMiner'),
                resident(2, 'Domas Smith'),
            }
            local results = search.apply(rows, {
                query=case.query,
                selected_descriptors={},
            })
            test.assert_sequence(case.expected, result_names(results))
        end)
    end

    test.case('ranking: full and partial matches remain in results', function()
        local filters = {
            descriptor('physical_attribute', 'STRENGTH'),
            descriptor('physical_attribute', 'AGILITY'),
        }
        local rows = {
            resident(1, 'No Match', {physical_attributes={STRENGTH=500, AGILITY=500}}),
            resident(2, 'Partial Match', {physical_attributes={STRENGTH=1500, AGILITY=500}}),
            resident(3, 'Full Match', {physical_attributes={STRENGTH=1500, AGILITY=1500}}),
        }
        local results = search.apply(rows, {selected_descriptors=filters})
        test.assert_sequence(
            {'Full Match', 'Partial Match', 'No Match'},
            result_names(results))
        test.assert_equal(2, results[1].matched_count)
        test.assert_equal(1, results[2].matched_count)
        test.assert_equal(0, results[3].matched_count)
        test.assert_equal(3, #results)
    end)

    test.case('ranking: earlier selected filter receives priority bonus', function()
        local filters = {
            descriptor('physical_attribute', 'STRENGTH'),
            descriptor('physical_attribute', 'AGILITY'),
        }
        local rows = {
            resident(1, 'Second Priority', {physical_attributes={STRENGTH=500, AGILITY=1500}}),
            resident(2, 'First Priority', {physical_attributes={STRENGTH=1500, AGILITY=500}}),
        }
        local results = search.apply(rows, {selected_descriptors=filters})
        test.assert_sequence(
            {'First Priority', 'Second Priority'},
            result_names(results))
        test.assert_equal(results[1].matched_count, results[2].matched_count)
        test.assert_near(results[1].score, results[2].score)
        test.assert_true(results[1].weighted_score > results[2].weighted_score)
    end)

    test.case('ranking: raw score breaks an exact weighted-score tie', function()
        local filters = {
            descriptor('physical_attribute', 'STRENGTH'),
            descriptor('physical_attribute', 'AGILITY'),
        }
        local rows = {
            resident(1, 'Alpha Lower Raw', {physical_attributes={STRENGTH=1600, AGILITY=1050}}),
            resident(2, 'Zulu Higher Raw', {physical_attributes={STRENGTH=1050, AGILITY=1650}}),
        }
        local results = search.apply(rows, {selected_descriptors=filters})
        test.assert_equal(results[1].matched_count, results[2].matched_count)
        test.assert_equal(results[1].weighted_score, results[2].weighted_score)
        test.assert_true(results[1].score > results[2].score)
        test.assert_sequence(
            {'Zulu Higher Raw', 'Alpha Lower Raw'},
            result_names(results))
    end)

    test.case('ranking: name breaks complete score tie', function()
        local filter = descriptor('physical_attribute', 'STRENGTH')
        local rows = {
            resident(1, 'Zulu', {physical_attributes={STRENGTH=1500}}),
            resident(2, 'Alpha', {physical_attributes={STRENGTH=1500}}),
        }
        local results = search.apply(rows, {selected_descriptors={filter}})
        test.assert_sequence({'Alpha', 'Zulu'}, result_names(results))
    end)

    test.case('ranking: unit ID breaks complete score and name tie', function()
        local filter = descriptor('physical_attribute', 'STRENGTH')
        local rows = {
            resident(20, 'Urist', {physical_attributes={STRENGTH=1500}}),
            resident(10, 'Urist', {physical_attributes={STRENGTH=1500}}),
        }
        local results = search.apply(rows, {selected_descriptors={filter}})
        test.assert_equal(10, results[1].unit_id)
        test.assert_equal(20, results[2].unit_id)
    end)

    test.case('ranking: mixed stat kinds evaluate together', function()
        local filters = {
            descriptor('trait', 'PATIENCE', 'high'),
            descriptor('mental_attribute', 'FOCUS', 'low'),
            descriptor('physical_attribute', 'STRENGTH', 'high'),
            descriptor('skill', 'MINING', 'high'),
        }
        local row = resident(1, 'Mixed Match', {
            race=1,
            unit={race=1, trait_baselines={PATIENCE=50}},
            traits={PATIENCE=70},
            mental_attributes={FOCUS=650},
            physical_attributes={STRENGTH=1500},
            skills={MINING=1.5},
        })
        local result = search.apply({row}, {selected_descriptors=filters})[1]
        test.assert_equal(4, result.matched_count)
        test.assert_equal(4, #result.filter_criteria)
    end)

    test.case('ranking: missing trait is omitted and absent skill supports low', function()
        local filters = {
            descriptor('trait', 'PATIENCE', 'high'),
            descriptor('skill', 'MINING', 'low'),
        }
        local result = search.apply(
            {resident(1, 'No Soul Stats')},
            {selected_descriptors=filters})[1]
        test.assert_equal(1, result.matched_count)
        test.assert_equal(1, #result.filter_criteria)
        test.assert_equal('skill', result.filter_criteria[1].kind)
        test.assert_true(result.filter_criteria[1].matched)
    end)
end
