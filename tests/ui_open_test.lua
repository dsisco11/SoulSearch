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
        local ui, _, state = soulsearch_env.load_ui_open_guard(repo_root, nil)
        local constructed
        ui.SoulSearchScreen = setmetatable({}, {
            __call=function(_, attributes)
                constructed = attributes
                return {show=function(self) return self end}
            end,
        })
        local options = {
            settings_id='creatures:miners',
            filters={{id='skill:MINING', direction='high'}},
            unit_scope='fort_residents',
        }
        local screen = ui.open(options)

        test.assert_true(screen ~= nil)
        test.assert_true(state.options == options)
        test.assert_equal('creatures:miners', constructed.settings_id)
        test.assert_equal('creatures:miners', constructed.settings.settings_id)
    end)

    test.case('UI Stats sort: transitions and persistence match the current window', function()
        local ui = soulsearch_env.load_ui_open_guard(repo_root, nil)
        local changes, refreshes = {}, {}
        local window = {
            stats_sort_key=nil,
            stats_sort_reverse=false,
            stats_sort_phase=0,
            update_session_settings=function(_, change)
                table.insert(changes, change.stats_sort)
            end,
            refresh_views=function(_, request) table.insert(refreshes, request) end,
        }
        local function cycle(column, key, reverse, phase)
            ui.SoulSearchWindow.cycle_stats_sort(window, column)
            test.assert_equal(key, window.stats_sort_key)
            test.assert_equal(reverse, window.stats_sort_reverse)
            test.assert_equal(phase, window.stats_sort_phase)
        end

        cycle('label', 'label', false, 1)
        cycle('label', 'label', true, 2)
        cycle('label', nil, false, 0)
        cycle('value', 'value', true, 1)
        cycle('value', 'value', false, 2)
        cycle('value', nil, false, 0)
        test.assert_equal(6, #changes)
        test.assert_equal(6, #refreshes)
        for _, request in ipairs(refreshes) do
            test.assert_true(request.stats)
        end
    end)

    test.case('UI input: child handling precedes global fallback handling', function()
        local ui = soulsearch_env.load_ui_open_guard(repo_root, nil)
        local super_calls, refreshes = 0, 0
        ui.SoulSearchWindow.super = {
            onInput=function()
                super_calls = super_calls + 1
                return true
            end,
        }
        local window = {
            refresh_residents=function() refreshes = refreshes + 1 end,
        }
        test.assert_true(ui.SoulSearchWindow.onInput(window, {CUSTOM_R=true}))
        test.assert_equal(1, super_calls)
        test.assert_equal(0, refreshes)
    end)
end
