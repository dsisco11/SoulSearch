local soulsearch_env = require('support.soulsearch_env')

local function labels(records)
    local result = {}
    for _, record in ipairs(records) do table.insert(result, record.label) end
    return result
end

local repo_root = require('support.repo_root')

describe('stats presenter', function()

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

    it('Stats presenter: notable values and default sections', function()
        local sections, flat = presenter.build_records(result)
        assert.are.equal(3, #sections)
        assert.are.same({'Strength'}, labels(sections[1]))
        assert.are.same({'Focus', 'Willpower'}, labels(sections[2]))
        assert.are.same({'Patience'}, labels(sections[3]))
        assert.are.equal(4, #flat)
        assert.are.equal('lightgreen', sections[1][1].pen)
        assert.are.equal('lightblue', sections[2][1].pen)
        assert.are.equal('lightmagenta', sections[3][1].pen)
    end)

    it('Stats presenter: skills remain excluded', function()
        local _, flat = presenter.build_records(result)
        for _, record in ipairs(flat) do
            assert.is_falsy(record.label == 'Mining')
        end
    end)

    it('Stats presenter: no meaningful deviations produces no records', function()
        local records = presenter.get_display_records({
            unit={},
            row={
                physical_attributes={STRENGTH=0},
                mental_attributes={FOCUS=0},
                traits={PATIENCE=0},
            },
        }, nil, false)
        assert.are.equal(0, #records)
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
        it('Stats presenter: ' .. case.name, function()
            local _, records = presenter.build_records(result)
            presenter.sort_records(records, case.key, case.reverse)
            assert.are.same(case.expected, labels(records))
        end)
    end

    it('Stats presenter: ties use label then stable source order', function()
        local records = {
            {label='Beta', label_key='beta', deviation=1, ordinal=3},
            {label='Alpha', label_key='alpha', deviation=1, ordinal=2},
            {label='Alpha', label_key='alpha', deviation=1, ordinal=1},
        }
        presenter.sort_records(records, 'value', true)
        assert.are.same({'Alpha', 'Alpha', 'Beta'}, labels(records))
        assert.are.equal(1, records[1].ordinal)
        assert.are.equal(2, records[2].ordinal)
    end)

    it('Stats presenter: body preserves default section gaps', function()
        local tokens = presenter.body(result, nil, false)
        local newline_count = 0
        for _, token in ipairs(tokens) do
            if token == '<NL>' then newline_count = newline_count + 1 end
        end
        assert.are.equal(6, newline_count)
    end)

    it('Stats presenter: column header remains separate from records', function()
        local header = presenter.column_header('value', true)
        local body = presenter.body(result, nil, false)
        assert.are.equal('Stat' .. (' '):rep(22), header[1].text)
        assert.are.equal('  Strength' .. (' '):rep(16), body[1].text)
    end)

end)