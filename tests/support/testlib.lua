local M = {cases={}}

local function format_value(value, seen)
    if type(value) ~= 'table' then
        return type(value) == 'string' and string.format('%q', value) or tostring(value)
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

local function fail(message, level)
    error(message, (level or 1) + 1)
end

function M.case(name, callback)
    table.insert(M.cases, {name=name, callback=callback})
end

function M.assert_true(value, message)
    if not value then
        fail(message or ('expected truthy value, got ' .. format_value(value)), 2)
    end
end

function M.assert_false(value, message)
    if value then
        fail(message or ('expected falsey value, got ' .. format_value(value)), 2)
    end
end

function M.assert_nil(value, message)
    if value ~= nil then
        fail(message or ('expected nil, got ' .. format_value(value)), 2)
    end
end

function M.assert_equal(expected, actual, message)
    if expected ~= actual then
        fail(message or ('expected %s, got %s'):format(
            format_value(expected),
            format_value(actual)), 2)
    end
end

function M.assert_near(expected, actual, tolerance, message)
    tolerance = tolerance or 1e-9
    if type(actual) ~= 'number' or math.abs(expected - actual) > tolerance then
        fail(message or ('expected %s +/- %s, got %s'):format(
            format_value(expected),
            format_value(tolerance),
            format_value(actual)), 2)
    end
end

function M.assert_sequence(expected, actual, message)
    M.assert_equal(#expected, #actual, message or 'sequence lengths differ')
    for index, expected_value in ipairs(expected) do
        if expected_value ~= actual[index] then
            fail(message or ('sequence differs at index %d: expected %s, got %s'):format(
                index,
                format_value(expected_value),
                format_value(actual[index])), 2)
        end
    end
end

function M.run()
    local failures = 0
    for _, test_case in ipairs(M.cases) do
        local ok, err = xpcall(test_case.callback, debug.traceback)
        if ok then
            io.write(('[PASS] %s\n'):format(test_case.name))
        else
            failures = failures + 1
            io.stderr:write(('[FAIL] %s\n%s\n'):format(test_case.name, err))
        end
    end

    io.write(('\n%d test(s), %d failure(s)\n'):format(#M.cases, failures))
    return failures == 0
end

return M
