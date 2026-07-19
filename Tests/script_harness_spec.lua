local harness = require('support.script_harness')

local repo_root = require('support.repo_root')

describe('script harness', function()

    it('script harness: supplies only explicit dependencies and overrides', function()
        local module = harness.load(repo_root, {
        source_path='Tests/fixtures/script_harness_target.lua',
            reqscript={['fixture/dependency']={value=2}},
            require_modules={['fixture.require']={value=3}},
            globals={global_offset=4},
        })
        assert.are.equal(9, module.result)
    end)

    it('script harness: missing fake dependencies fail explicitly', function()
        local ok, err = pcall(harness.load, repo_root, {
        source_path='Tests/fixtures/script_harness_target.lua',
            reqscript={['fixture/dependency']={value=2}},
            require_modules={},
            globals={global_offset=4},
        })
        assert.is_falsy(ok)
        assert.is_truthy(tostring(err):find('unexpected require: fixture.require', 1, true) ~= nil)
    end)

end)
