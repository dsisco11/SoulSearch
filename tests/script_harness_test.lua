local harness = require('support.script_harness')

return function(test, repo_root)
    test.case('script harness: supplies only explicit dependencies and overrides', function()
        local module = harness.load(repo_root, {
            source_path='tests/fixtures/script_harness_target.lua',
            reqscript={['fixture/dependency']={value=2}},
            require_modules={['fixture.require']={value=3}},
            globals={global_offset=4},
        })
        test.assert_equal(9, module.result)
    end)

    test.case('script harness: missing fake dependencies fail explicitly', function()
        local ok, err = pcall(harness.load, repo_root, {
            source_path='tests/fixtures/script_harness_target.lua',
            reqscript={['fixture/dependency']={value=2}},
            require_modules={},
            globals={global_offset=4},
        })
        test.assert_false(ok)
        test.assert_true(tostring(err):find('unexpected require: fixture.require', 1, true) ~= nil)
    end)
end
