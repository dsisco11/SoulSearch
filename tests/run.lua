local separator = package.config:sub(1, 1)
local source = debug.getinfo(1, 'S').source
assert(source:sub(1, 1) == '@', 'tests/run.lua must be loaded from a file')
local tests_root = assert(source:sub(2):match('^(.*)[/\\][^/\\]+$'),
    'could not resolve the tests directory')
local repo_root = tests_root .. separator .. '..'
local production_root = repo_root .. separator .. 'src' .. separator ..
    'scripts_modinstalled'
package.path = table.concat({
    tests_root .. separator .. '?.lua',
    tests_root .. separator .. '?' .. separator .. 'init.lua',
    production_root .. separator .. '?.lua',
    production_root .. separator .. '?' .. separator .. 'init.lua',
    package.path,
}, ';')

local luaunit = require('luaunit')

-- Run-UnitTests.ps1 supplies the deterministic, newline-delimited suite list
-- through this project-neutral environment variable. LuaUnit CLI arguments are
-- deliberately left in arg so callers can target tests or select output modes.
assert(os.getenv('DFHACK_LUA_TEST_FILES'),
    'DFHACK_LUA_TEST_FILES must be provided by Tools/Run-UnitTests.ps1')

-- Phase 2 runs the native LuaUnit bootstrap contract only. Phase 3 bridges the
-- existing custom suites onto LuaUnit before they join this runner.
require('luaunit_setup_test')

os.exit(luaunit.LuaUnit.run())
