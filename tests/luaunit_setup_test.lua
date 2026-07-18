local luaunit = require('luaunit')

local separator = package.config:sub(1, 1)
local source = debug.getinfo(1, 'S').source
local tests_root = assert(source:sub(2):match('^(.*)[/\\][^/\\]+$'))
local repo_root = tests_root .. separator .. '..'

TestLuaUnitSetup = {}

function TestLuaUnitSetup:test_dependency_and_repository_root()
    luaunit.assertNotNil(luaunit)

    local production = assert(io.open(repo_root .. separator .. 'src' ..
        separator .. 'scripts_modinstalled' .. separator .. 'soulsearch.lua', 'r'))
    production:close()
end

function TestLuaUnitSetup:test_discovery_contract()
    local files = assert(os.getenv('DFHACK_LUA_TEST_FILES'),
        'runner did not provide discovered test files')

    luaunit.assertStrContains(files, 'luaunit_setup_test.lua')
    luaunit.assertStrContains(files, 'attributes_test.lua')
    luaunit.assertNotStrContains(files, 'tests\\support\\testlib.lua')
    luaunit.assertNotStrContains(files, 'tests\\run.lua')
end

function TestLuaUnitSetup:test_opt_in_failure_path()
    if os.getenv('DFHACK_LUAUNIT_SMOKE_FORCE_FAILURE') == '1' then
        luaunit.fail('intentional LuaUnit smoke failure')
    end
end

return TestLuaUnitSetup
