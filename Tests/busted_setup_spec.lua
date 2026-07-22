local separator = package.config:sub(1, 1)
local repo_root = require('support.repo_root')

describe('Busted setup', function()
    it('loads the framework and resolves the repository source root', function()
        assert.is_function(describe)
        assert.is_function(it)
        assert.is_table(assert)

        local production = assert(io.open(repo_root .. separator .. 'src' ..
            separator .. 'scripts_modinstalled' .. separator .. 'soulsearch.lua', 'r'))
        production:close()
    end)

    it('is discovered only through the spec filename convention', function()
        local source = debug.getinfo(1, 'S').source
        assert.is_truthy(source:match('busted_setup_spec%.lua$'))

        local support_path = repo_root .. separator .. 'Tests' .. separator ..
            'support' .. separator .. 'repo_root.lua'
        assert.is_nil(support_path:match('_spec%.lua$'))
    end)

    it('propagates an opt-in failure', function()
        if os.getenv('UNIT_TEST_SMOKE_FORCE_FAILURE') == '1' then
            assert.is_true(false, 'intentional Busted smoke failure')
        end
    end)
end)
