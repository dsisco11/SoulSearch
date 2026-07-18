local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local function load(map_loaded, fortress_mode)
        return soulsearch_env.load_availability(repo_root, {
            isMapLoaded=function() return map_loaded end,
            world={isFortressMode=function() return fortress_mode end},
        })
    end

    add_test('availability: no map, wrong mode, and valid fortress have one policy', function()
        luaunit.assertIs('SoulSearch requires a loaded fortress map.',
            load(false, true).get_unavailable_reason())
        luaunit.assertIs('SoulSearch only works in fortress mode.',
            load(true, false).get_unavailable_reason())
        luaunit.assertNil(load(true, true).get_unavailable_reason())
    end)

return native_tests
