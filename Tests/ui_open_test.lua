local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('UI open: unavailable context prints reason without constructing a screen', function()
        local ui = soulsearch_env.load_ui_open_guard(
            repo_root, 'SoulSearch requires a loaded fortress.')
        local printed = {}
        local original_print = print
        print = function(value) table.insert(printed, value) end
        local ok, err = pcall(ui.open)
        print = original_print

        luaunit.assertEvalToTrue(ok, tostring(err))
        luaunit.assertEquals(
            {'SoulSearch requires a loaded fortress.'}, printed)
    end)

    add_test('UI reload teardown: dismisses zero, one, and multiple screens safely', function()
        local ui, registry = soulsearch_env.load_ui_open_guard(repo_root, nil)
        registry.clear()

        ui.dismiss_all()
        luaunit.assertIs(0, registry.count())

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
        luaunit.assertIs(1, one.dismiss_count)
        luaunit.assertIs(0, registry.count())

        local first = registered_screen('first')
        local second = registered_screen('second')
        local third = registered_screen('third')
        ui.dismiss_all()
        luaunit.assertIs(1, first.dismiss_count)
        luaunit.assertIs(1, second.dismiss_count)
        luaunit.assertIs(1, third.dismiss_count)
        luaunit.assertIs(0, registry.count())

        ui.dismiss_all()
        luaunit.assertIs(4, #dismissals)
    end)

    add_test('UI open: scoped options construct one new screen', function()
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

        luaunit.assertEvalToTrue(screen ~= nil)
        luaunit.assertEvalToTrue(state.options == options)
        luaunit.assertIs('creatures:miners', constructed.settings_id)
        luaunit.assertIs('creatures:miners', constructed.settings.settings_id)
    end)

    add_test('UI input: child handling precedes global fallback handling', function()
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
        luaunit.assertEvalToTrue(main_window.SoulSearchWindow.onInput(
            window, {CUSTOM_R=true}))
        luaunit.assertIs(1, super_calls)
        luaunit.assertIs(0, refreshes)
    end)

return native_tests
