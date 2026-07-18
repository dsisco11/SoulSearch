local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local text_match = soulsearch_env.load_text_match(repo_root)
    add_test('text matching: nil and coercion contract', function()
        luaunit.assertEvalToTrue(text_match.contains(nil, nil))
        luaunit.assertEvalToTrue(text_match.contains(123, '23'))
        luaunit.assertEvalToTrue(text_match.contains('Mining', 'NIN'))
        luaunit.assertEvalToFalse(text_match.contains(false, 'fal'))
        luaunit.assertEvalToFalse(text_match.contains(nil, 'x'))
    end)

return native_tests
