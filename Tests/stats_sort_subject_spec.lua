local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('stats sort subject', function()

    it('sort state: normalization and cycling preserve Stats semantics', function()
        local sort = soulsearch_env.load_sort_state(repo_root)
        local spec = sort.new_spec({'label', 'value'}, {value=true})
        local default = sort.get_default(spec)
        assert.is_nil(default.key)
        local label = sort.next(default, 'label', spec)
        assert.are.equal('label', label.key)
        assert.is_falsy(label.reverse)
        local label_reverse = sort.next(label, 'label', spec)
        assert.is_truthy(label_reverse.reverse)
        assert.is_nil(sort.next(label_reverse, 'label', spec).key)
        local value = sort.next(default, 'value', spec)
        assert.is_truthy(value.reverse)
        assert.is_falsy(sort.next(value, 'value', spec).reverse)
        local malformed = sort.normalize({key='future', reverse=true, phase=2}, spec)
        assert.is_nil(malformed.key)
        local result_spec = sort.new_spec({'name', 'profession', 'unit_id'})
        local result = sort.next(sort.get_default(result_spec), 'name', result_spec)
        assert.is_falsy(result.reverse)
        assert.is_truthy(sort.next(result, 'name', result_spec).reverse)
        result.key = 'broken'
        assert.are.equal('name', sort.next(sort.get_default(result_spec), 'name', result_spec).key)
        local result_spec = sort.new_spec({'name', 'profession', 'unit_id'})
        local result = sort.next(sort.get_default(result_spec), 'name', result_spec)
        assert.is_falsy(result.reverse)
        assert.is_truthy(sort.next(result, 'name', result_spec).reverse)
        result.key = 'broken'
        assert.are.equal('name', sort.next(sort.get_default(result_spec), 'name', result_spec).key)
    end)

    it('stats subject: row construction snapshots identity and criteria', function()
        local subject = soulsearch_env.load_stats_subject(repo_root)
        local unit = {id=7}
        local criteria = {{id='skill:MINING'}}
        local value = subject.from_row({
            unit=unit, unit_id=7, name='Urist', profession='Miner',
        }, criteria)
        assert.are.equal(unit, value.unit)
        assert.are.equal(7, value.unit_id)
        assert.are.equal('Urist', value.name)
        criteria[1] = {id='skill:SWORD'}
        assert.are.equal('skill:MINING', value.filter_criteria[1].id)
        assert.is_nil(subject.from_row({unit=unit, unit_id=-1}))
    end)

end)