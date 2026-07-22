local SoulSearchScreen =
    reqscript('internal/soulsearch/ui/main_screen').SoulSearchScreen
local filter_presets = reqscript('internal/soulsearch/filter_presets')

local original_list = filter_presets.list

---@class tests.SoulSearchMainScreen: SoulSearchScreen
local MainScreen = defclass(nil, SoulSearchScreen)
MainScreen.ATTRS{focus_path='soulsearch/main-screen-test'}

---Mounts a complete SoulSearch screen with normal production initialization.
---@return tests.SoulSearchMainScreen screen
local function mount_screen()
    ds.mount(MainScreen)
    return ds.root():raw()
end

describe('SoulSearch complete screen', function()
    before_each(function()
        -- The installed DFHack script-manager path helper is incompatible
        -- with this host build; persistence is outside this screen contract.
        filter_presets.list = function() return {} end
    end)

    after_each(function()
        filter_presets.list = original_list
    end)

    it('mounts, renders, and exposes the production panel hierarchy', function()
        mount_screen()
        assert.is_true(ds.get('window'):inspect().visible)
        assert.is_not_nil(ds.get('window/results_panel'))
        assert.is_not_nil(ds.get('window/filter_panel_window'))
        assert.is_not_nil(ds.get('window/stats_panel'))
    end)

    it('gives search focus and routes result navigation through the complete screen', function()
        mount_screen()
        ds.get('window/results_panel/search_field'):click()
        assert.is_true(ds.get('window/results_panel/search_field'):inspect().focused)
        ds.get('window'):input('KEYBOARD_CURSOR_DOWN')
        assert.is_not_nil(ds.get('window/results_panel/result_list'):raw():getSelected())
    end)

    it('gives filter modal controls priority over the result list', function()
        mount_screen()
        ds.get('window/filters_button'):raw().label.on_activate()
        assert.is_true(ds.get('window/filter_panel_window'):inspect().visible)
        ds.get('window/filter_panel_window/add_filter_button'):raw().label.on_activate()
        assert.is_true(ds.get('window/filter_panel_window/available_filter_window'):inspect().visible)
        assert.is_false(ds.get('window/filter_panel_window/filter_list'):raw().visible())
    end)

    it('cleans up idempotently when dismissed and destroyed', function()
        local screen = mount_screen()
        assert.is_true(screen:cleanup())
        assert.is_false(screen:cleanup())
    end)
end)
