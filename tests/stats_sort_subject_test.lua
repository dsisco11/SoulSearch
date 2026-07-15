local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    test.case('sort state: normalization and cycling preserve Stats semantics', function()
        local sort = soulsearch_env.load_sort_state(repo_root)
        local spec = sort.new_spec({'label', 'value'}, {value=true})
        local default = sort.get_default(spec)
        test.assert_nil(default.key)
        local label = sort.next(default, 'label', spec)
        test.assert_equal('label', label.key)
        test.assert_false(label.reverse)
        local label_reverse = sort.next(label, 'label', spec)
        test.assert_true(label_reverse.reverse)
        test.assert_nil(sort.next(label_reverse, 'label', spec).key)
        local value = sort.next(default, 'value', spec)
        test.assert_true(value.reverse)
        test.assert_false(sort.next(value, 'value', spec).reverse)
        local malformed = sort.normalize({key='future', reverse=true, phase=2}, spec)
        test.assert_nil(malformed.key)
        local result_spec = sort.new_spec({'name', 'profession', 'unit_id'})
        local result = sort.next(sort.get_default(result_spec), 'name', result_spec)
        test.assert_false(result.reverse)
        test.assert_true(sort.next(result, 'name', result_spec).reverse)
        result.key = 'broken'
        test.assert_equal('name', sort.next(sort.get_default(result_spec), 'name', result_spec).key)
        local result_spec = sort.new_spec({'name', 'profession', 'unit_id'})
        local result = sort.next(sort.get_default(result_spec), 'name', result_spec)
        test.assert_false(result.reverse)
        test.assert_true(sort.next(result, 'name', result_spec).reverse)
        result.key = 'broken'
        test.assert_equal('name', sort.next(sort.get_default(result_spec), 'name', result_spec).key)
    end)

    test.case('stats subject: row construction snapshots identity and criteria', function()
        local subject = soulsearch_env.load_stats_subject(repo_root)
        local unit = {id=7}
        local criteria = {{id='skill:MINING'}}
        local value = subject.from_row({
            unit=unit, unit_id=7, name='Urist', profession='Miner',
        }, criteria)
        test.assert_equal(unit, value.unit)
        test.assert_equal(7, value.unit_id)
        test.assert_equal('Urist', value.name)
        criteria[1] = {id='skill:SWORD'}
        test.assert_equal('skill:MINING', value.filter_criteria[1].id)
        test.assert_nil(subject.from_row({unit=unit, unit_id=-1}))
    end)
end
