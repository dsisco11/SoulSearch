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

    test.case('UI reload teardown: dismisses zero, one, and multiple screens safely', function()
        local ui, registry = soulsearch_env.load_ui_open_guard(repo_root, nil)
        registry.clear()

        ui.dismiss_all()
        test.assert_equal(0, registry.count())

        local dismissals = {}
        local function registered_screen(name)
            local active = {name=name, dismiss_count=0}
            function active:dismiss()
                self.dismiss_count = self.dismiss_count + 1
                table.insert(dismissals, self.name)
                registry.remove(self)
            end
            registry.add(active)
            return active
        end

        local one = registered_screen('one')
        ui.dismiss_all()
        test.assert_equal(1, one.dismiss_count)
        test.assert_equal(0, registry.count())

        local first = registered_screen('first')
        local second = registered_screen('second')
        local third = registered_screen('third')
        ui.dismiss_all()
        test.assert_equal(1, first.dismiss_count)
        test.assert_equal(1, second.dismiss_count)
        test.assert_equal(1, third.dismiss_count)
        test.assert_equal(0, registry.count())

        ui.dismiss_all()
        test.assert_equal(4, #dismissals)
    end)
end
