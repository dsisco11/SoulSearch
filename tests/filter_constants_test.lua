local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('filter constants: preserve serialized filter protocol values', function()
        local constants =
            soulsearch_env.load_filter_constants(repo_root).FILTER_CONSTANTS

        luaunit.assertIs('high', constants.direction.HIGH)
        luaunit.assertIs('low', constants.direction.LOW)
        luaunit.assertIs('candidate', constants.behavior.CANDIDATE)
        luaunit.assertIs('ranking', constants.behavior.RANKING)
        luaunit.assertIs('unit_scope', constants.kind.UNIT_SCOPE)
        luaunit.assertIs('citizens', constants.unit_scope.CITIZENS)
        luaunit.assertIs('livestock', constants.unit_scope.LIVESTOCK)
        luaunit.assertIs('pets', constants.unit_scope.PETS)
        luaunit.assertIs('visitors', constants.unit_scope.VISITORS)
        luaunit.assertIs('wildlife', constants.unit_scope.WILDLIFE)
        luaunit.assertIs('unit_scope:', constants.unit_scope.id_prefix)
        luaunit.assertIs('race:group:HUMANOIDS',
            constants.default_race_filter_id)
        luaunit.assertIs('race:raw:', constants.race.raw_id_prefix)
    end)

return native_tests
