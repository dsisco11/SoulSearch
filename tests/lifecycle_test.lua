local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    test.case('lifecycle: cache resets occur once per world boundary', function()
        local calls = {}
        local modules = {}
        for _, name in ipairs{'attributes', 'descriptors', 'residents'} do
            modules['internal/soulsearch/' .. name] = {
                reset_cache=function() calls[name] = (calls[name] or 0) + 1 end,
                reset=function() calls[name] = (calls[name] or 0) + 1 end,
            }
        end
        local lifecycle = soulsearch_env.load_lifecycle(repo_root, modules)
        local first, second = {}, {}
        test.assert_true(lifecycle.prepare_for_world(first))
        test.assert_false(lifecycle.prepare_for_world(first))
        test.assert_true(lifecycle.prepare_for_world(second))
        for _, name in ipairs{'attributes', 'descriptors', 'residents'} do
            test.assert_equal(2, calls[name])
        end
    end)

    test.case('attributes and descriptors: caches reuse then reset explicitly', function()
        local attributes = soulsearch_env.load_attributes(repo_root)
        local first = attributes.get_race_medians(1)
        local second = attributes.get_race_medians(1)
        test.assert_true(first == second)
        attributes.reset_cache()
        test.assert_false(first == attributes.get_race_medians(1))

        local descriptors = soulsearch_env.load_descriptors(repo_root)
        local first_catalog = descriptors.get_catalog()
        test.assert_true(first_catalog == descriptors.get_catalog())
        descriptors.reset_cache()
        test.assert_false(first_catalog == descriptors.get_catalog())
    end)
end
