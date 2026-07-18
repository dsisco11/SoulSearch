local luaunit = require('luaunit')
local separator = package.config:sub(1, 1)
local repo_root = require('support.repo_root')

local native_tests = {}

function native_tests:test_dependency_and_repository_root()
    luaunit.assertNotNil(luaunit)

    local production = assert(io.open(repo_root .. separator .. 'src' ..
        separator .. 'scripts_modinstalled' .. separator .. 'soulsearch.lua', 'r'))
    production:close()
end

function native_tests:test_discovery_contract()
    local files = assert(os.getenv('DFHACK_LUA_TEST_FILES'),
        'runner did not provide discovered test files')

    luaunit.assertStrContains(files, 'luaunit_setup_test.lua')
    luaunit.assertStrContains(files, 'attributes_test.lua')
    luaunit.assertNotStrContains(files, 'Tests\\support\\testlib.lua')
    luaunit.assertNotStrContains(files, 'Tests\\run.lua')
end

function native_tests:test_opt_in_failure_path()
    if os.getenv('DFHACK_LUAUNIT_SMOKE_FORCE_FAILURE') == '1' then
        luaunit.fail('intentional LuaUnit smoke failure')
    end
end

return native_tests
