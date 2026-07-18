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
local compatibility = require('support.luaunit_compat')

-- Run-UnitTests.ps1 supplies the deterministic, newline-delimited suite list
-- through this project-neutral environment variable. LuaUnit CLI arguments are
-- deliberately left in arg so callers can target tests or select output modes.
local discovered_files = assert(os.getenv('DFHACK_LUA_TEST_FILES'),
    'DFHACK_LUA_TEST_FILES must be provided by Tools/Run-UnitTests.ps1')

require('luaunit_setup_test')

local normalized_tests_root = tests_root:gsub('\\', '/') .. '/'
local metrics = {
    suite_count=0,
    case_count=0,
    assertion_count=0,
    assertion_counts={
        ['true']=0,
        ['false']=0,
        ['nil']=0,
        equal=0,
        near=0,
        sequence=0,
    },
}

for path in discovered_files:gmatch('[^\r\n]+') do
    local normalized_path = path:gsub('\\', '/')
    assert(normalized_path:sub(1, #normalized_tests_root) ==
        normalized_tests_root,
        'discovered test is outside tests/: ' .. path)

    local relative_path = normalized_path:sub(#normalized_tests_root + 1)
    local module_name = relative_path:gsub('%.lua$', ''):gsub('/', '.')
    if module_name ~= 'luaunit_setup_test' then
        local register_suite = require(module_name)
        assert(type(register_suite) == 'function',
            module_name .. ' must return a suite registration function')

        metrics.suite_count = metrics.suite_count + 1
        register_suite(compatibility.new(module_name, metrics), repo_root)
    end
end

local result = luaunit.LuaUnit.run()
io.write(('Legacy compatibility: %d suite file(s), %d case(s), ' ..
    '%d assertion(s) executed\n'):format(
    metrics.suite_count,
    metrics.case_count,
    metrics.assertion_count))
io.write(('Legacy assertions: true=%d, false=%d, nil=%d, equal=%d, ' ..
    'near=%d, sequence=%d\n'):format(
    metrics.assertion_counts['true'],
    metrics.assertion_counts['false'],
    metrics.assertion_counts['nil'],
    metrics.assertion_counts.equal,
    metrics.assertion_counts.near,
    metrics.assertion_counts.sequence))
os.exit(result)
