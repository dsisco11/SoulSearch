local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('sort state: normalization and cycling preserve Stats semantics', function()
        local sort = soulsearch_env.load_sort_state(repo_root)
        local spec = sort.new_spec({'label', 'value'}, {value=true})
        local default = sort.get_default(spec)
        luaunit.assertNil(default.key)
        local label = sort.next(default, 'label', spec)
        luaunit.assertIs('label', label.key)
        luaunit.assertEvalToFalse(label.reverse)
        local label_reverse = sort.next(label, 'label', spec)
        luaunit.assertEvalToTrue(label_reverse.reverse)
        luaunit.assertNil(sort.next(label_reverse, 'label', spec).key)
        local value = sort.next(default, 'value', spec)
        luaunit.assertEvalToTrue(value.reverse)
        luaunit.assertEvalToFalse(sort.next(value, 'value', spec).reverse)
        local malformed = sort.normalize({key='future', reverse=true, phase=2}, spec)
        luaunit.assertNil(malformed.key)
        local result_spec = sort.new_spec({'name', 'profession', 'unit_id'})
        local result = sort.next(sort.get_default(result_spec), 'name', result_spec)
        luaunit.assertEvalToFalse(result.reverse)
        luaunit.assertEvalToTrue(sort.next(result, 'name', result_spec).reverse)
        result.key = 'broken'
        luaunit.assertIs('name', sort.next(sort.get_default(result_spec), 'name', result_spec).key)
        local result_spec = sort.new_spec({'name', 'profession', 'unit_id'})
        local result = sort.next(sort.get_default(result_spec), 'name', result_spec)
        luaunit.assertEvalToFalse(result.reverse)
        luaunit.assertEvalToTrue(sort.next(result, 'name', result_spec).reverse)
        result.key = 'broken'
        luaunit.assertIs('name', sort.next(sort.get_default(result_spec), 'name', result_spec).key)
    end)

    add_test('stats subject: row construction snapshots identity and criteria', function()
        local subject = soulsearch_env.load_stats_subject(repo_root)
        local unit = {id=7}
        local criteria = {{id='skill:MINING'}}
        local value = subject.from_row({
            unit=unit, unit_id=7, name='Urist', profession='Miner',
        }, criteria)
        luaunit.assertIs(unit, value.unit)
        luaunit.assertIs(7, value.unit_id)
        luaunit.assertIs('Urist', value.name)
        criteria[1] = {id='skill:SWORD'}
        luaunit.assertIs('skill:MINING', value.filter_criteria[1].id)
        luaunit.assertNil(subject.from_row({unit=unit, unit_id=-1}))
    end)

return native_tests
