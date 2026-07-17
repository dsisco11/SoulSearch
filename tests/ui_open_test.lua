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

    test.case('UI open: scoped options construct one new screen', function()
        local ui, _, state, screen_constructor =
            soulsearch_env.load_ui_open_guard(repo_root, nil)
        local constructed
        screen_constructor.construct=function(attributes)
            constructed = attributes
            return {show=function(self) return self end}
        end
        local options = {
            settings_id='creatures:miners',
            filters={{id='unit_scope:fort_residents', direction='high'},
                {id='skill:MINING', direction='high'}},
        }
        local screen = ui.open(options)

        test.assert_true(screen ~= nil)
        test.assert_true(state.options == options)
        test.assert_equal('creatures:miners', constructed.settings_id)
        test.assert_equal('creatures:miners', constructed.settings.settings_id)
    end)

    test.case('UI input: child handling precedes global fallback handling', function()
        local _, _, _, main_window =
            soulsearch_env.load_ui_characterization(repo_root)
        local super_calls, refreshes = 0, 0
        main_window.SoulSearchWindow.super = {
            onInput=function()
                super_calls = super_calls + 1
                return true
            end,
        }
        local window = {
            refresh_residents=function() refreshes = refreshes + 1 end,
        }
        test.assert_true(main_window.SoulSearchWindow.onInput(
            window, {CUSTOM_R=true}))
        test.assert_equal(1, super_calls)
        test.assert_equal(0, refreshes)
    end)
end
