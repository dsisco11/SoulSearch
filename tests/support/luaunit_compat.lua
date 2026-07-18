local luaunit = require('luaunit')

local M = {}

local function format_value(value, seen)
    if type(value) ~= 'table' then
        return type(value) == 'string' and string.format('%q', value) or
            tostring(value)
    end

    seen = seen or {}
    if seen[value] then
        return '<cycle>'
    end
    seen[value] = true

    local parts = {}
    for key, child in pairs(value) do
        table.insert(parts, ('[%s]=%s'):format(
            format_value(key, seen),
            format_value(child, seen)))
    end
    table.sort(parts)
    seen[value] = nil
    return '{' .. table.concat(parts, ', ') .. '}'
end

local function assertion(metrics, kind, condition, message)
    metrics.assertion_count = metrics.assertion_count + 1
    metrics.assertion_counts[kind] = metrics.assertion_counts[kind] + 1
    luaunit.assertTrue(condition, message)
end

function M.new(suite_name, metrics)
    local test = {}

    function test.case(name, callback)
        local luaunit_name = ('test %s :: %s'):format(suite_name, name)
        if _G[luaunit_name] ~= nil then
            error('duplicate compatibility test name: ' .. luaunit_name, 2)
        end
        _G[luaunit_name] = callback
        metrics.case_count = metrics.case_count + 1
    end

    function test.assert_true(value, message)
        assertion(metrics, 'true', not not value,
            message or ('expected truthy value, got ' .. format_value(value)))
    end

    function test.assert_false(value, message)
        assertion(metrics, 'false', not value,
            message or ('expected falsey value, got ' .. format_value(value)))
    end

    function test.assert_nil(value, message)
        metrics.assertion_count = metrics.assertion_count + 1
        metrics.assertion_counts['nil'] = metrics.assertion_counts['nil'] + 1
        luaunit.assertNil(value,
            message or ('expected nil, got ' .. format_value(value)))
    end

    function test.assert_equal(expected, actual, message)
        assertion(metrics, 'equal', expected == actual,
            message or ('expected %s, got %s'):format(
                format_value(expected),
                format_value(actual)))
    end

    function test.assert_near(expected, actual, tolerance, message)
        tolerance = tolerance or 1e-9
        assertion(metrics, 'near',
            type(actual) == 'number' and
                math.abs(expected - actual) <= tolerance,
            message or ('expected %s +/- %s, got %s'):format(
                format_value(expected),
                format_value(tolerance),
                format_value(actual)))
    end

    function test.assert_sequence(expected, actual, message)
        local failure
        if #expected ~= #actual then
            failure = message or 'sequence lengths differ'
        else
            for index, expected_value in ipairs(expected) do
                if expected_value ~= actual[index] then
                    failure = message or
                        ('sequence differs at index %d: expected %s, got %s'):
                            format(index, format_value(expected_value),
                                format_value(actual[index]))
                    break
                end
            end
        end
        assertion(metrics, 'sequence', failure == nil, failure)
    end

    return test
end

return M
