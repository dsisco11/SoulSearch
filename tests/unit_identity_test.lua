local env = require('support.soulsearch_env')
local luaunit = require('luaunit')
local root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('unit identity: owns the unit name and title labels', function()
        local UnitIdentity = env.load_unit_identity(root)
        local identity = UnitIdentity{subject={row={}, name='Urist', profession='Miner'}}

        luaunit.assertIs('Urist', identity.subviews.name.text)
        luaunit.assertIs('Miner', identity.subviews.title.text)
        luaunit.assertIs(3, identity:get_height())

        identity:set_subject(nil)
        luaunit.assertIs('No unit selected.', identity.subviews.name.text)
        luaunit.assertIs('', identity.subviews.title.text)
        luaunit.assertIs(1, identity:get_height())
    end)

return native_tests
