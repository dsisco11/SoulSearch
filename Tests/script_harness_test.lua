local harness = require('support.script_harness')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('script harness: supplies only explicit dependencies and overrides', function()
        local module = harness.load(repo_root, {
        source_path='Tests/fixtures/script_harness_target.lua',
            reqscript={['fixture/dependency']={value=2}},
            require_modules={['fixture.require']={value=3}},
            globals={global_offset=4},
        })
        luaunit.assertIs(9, module.result)
    end)

    add_test('script harness: missing fake dependencies fail explicitly', function()
        local ok, err = pcall(harness.load, repo_root, {
        source_path='Tests/fixtures/script_harness_target.lua',
            reqscript={['fixture/dependency']={value=2}},
            require_modules={},
            globals={global_offset=4},
        })
        luaunit.assertEvalToFalse(ok)
        luaunit.assertEvalToTrue(tostring(err):find('unexpected require: fixture.require', 1, true) ~= nil)
    end)

return native_tests
