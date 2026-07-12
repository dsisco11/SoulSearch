local repo_root = assert(arg[1], 'usage: lua tests/run.lua <repo-root>')
local separator = package.config:sub(1, 1)
local tests_root = repo_root .. separator .. 'tests'
package.path = table.concat({
    tests_root .. separator .. '?.lua',
    tests_root .. separator .. '?' .. separator .. 'init.lua',
    package.path,
}, ';')

local test = require('support.testlib')
local suites = {
    (require('attributes_test')),
    (require('attribute_descriptions_test')),
    (require('metadata_test')),
    (require('filter_state_test')),
    (require('filter_defaults_test')),
    (require('role_presets_test')),
    (require('filter_presets_test')),
    (require('search_test')),
    (require('ui_refresh_test')),
    (require('ui_glyphs_test')),
    (require('ui_layout_test')),
    (require('text_match_test')),
    (require('ui_format_test')),
    (require('stats_presenter_test')),
    (require('ui_components_test')),
    (require('residents_test')),
    (require('lifecycle_test')),
    (require('module_registry_test')),
}

for _, register_suite in ipairs(suites) do
    register_suite(test, repo_root)
end

if not test.run() then
    os.exit(1)
end
