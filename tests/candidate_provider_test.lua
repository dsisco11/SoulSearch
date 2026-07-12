local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    test.case('candidate provider: preserves the supplied collection contract', function()
        local calls = 0
        local expected = {{id=1}, {id=2}}
        local provider = soulsearch_env.load_candidate_provider(repo_root).new(function()
            calls = calls + 1
            return expected
        end)
        local units, err = provider.get_units()
        test.assert_equal(expected, units)
        test.assert_nil(err)
        test.assert_equal(1, calls)
    end)

    test.case('candidate provider: requires a collection function', function()
        local provider = soulsearch_env.load_candidate_provider(repo_root)
        local ok, err = pcall(provider.new, false)
        test.assert_false(ok)
        test.assert_true(tostring(err):find('requires get_units()', 1, true) ~= nil)
    end)
end
