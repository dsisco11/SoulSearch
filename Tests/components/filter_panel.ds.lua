local gui = require('gui')
local widgets = require('gui.widgets')
local FilterPanel = reqscript('internal/soulsearch/ui/filter_panel').FilterPanel

---@class tests.FilterPanelScreen: gui.ZScreen
---@field panel FilterPanel
---@field callbacks table
local FilterPanelScreen = defclass(nil, gui.ZScreen)
FilterPanelScreen.ATTRS{callbacks=DEFAULT_NIL,
    focus_path='soulsearch/filter-panel-test'}

---Builds the production filter panel with callbacks that refresh visible state.
function FilterPanelScreen:init()
    local callbacks = self.callbacks
    callbacks.on_toggle_filter = spy.new(function(filter_id)
        self.panel:set_active_filter_choices({{
            text=filter_id,
            descriptor={id=filter_id, kind='trait', key='PATIENCE'},
        }}, 1)
    end)
    self.open_button = widgets.TextButton{view_id='open_filter_panel',
        frame={l=0, t=0, w=18, h=1}, label='Open filters',
        on_activate=function() self.panel:open() end}
    self.panel = FilterPanel{view_id='filter_panel',
        frame={l=1, t=2, w=53, h=8}, inputs=callbacks}
    self:addviews{self.open_button, self.panel}
    self.panel:set_active_filter_choices({{
        text='Patience', descriptor={id='trait:PATIENCE', kind='trait', key='PATIENCE'},
    }}, 1)
    self.panel:set_picker_choices('attribute', {{text='Bravery',
        descriptor={id='trait:BRAVERY', kind='trait', key='BRAVERY'}}}, 1)
    self.panel:set_picker_choices('skill', {{text='Mining',
        descriptor={id='skill:MINING', kind='skill', key='MINING'}}}, 1)
    self.panel:set_picker_choices('race', {{text='Dwarf',
        descriptor={id='race:DWARF', kind='race', key='DWARF'}}}, 1)
    self.panel:set_picker_choices('unit_scope', {{text='Citizens',
        descriptor={id='unit_scope:citizens', kind='unit_scope', key='citizens'}}}, 1)
    self.panel:set_preset_choices({{text='Custom', name='custom'}})
end

---Creates spies for every FilterPanel host callback.
---@return table callbacks
local function panel_callbacks()
    return {
        on_clear=spy.new(function() end), on_refresh=spy.new(function() end),
        on_preset_query=spy.new(function() end), on_save_preset=spy.new(function() end),
        on_load_preset=spy.new(function() end),
        on_load_default_preset=spy.new(function() end),
        on_load_role_preset=spy.new(function() end),
        on_attribute_query=spy.new(function() end),
        on_skill_query=spy.new(function() end), on_race_query=spy.new(function() end),
        on_unit_scope_query=spy.new(function() end),
        on_filter_action=spy.new(function() end),
    }
end

---Mounts the FilterPanel component fixture.
---@return table callbacks
local function mount_filter_panel()
    local callbacks = panel_callbacks()
    ds.mount(FilterPanelScreen{callbacks=callbacks})
    return callbacks
end

---Opens one FilterPanel child picker through its production toggle method.
---@param kind string
local function open_picker(kind)
    ds.get('filter_panel'):raw():toggle_picker(kind)
end

describe('SoulSearch Filter Panel', function()
    it('opens with active filters and refreshes picker and preset choices', function()
        local callbacks = mount_filter_panel()
        ds.get('open_filter_panel'):click()
        assert.is_true(ds.get('filter_panel'):inspect().visible)
        assert.equals(1, ds.get('filter_panel/filter_list'):raw():getSelected())
        assert.spy(callbacks.on_refresh).was_called_with({pickers=true, presets=true})
    end)

    it('opens each picker, closes the previous picker, and hides the filter list', function()
        mount_filter_panel()
        ds.get('open_filter_panel'):click()
        for _, kind in ipairs({'attribute', 'skill', 'race', 'unit_scope', 'preset'}) do
            open_picker(kind)
            assert.is_true(ds.get('filter_panel'):raw():is_picker_open(kind))
            assert.is_false(ds.get('filter_panel/filter_list'):raw().visible())
        end
        assert.is_false(ds.get('filter_panel'):raw():is_picker_open('attribute'))
        assert.is_true(ds.get('filter_panel'):raw():is_picker_open('preset'))
    end)

    it('updates the visible active-filter list after picker selection and closes pickers with the panel', function()
        local callbacks = mount_filter_panel()
        ds.get('open_filter_panel'):click()
        open_picker('attribute')
        ds.get('filter_panel/available_filter_window/available_filter_list'):raw():submit()
        assert.spy(callbacks.on_toggle_filter).was_called_with('trait:BRAVERY')
        local _, selected = ds.get('filter_panel/filter_list'):raw():getSelected()
        assert.equals('trait:BRAVERY', selected.descriptor.id)
        ds.get('filter_panel'):raw():close()
        assert.is_false(ds.get('filter_panel/available_filter_window'):inspect().visible)
    end)

    it('dispatches reset through its visible panel control', function()
        local callbacks = mount_filter_panel()
        ds.get('open_filter_panel'):click()
        ds.get('filter_panel/clear_filters_button'):raw().label.on_activate()
        assert.spy(callbacks.on_clear).was_called()
    end)

    it('opens the attribute picker through its keyboard shortcut', function()
        mount_filter_panel()
        ds.get('open_filter_panel'):click()
        ds.get('filter_panel'):input('CUSTOM_A')
        assert.is_true(ds.get('filter_panel'):raw():is_picker_open('attribute'))
    end)
end)
