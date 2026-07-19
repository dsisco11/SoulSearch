local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('candidate provider', function()

    it('candidate provider: preserves the supplied collection contract', function()
        local calls = 0
        local expected = {{id=1}, {id=2}}
        local provider = soulsearch_env.load_candidate_provider(repo_root).new(function()
            calls = calls + 1
            return expected
        end)
        local units, err = provider.get_units()
        assert.are.equal(expected, units)
        assert.is_nil(err)
        assert.are.equal(1, calls)
    end)

    it('candidate provider: requires a collection function', function()
        local provider = soulsearch_env.load_candidate_provider(repo_root)
        local ok, err = pcall(provider.new, false)
        assert.is_falsy(ok)
        assert.is_truthy(tostring(err):find('requires get_units()', 1, true) ~= nil)
    end)

end)