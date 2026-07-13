local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    test.case('UI open: unavailable context prints reason without constructing a screen', function()
        local ui = soulsearch_env.load_ui_open_guard(
            repo_root, 'SoulSearch requires a loaded fortress.')
        local printed = {}
        local original_print = print
        print = function(value) table.insert(printed, value) end
        local ok, err = pcall(ui.open)
        print = original_print

        test.assert_true(ok, tostring(err))
        test.assert_sequence(
            {'SoulSearch requires a loaded fortress.'}, printed)
    end)
end
