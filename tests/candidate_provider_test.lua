local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('candidate provider: preserves the supplied collection contract', function()
        local calls = 0
        local expected = {{id=1}, {id=2}}
        local provider = soulsearch_env.load_candidate_provider(repo_root).new(function()
            calls = calls + 1
            return expected
        end)
        local units, err = provider.get_units()
        luaunit.assertIs(expected, units)
        luaunit.assertNil(err)
        luaunit.assertIs(1, calls)
    end)

    add_test('candidate provider: requires a collection function', function()
        local provider = soulsearch_env.load_candidate_provider(repo_root)
        local ok, err = pcall(provider.new, false)
        luaunit.assertEvalToFalse(ok)
        luaunit.assertEvalToTrue(tostring(err):find('requires get_units()', 1, true) ~= nil)
    end)

return native_tests
