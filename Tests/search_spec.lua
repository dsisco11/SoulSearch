local soulsearch_env = require('support.soulsearch_env')

local function selected_filter(kind, key, direction)
    return {
        id=kind .. ':' .. key,
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

local repo_root = require('support.repo_root')

describe('search', function()

    local attributes = soulsearch_env.load_attributes(repo_root)
    local search = soulsearch_env.load_search(repo_root, attributes)

    local function result_for_order(overrides)
        local result = {
            matched_count=1,
            weighted_score=10,
            score=1,
            name='Beta',
            profession='Peasant',
            unit_id=2,
        }
        for key, value in pairs(overrides or {}) do
            result[key] = value
        end
        return result
    end

    local comparator_cases = {
        {
            name='matched count',
            left={matched_count=2},
            right={matched_count=1},
        },
        {
            name='weighted score',
            left={weighted_score=11},
            right={weighted_score=10},
        },
        {
            name='raw score',
            left={score=2},
            right={score=1},
        },
        {
            name='resident name',
            left={name='Alpha'},
            right={name='Beta'},
        },
        {
            name='unit ID',
            left={unit_id=1},
            right={unit_id=2},
        },
    }
    for _, case in ipairs(comparator_cases) do
        it('result comparator: ' .. case.name, function()
            local left = result_for_order(case.left)
            local right = result_for_order(case.right)
            assert.is_truthy(search.compare_results(left, right))
            assert.is_falsy(search.compare_results(right, left))
        end)
    end

    it('result comparator: equal values do not reorder', function()
        local left = result_for_order()
        local right = result_for_order()
        assert.is_falsy(search.compare_results(left, right))
        assert.is_falsy(search.compare_results(right, left))
    end)

    it('search filters: validates entries and keeps first valid duplicate', function()
        local filters = {
            false,
            {id='skill:UNKNOWN', direction='high'},
            {id='skill:MINING', direction='sideways'},
            {id='skill:MINING', direction='high'},
            {id='skill:MINING', direction='low'},
            {id='skill:SWIMMING', direction='low'},
        }
        local row = resident(1, 'Miner', {skills={MINING=2}})
        local result = search.apply({row}, {selected_filters=filters})[1]
        assert.are.equal(2, result.matched_count)
        assert.are.equal(2, #result.filter_criteria)
        assert.are.equal('skill:MINING', result.filter_criteria[1].id)
        assert.are.equal('high', result.filter_criteria[1].direction)
        assert.are.equal('skill:SWIMMING', result.filter_criteria[2].id)
        assert.are.equal('low', result.filter_criteria[2].direction)
        assert.are.equal('high', filters[4].direction)
        assert.are.equal('low', filters[5].direction)
    end)

    it('result column sort: uses the selected column then relevance', function()
        local results = {
            result_for_order{unit_id=7, name='Beta', profession='Miner'},
            result_for_order{unit_id=3, name='Alpha', profession='Peasant'},
            result_for_order{
                unit_id=4, name='Alpha', profession='Woodworker', matched_count=2},
        }
        search.sort_results(results, 'name', false)
        assert.are.same({4, 3, 7},
            {results[1].unit_id, results[2].unit_id, results[3].unit_id})

        search.sort_results(results, 'unit_id', true)
        assert.are.same({7, 4, 3},
            {results[1].unit_id, results[2].unit_id, results[3].unit_id})

        search.sort_results(results, 'profession', false)
        assert.are.same({'Miner', 'Peasant', 'Woodworker'},
            {results[1].profession, results[2].profession, results[3].profession})
    end)

    it('search filters: candidate descriptors are ignored by the ranker', function()
        local result = search.apply({resident(1, 'Miner', {skills={MINING=2}})}, {
            selected_filters={
                selected_filter('race:group', 'HUMANOIDS'),
                selected_filter('skill', 'MINING'),
            },
        })[1]
        assert.are.equal(1, result.matched_count)
        assert.are.equal(1, #result.filter_criteria)
        assert.are.equal('skill:MINING', result.filter_criteria[1].id)
    end)

    it('result model: contains only consumed presentation and sort data', function()
        local result = search.apply({resident(1, 'Urist')}, {
            selected_filters={},
        })[1]
        assert.is_truthy(result.row ~= nil)
        assert.is_truthy(result.unit ~= nil)
        assert.are.equal(0, result.matched_count)
        assert.are.equal(0, result.score)
        assert.are.equal(0, result.weighted_score)
        assert.is_nil(result.matched_criteria)
        assert.is_nil(result.criteria_count)
        assert.is_nil(result.match_label)
    end)

    it('search query: empty includes all and uses name then unit ID', function()
        local rows = {
            resident(3, 'Beta'),
            resident(2, 'Alpha'),
            resident(1, 'Alpha'),
        }
        local results = search.apply(rows, {query='', selected_filters={}})
        assert.are.same({'Alpha', 'Alpha', 'Beta'}, result_names(results))
        assert.are.equal(1, results[1].unit_id)
        assert.are.equal(2, results[2].unit_id)
    end)

    local query_cases = {
        {name='matching query', query='Urist', expected={'Urist McMiner'}},
        {name='case-insensitive query', query='urist', expected={'Urist McMiner'}},
        {name='nonmatching query', query='Zon', expected={}},
    }
    for _, case in ipairs(query_cases) do
        it('search query: ' .. case.name, function()
            local rows = {
                resident(1, 'Urist McMiner'),
                resident(2, 'Domas Smith'),
            }
            local results = search.apply(rows, {
                query=case.query,
                selected_filters={},
            })
            assert.are.same(case.expected, result_names(results))
        end)
    end

    it('ranking: full and partial matches remain in results', function()
        local filters = {
            selected_filter('physical_attribute', 'STRENGTH'),
            selected_filter('physical_attribute', 'AGILITY'),
        }
        local rows = {
            resident(1, 'No Match', {physical_attributes={STRENGTH=500, AGILITY=500}}),
            resident(2, 'Partial Match', {physical_attributes={STRENGTH=1500, AGILITY=500}}),
            resident(3, 'Full Match', {physical_attributes={STRENGTH=1500, AGILITY=1500}}),
        }
        local results = search.apply(rows, {selected_filters=filters})
        assert.are.same(
            {'Full Match', 'Partial Match', 'No Match'},
            result_names(results))
        assert.are.equal(2, results[1].matched_count)
        assert.are.equal(1, results[2].matched_count)
        assert.are.equal(0, results[3].matched_count)
        assert.are.equal(3, #results)
    end)

    it('ranking: earlier selected filter receives priority bonus', function()
        local filters = {
            selected_filter('physical_attribute', 'STRENGTH'),
            selected_filter('physical_attribute', 'AGILITY'),
        }
        local rows = {
            resident(1, 'Second Priority', {physical_attributes={STRENGTH=500, AGILITY=1500}}),
            resident(2, 'First Priority', {physical_attributes={STRENGTH=1500, AGILITY=500}}),
        }
        local results = search.apply(rows, {selected_filters=filters})
        assert.are.same(
            {'First Priority', 'Second Priority'},
            result_names(results))
        assert.are.equal(results[1].matched_count, results[2].matched_count)
        assert.near(results[1].score, results[2].score, 2^-52)
        assert.is_truthy(results[1].weighted_score > results[2].weighted_score)
    end)

    it('ranking: raw score breaks an exact weighted-score tie', function()
        local filters = {
            selected_filter('physical_attribute', 'STRENGTH'),
            selected_filter('physical_attribute', 'AGILITY'),
        }
        local rows = {
            resident(1, 'Alpha Lower Raw', {physical_attributes={STRENGTH=1600, AGILITY=1050}}),
            resident(2, 'Zulu Higher Raw', {physical_attributes={STRENGTH=1050, AGILITY=1650}}),
        }
        local results = search.apply(rows, {selected_filters=filters})
        assert.are.equal(results[1].matched_count, results[2].matched_count)
        assert.are.equal(results[1].weighted_score, results[2].weighted_score)
        assert.is_truthy(results[1].score > results[2].score)
        assert.are.same(
            {'Zulu Higher Raw', 'Alpha Lower Raw'},
            result_names(results))
    end)

    it('ranking: name breaks complete score tie', function()
        local filter = selected_filter('physical_attribute', 'STRENGTH')
        local rows = {
            resident(1, 'Zulu', {physical_attributes={STRENGTH=1500}}),
            resident(2, 'Alpha', {physical_attributes={STRENGTH=1500}}),
        }
        local results = search.apply(rows, {selected_filters={filter}})
        assert.are.same({'Alpha', 'Zulu'}, result_names(results))
    end)

    it('ranking: unit ID breaks complete score and name tie', function()
        local filter = selected_filter('physical_attribute', 'STRENGTH')
        local rows = {
            resident(20, 'Urist', {physical_attributes={STRENGTH=1500}}),
            resident(10, 'Urist', {physical_attributes={STRENGTH=1500}}),
        }
        local results = search.apply(rows, {selected_filters={filter}})
        assert.are.equal(10, results[1].unit_id)
        assert.are.equal(20, results[2].unit_id)
    end)

    it('ranking: mixed stat kinds evaluate together', function()
        local filters = {
            selected_filter('trait', 'PATIENCE', 'high'),
            selected_filter('mental_attribute', 'FOCUS', 'low'),
            selected_filter('physical_attribute', 'STRENGTH', 'high'),
            selected_filter('skill', 'MINING', 'high'),
        }
        local row = resident(1, 'Mixed Match', {
            race=1,
            unit={race=1, trait_baselines={PATIENCE=50}},
            traits={PATIENCE=70},
            mental_attributes={FOCUS=650},
            physical_attributes={STRENGTH=1500},
            skills={MINING=1.5},
        })
        local result = search.apply({row}, {selected_filters=filters})[1]
        assert.are.equal(4, result.matched_count)
        assert.are.equal(4, #result.filter_criteria)
    end)

    it('ranking: missing trait is omitted and absent skill supports low', function()
        local filters = {
            selected_filter('trait', 'PATIENCE', 'high'),
            selected_filter('skill', 'MINING', 'low'),
        }
        local result = search.apply(
            {resident(1, 'No Soul Stats')},
            {selected_filters=filters})[1]
        assert.are.equal(1, result.matched_count)
        assert.are.equal(1, #result.filter_criteria)
        assert.are.equal('skill', result.filter_criteria[1].kind)
        assert.is_truthy(result.filter_criteria[1].matched)
    end)

end)