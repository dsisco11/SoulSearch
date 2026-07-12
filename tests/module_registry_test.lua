local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local registry = soulsearch_env.load_module_registry(repo_root)

    test.case('module registry: validates real contracts in dependency order', function()
        local calls = {}
        local loaded = registry.load_all(function(name)
            table.insert(calls, name)
            for _, spec in ipairs(registry.MODULES) do
                if spec.name == name then return {[spec.contract]=function() end} end
            end
        end)
        test.assert_equal(#registry.MODULES, #calls)
        test.assert_equal('internal/soulsearch/df_enums', calls[1])
        test.assert_equal('internal/soulsearch/ui', calls[#calls])
        local candidate_index, state_index
        for index, name in ipairs(calls) do
            if name == 'internal/soulsearch/candidate_provider' then
                candidate_index = index
            elseif name == 'internal/soulsearch/filter_state' then
                state_index = index
            end
        end
        test.assert_true(candidate_index < state_index)
        test.assert_true(loaded['internal/soulsearch/search'].apply ~= nil)
        test.assert_true(
            loaded['internal/soulsearch/candidate_provider'].new ~= nil)
    end)

    test.case('module registry: missing contracts fail clearly', function()
        local ok, err = pcall(registry.load_all, function() return {} end)
        test.assert_false(ok)
        test.assert_true(tostring(err):find('missing entries()', 1, true) ~= nil)
    end)

    test.case('module registry: clear order is reverse dependency order', function()
        local names = registry.get_script_names()
        test.assert_equal(#registry.MODULES + 1, #names)
        test.assert_equal('internal/soulsearch/module_registry', names[1])
        test.assert_equal('internal/soulsearch/ui', names[2])
        test.assert_equal('internal/soulsearch/df_enums', names[#names])
    end)
end
