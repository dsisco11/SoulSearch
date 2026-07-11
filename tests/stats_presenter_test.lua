local soulsearch_env = require('support.soulsearch_env')

local function labels(records)
    local result = {}
    for _, record in ipairs(records) do table.insert(result, record.label) end
    return result
end

return function(test, repo_root)
    local fake_attributes = {
        evaluate=function(kind, key, value, unit)
            return {deviation=value, tier_distance=math.abs(value)}
        end,
    }
    local presenter = soulsearch_env.load_stats_presenter(
        repo_root,
        fake_attributes)

    local result = {
        unit={},
        row={
            physical_attributes={STRENGTH=2, AGILITY=0},
            mental_attributes={FOCUS=-1, WILLPOWER=3},
            traits={PATIENCE=1},
            skills={MINING=10},
        },
    }

    test.case('Stats presenter: notable values and default sections', function()
        local sections, flat = presenter.build_records(result)
        test.assert_equal(3, #sections)
        test.assert_sequence({'Strength'}, labels(sections[1]))
        test.assert_sequence({'Focus', 'Willpower'}, labels(sections[2]))
        test.assert_sequence({'Patience'}, labels(sections[3]))
        test.assert_equal(4, #flat)
        test.assert_equal('lightgreen', sections[1][1].pen)
        test.assert_equal('lightblue', sections[2][1].pen)
        test.assert_equal('lightmagenta', sections[3][1].pen)
    end)

    test.case('Stats presenter: skills remain excluded', function()
        local _, flat = presenter.build_records(result)
        for _, record in ipairs(flat) do
            test.assert_false(record.label == 'Mining')
        end
    end)

    local sort_cases = {
        {name='label ascending', key='label', reverse=false,
         expected={'Focus', 'Patience', 'Strength', 'Willpower'}},
        {name='label descending', key='label', reverse=true,
         expected={'Willpower', 'Strength', 'Patience', 'Focus'}},
        {name='delta ascending', key='value', reverse=false,
         expected={'Focus', 'Patience', 'Strength', 'Willpower'}},
        {name='delta descending', key='value', reverse=true,
         expected={'Willpower', 'Strength', 'Patience', 'Focus'}},
    }
    for _, case in ipairs(sort_cases) do
        test.case('Stats presenter: ' .. case.name, function()
            local _, records = presenter.build_records(result)
            presenter.sort_records(records, case.key, case.reverse)
            test.assert_sequence(case.expected, labels(records))
        end)
    end

    test.case('Stats presenter: ties use label then stable source order', function()
        local records = {
            {label='Beta', label_key='beta', deviation=1, ordinal=3},
            {label='Alpha', label_key='alpha', deviation=1, ordinal=2},
            {label='Alpha', label_key='alpha', deviation=1, ordinal=1},
        }
        presenter.sort_records(records, 'value', true)
        test.assert_sequence({'Alpha', 'Alpha', 'Beta'}, labels(records))
        test.assert_equal(1, records[1].ordinal)
        test.assert_equal(2, records[2].ordinal)
    end)

    test.case('Stats presenter: body preserves default section gaps', function()
        local tokens = presenter.body(result, nil, false)
        local newline_count = 0
        for _, token in ipairs(tokens) do
            if token == '<NL>' then newline_count = newline_count + 1 end
        end
        test.assert_equal(8, newline_count)
    end)
end
