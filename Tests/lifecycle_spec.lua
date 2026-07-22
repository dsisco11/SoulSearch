local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('lifecycle', function()

    it('lifecycle: cache resets occur once per world boundary', function()
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
        assert.is_truthy(lifecycle.prepare_for_world(first))
        assert.is_falsy(lifecycle.prepare_for_world(first))
        assert.is_truthy(lifecycle.prepare_for_world(second))
        for _, name in ipairs{'attributes', 'race_catalog', 'descriptors', 'residents'} do
            assert.are.equal(2, calls[name])
        end
    end)

    it('attributes and descriptors: caches reuse then reset explicitly', function()
        local attributes = soulsearch_env.load_attributes(repo_root)
        local first = attributes.get_race_medians(1)
        local second = attributes.get_race_medians(1)
        assert.is_truthy(first == second)
        attributes.reset_cache()
        assert.is_falsy(first == attributes.get_race_medians(1))

        local descriptors = soulsearch_env.load_descriptors(repo_root)
        local first_catalog = descriptors.get_catalog()
        assert.is_truthy(first_catalog == descriptors.get_catalog())
        descriptors.reset_cache()
        assert.is_falsy(first_catalog == descriptors.get_catalog())
    end)

    it('lifecycle: world changes retain settings until module reload', function()
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
        assert.are.equal('name', settings.load('scoped').result_sort)
        lifecycle.prepare_for_world({})
        assert.are.equal('name', settings.load('scoped').result_sort)

        local reloaded_settings = soulsearch_env.load_window_settings(repo_root)
        assert.is_nil(reloaded_settings.load('scoped'))
    end)

end)
