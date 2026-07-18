local soulsearch_env = require('support.soulsearch_env')

local function ids(units)
    local result = {}
    for _, unit in ipairs(units or {}) do table.insert(result, unit.id) end
    return result
end

local function filter(key, direction)
    return {id='unit_scope:' .. key, direction=direction or 'high'}
end

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local family = soulsearch_env.load_candidate_filter_family_provider(repo_root)
    local candidates = soulsearch_env.load_candidate_provider(repo_root)
    local source = {
        {id=1, scopes={citizens=true, fort_residents=true}},
        {id=2, scopes={livestock=true}},
        {id=3, scopes={visitors=true}},
        {id=4, scopes={fort_residents=true}},
        {id=1, scopes={citizens=true, fort_residents=true}},
    }
    local function run(filters)
        return family.new(candidates.new(function() return source end), filters,
            'unit_scope', function(descriptor, unit) return unit.scopes[descriptor.key] end)
            .get_units()
    end

    add_test('candidate filter family: empty, positive, union, negative, and include-except behavior', function()
        luaunit.assertEquals({1, 2, 3, 4}, ids(run({})))
        luaunit.assertEquals({1}, ids(run({filter('citizens')})))
        luaunit.assertEquals({1, 3}, ids(run({filter('citizens'), filter('visitors')})))
        luaunit.assertEquals({1, 3, 4}, ids(run({filter('livestock', 'low')})))
        luaunit.assertEquals({4}, ids(run({filter('fort_residents'), filter('citizens', 'low')})))
    end)

    add_test('candidate filter family: ignores stale, duplicate, invalid, and other-kind filters', function()
        local units = run({
            filter('citizens'), filter('citizens', 'low'),
            {id='unit_scope:unknown', direction='high'},
            {id='race:group:HUMANOIDS', direction='high'},
            {id='unit_scope:visitors', direction='sideways'},
        })
        luaunit.assertEquals({1}, ids(units))
    end)

    add_test('candidate filter family: propagates upstream errors without partial candidates', function()
        local provider = family.new(candidates.new(function() return nil, 'upstream unavailable' end),
            {}, 'unit_scope', function() return true end)
        local units, err = provider.get_units()
        luaunit.assertNil(units)
        luaunit.assertIs('upstream unavailable', err)
    end)

return native_tests
