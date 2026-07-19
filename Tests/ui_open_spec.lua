local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('UI open', function()

    it('UI open: unavailable context prints reason without constructing a screen', function()
        local ui = soulsearch_env.load_ui_open_guard(
            repo_root, 'SoulSearch requires a loaded fortress.')
        local printed = {}
        local original_print = _G.print
        _G.print = function(value) table.insert(printed, value) end
        local ok, err = pcall(ui.open)
        _G.print = original_print

        assert.is_truthy(ok, tostring(err))
        assert.are.same(
            {'SoulSearch requires a loaded fortress.'}, printed)
    end)

    it('UI reload teardown: dismisses zero, one, and multiple screens safely', function()
        local ui, registry = soulsearch_env.load_ui_open_guard(repo_root, nil)
        registry.clear()

        ui.dismiss_all()
        assert.are.equal(0, registry.count())

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
        assert.are.equal(1, one.dismiss_count)
        assert.are.equal(0, registry.count())

        local first = registered_screen('first')
        local second = registered_screen('second')
        local third = registered_screen('third')
        ui.dismiss_all()
        assert.are.equal(1, first.dismiss_count)
        assert.are.equal(1, second.dismiss_count)
        assert.are.equal(1, third.dismiss_count)
        assert.are.equal(0, registry.count())

        ui.dismiss_all()
        assert.are.equal(4, #dismissals)
    end)

    it('UI open: scoped options construct one new screen', function()
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

        assert.is_truthy(screen ~= nil)
        assert.is_truthy(state.options == options)
        assert.are.equal('creatures:miners', constructed.settings_id)
        assert.are.equal('creatures:miners', constructed.settings.settings_id)
    end)

    it('UI input: child handling precedes global fallback handling', function()
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
        assert.is_truthy(main_window.SoulSearchWindow.onInput(
            window, {CUSTOM_R=true}))
        assert.are.equal(1, super_calls)
        assert.are.equal(0, refreshes)
    end)

end)
