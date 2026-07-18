local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('lifecycle: cache resets occur once per world boundary', function()
        local calls = {}
        local modules = {}
        for _, name in ipairs{'attributes', 'race_catalog', 'descriptors', 'residents'} do
            modules['internal/soulsearch/' .. name] = {
                reset_cache=function() calls[name] = (calls[name] or 0) + 1 end,
                reset=function() calls[name] = (calls[name] or 0) + 1 end,
            }
        end
        local lifecycle = soulsearch_env.load_lifecycle(repo_root, modules)
        local first, second = {}, {}
        luaunit.assertEvalToTrue(lifecycle.prepare_for_world(first))
        luaunit.assertEvalToFalse(lifecycle.prepare_for_world(first))
        luaunit.assertEvalToTrue(lifecycle.prepare_for_world(second))
        for _, name in ipairs{'attributes', 'race_catalog', 'descriptors', 'residents'} do
            luaunit.assertIs(2, calls[name])
        end
    end)

    add_test('attributes and descriptors: caches reuse then reset explicitly', function()
        local attributes = soulsearch_env.load_attributes(repo_root)
        local first = attributes.get_race_medians(1)
        local second = attributes.get_race_medians(1)
        luaunit.assertEvalToTrue(first == second)
        attributes.reset_cache()
        luaunit.assertEvalToFalse(first == attributes.get_race_medians(1))

        local descriptors = soulsearch_env.load_descriptors(repo_root)
        local first_catalog = descriptors.get_catalog()
        luaunit.assertEvalToTrue(first_catalog == descriptors.get_catalog())
        descriptors.reset_cache()
        luaunit.assertEvalToFalse(first_catalog == descriptors.get_catalog())
    end)

    add_test('lifecycle: world changes retain settings until module reload', function()
        local modules = {}
        for _, name in ipairs{'attributes', 'race_catalog', 'descriptors', 'residents'} do
            modules['internal/soulsearch/' .. name] = {
                reset_cache=function() end,
                reset=function() end,
            }
        end
        local lifecycle = soulsearch_env.load_lifecycle(repo_root, modules)
        local settings = soulsearch_env.load_window_settings(repo_root)
        settings.update('scoped', {result_sort='name'})

        lifecycle.prepare_for_world({})
        luaunit.assertIs('name', settings.load('scoped').result_sort)
        lifecycle.prepare_for_world({})
        luaunit.assertIs('name', settings.load('scoped').result_sort)

        local reloaded_settings = soulsearch_env.load_window_settings(repo_root)
        luaunit.assertNil(reloaded_settings.load('scoped'))
    end)

return native_tests
