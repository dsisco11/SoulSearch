local gui = require('gui')
local widgets = require('gui.widgets')
local SearchablePicker =
    reqscript('internal/soulsearch/ui/searchable_picker').SearchablePicker
local PresetPicker = reqscript('internal/soulsearch/ui/preset_picker').PresetPicker
local ModalPanelWindow =
    reqscript('internal/soulsearch/ui/modal_panel').ModalPanelWindow
local pointer_adapter = require('dwarfspec.automation.pointer_adapter')

---@class tests.RightClickConsumer: widgets.Panel
---@field on_right_click fun()
local RightClickConsumer = defclass(nil, widgets.Panel)
RightClickConsumer.ATTRS{on_right_click=DEFAULT_NIL, consume=false}

---Consumes right-click input to verify modal child-input priority.
---@param keys table
---@return boolean
function RightClickConsumer:onInput(keys)
    if keys._MOUSE_R and self.consume then
        self.on_right_click()
        return true
    end
    return RightClickConsumer.super.onInput(self, keys)
end

---@class tests.BlankModalArea: widgets.Panel
local BlankModalArea = defclass(nil, widgets.Panel)

---Leaves pointer input for the modal window to handle.
---@param keys table
---@return boolean
function BlankModalArea:onInput(keys)
    return false
end

---@class tests.SearchablePickerScreen: gui.ZScreen
---@field picker_kind string
---@field choices table[]
---@field callbacks table
local SearchablePickerScreen = defclass(nil, gui.ZScreen)
SearchablePickerScreen.ATTRS{
    picker_kind='attribute',
    choices=DEFAULT_NIL,
    callbacks=DEFAULT_NIL,
    focus_path='soulsearch/picker-test',
}

---Builds a real searchable picker above a control that must remain blocked.
function SearchablePickerScreen:init()
    local inputs = self.callbacks
    self.underlay = widgets.TextButton{
        view_id='underlay', frame={l=20, t=2, w=30, h=1}, label='Underlay',
        on_activate=inputs.on_underlay,
    }
    self.open_button = widgets.TextButton{
        view_id='open_picker', frame={l=0, t=0, w=14, h=1}, label='Open picker',
        on_activate=function() self.picker:open() end,
    }
    self.picker = SearchablePicker{
        view_id='picker', frame={l=20, t=2, w=34, h=3}, kind=self.picker_kind,
        inputs={
            on_query=inputs.on_query,
            on_close=inputs.on_close,
            on_submit=inputs.on_submit,
        },
    }
    self:addviews{self.underlay, self.open_button, self.picker}
    self.picker:addviews{
        RightClickConsumer{view_id='right_click_consumer',
            frame={l=12, t=1, w=10, h=1},
            on_right_click=self.callbacks.on_right_click},
        BlankModalArea{view_id='modal_blank', frame={l=0, t=1, w=8, h=1}},
    }
    self.picker:set_choices(self.choices, 1)
end

---Returns IDs for one searchable-picker kind.
---@param kind string
---@return string search_id
---@return string list_id
---@return string close_id
local function searchable_ids(kind)
    local ids = {
        attribute={'attribute_search_field', 'available_filter_list',
            'close_filter_picker_button'},
        race={'race_search_field', 'available_race_list',
            'close_race_picker_button'},
        unit_scope={'unit_scope_search_field', 'available_unit_scope_list',
            'close_unit_scope_picker_button'},
    }
    local kind_ids = assert(ids[kind], 'unsupported picker kind: ' .. kind)
    return table.unpack(kind_ids)
end

---Creates the callback table consumed by one searchable-picker screen.
---@return table callbacks
local function searchable_callbacks()
    local callbacks = {
        on_underlay=spy.new(function() end),
        on_query=spy.new(function() end),
        on_close=spy.new(function() end),
        on_right_click=spy.new(function() end),
    }
    callbacks.on_submit = spy.new(function(choice)
        callbacks.submitted_choice = choice
    end)
    return callbacks
end

---Mounts a searchable picker with one selected choice.
---@param kind string
---@param choice table
---@return table callbacks
local function mount_searchable_picker(kind, choice)
    local callbacks = searchable_callbacks()
    ds.mount(SearchablePickerScreen{
        picker_kind=kind,
        choices={choice},
        callbacks=callbacks,
    })
    return callbacks
end

---@class tests.PresetPickerScreen: gui.ZScreen
---@field choices table[]
---@field callbacks table
local PresetPickerScreen = defclass(nil, gui.ZScreen)
PresetPickerScreen.ATTRS{choices=DEFAULT_NIL, callbacks=DEFAULT_NIL,
    focus_path='soulsearch/preset-picker-test'}

---Builds a real preset picker above a control that must remain blocked.
function PresetPickerScreen:init()
    self.underlay = widgets.TextButton{view_id='underlay',
        frame={l=20, t=2, w=30, h=1}, label='Underlay',
        on_activate=self.callbacks.on_underlay}
    self.open_button = widgets.TextButton{view_id='open_preset',
        frame={l=0, t=0, w=14, h=1}, label='Open preset',
        on_activate=function() self.picker:open() end}
    self.picker = PresetPicker{view_id='preset_picker',
        frame={l=20, t=2, w=34, h=4}, inputs=self.callbacks}
    self:addviews{self.underlay, self.open_button, self.picker}
    self.picker.subviews.preset_list:setChoices(self.choices, 1)
end

---Creates preset-picker callbacks with spies for every route.
---@return table callbacks
local function preset_callbacks()
    return {on_underlay=spy.new(function() end), on_close=spy.new(function() end),
        on_save=spy.new(function() end), on_query=spy.new(function() end),
        on_load=spy.new(function() end), on_load_default=spy.new(function() end),
        on_load_role=spy.new(function() end)}
end

---Mounts a preset picker containing one selected choice.
---@param choice table
---@return table callbacks
local function mount_preset_picker(choice)
    local callbacks = preset_callbacks()
    ds.mount(PresetPickerScreen{choices={choice}, callbacks=callbacks})
    return callbacks
end

---@class tests.ModalPriorityScreen: gui.ZScreen
---@field callbacks table
local ModalPriorityScreen = defclass(nil, gui.ZScreen)
ModalPriorityScreen.ATTRS{callbacks=DEFAULT_NIL,
    focus_path='soulsearch/modal-priority-test'}

---Builds a minimal modal with explicit consuming and delegating children.
function ModalPriorityScreen:init()
    self.open_button = widgets.TextButton{view_id='open_modal',
        frame={l=0, t=0, w=12, h=1}, label='Open modal',
        on_activate=function() self.modal:open() end}
    self.modal = ModalPanelWindow{view_id='priority_modal',
        frame={l=20, t=2, w=30, h=3}}
    self.modal:addviews{
        RightClickConsumer{view_id='right_click_consumer',
            frame={l=12, t=1, w=10, h=1},
            on_right_click=self.callbacks.on_right_click},
        BlankModalArea{view_id='modal_blank', frame={l=0, t=1, w=8, h=1}},
    }
    self:addviews{self.open_button, self.modal}
end

---Mounts a minimal modal for right-click dispatch coverage.
---@return table callbacks
local function mount_priority_modal()
    local callbacks = {on_right_click=spy.new(function() end)}
    ds.mount(ModalPriorityScreen{callbacks=callbacks})
    return callbacks
end

describe('SoulSearch modal panels and pickers', function()
    it('opens a searchable picker visibly and focuses its search field', function()
        mount_searchable_picker('attribute', {
            text='Patience', descriptor={id='trait:PATIENCE', kind='trait', key='PATIENCE'},
        })
        local search_id = searchable_ids('attribute')

        ds.get('open_picker'):click()

        assert.is_true(ds.get('picker'):inspect().visible)
        assert.is_true(ds.get('picker/' .. search_id):inspect().focused)
    end)

    it('types queries, submits descriptors, and remains open for another selection', function()
        local descriptor = {id='trait:PATIENCE', kind='trait', key='PATIENCE'}
        local callbacks = mount_searchable_picker('attribute', {
            text='Patience', descriptor=descriptor,
        })
        local search_id, list_id = searchable_ids('attribute')

        ds.get('open_picker'):click()
        ds.get('picker/' .. search_id):type('pat')
        assert.equals(1, ds.get('picker/' .. list_id):raw():getSelected())
        -- DwarfSpec has no focus-transfer operation for list controls.
        ds.get('picker/' .. list_id):raw():submit()

        assert.spy(callbacks.on_query).was_called_with('pat', 'pa')
        assert.equals('pat', ds.get('picker/' .. search_id):inspect().text)
        assert.spy(callbacks.on_submit).was_called()
        assert.equals(descriptor.id, callbacks.submitted_choice.descriptor.id)
        assert.is_true(ds.get('picker'):inspect().visible)
    end)

    it('closes from its close button and consumes pointer input over the underlay', function()
        local callbacks = mount_searchable_picker('attribute', {
            text='Patience', descriptor={id='trait:PATIENCE', kind='trait', key='PATIENCE'},
        })
        ds.get('open_picker'):click()
        ds.get('picker'):click()
        assert.spy(callbacks.on_underlay).was_not_called()
        local close_button = ds.get('picker/close_filter_picker_button')
        close_button:raw().label.on_activate()
        assert.is_false(ds.get('picker'):inspect().visible)
    end)

    it('gives child right-click handlers priority before dismissing from a blank area', function()
        local callbacks = mount_priority_modal()
        ds.get('open_modal'):click()
        local consumer = ds.get('priority_modal/right_click_consumer')
        consumer:raw().consume = true
        consumer:raw():setFocus(true)
        consumer:input('_MOUSE_R')
        assert.spy(callbacks.on_right_click).was_called()
        assert.is_true(ds.get('priority_modal'):inspect().visible)
        consumer:raw().consume = false
        consumer:raw():setFocus(false)
        local blank = ds.get('priority_modal/modal_blank')
        blank:move_pointer()
        local body = blank:raw().frame_body
        local x = math.floor((body.x1 + body.x2) / 2)
        local y = math.floor((body.y1 + body.y2) / 2)
        pointer_adapter.with_interface_mouse(x, y, function()
            ds.get('priority_modal'):raw():onInput({_MOUSE_R=true})
        end)
        assert.is_false(ds.get('priority_modal'):inspect().visible)
    end)

    it('renders attribute, race, and unit-scope tooltips on hovered rows', function()
        local cases = {
            {kind='attribute', descriptor={id='trait:PATIENCE', kind='trait', key='PATIENCE'},
                tooltip='A personality trait that shapes behavior and social interaction.'},
            {kind='race', descriptor={id='race:DWARF', kind='race', key='DWARF'},
                tooltip='Filters by a creatures race.'},
            {kind='unit_scope', descriptor={id='unit_scope:citizens', kind='unit_scope', key='citizens'},
                tooltip='Filters which active units are considered.'},
        }
        for _, case in ipairs(cases) do
            mount_searchable_picker(case.kind, {text='Choice', descriptor=case.descriptor})
            local _, list_id = searchable_ids(case.kind)
            ds.get('open_picker'):click()
            local list = ds.get('picker/' .. list_id)
            list:move_pointer()
            list:raw().on_pointer_update(list:raw(), 0, 0)
            assert.equals(case.tooltip, list:raw().tooltip)
            ds.unmount()
        end
    end)

    it('routes custom, default, and role preset selections', function()
        local cases = {
            {choice={text='Custom', name='custom'}, callback='on_load', value='custom'},
            {choice={text='Default', default_id='default'}, callback='on_load_default', value='default'},
            {choice={text='Role', role_id='miner'}, callback='on_load_role', value='miner'},
        }
        for _, case in ipairs(cases) do
            local callbacks = mount_preset_picker(case.choice)
            ds.get('open_preset'):click()
            ds.get('preset_picker/preset_list'):raw():submit()
            assert.spy(callbacks[case.callback]).was_called_with(case.value)
            ds.unmount()
        end
    end)

    it('saves presets without clearing the entered search text', function()
        local callbacks = mount_preset_picker({text='Custom', name='custom'})
        ds.get('open_preset'):click()
        ds.get('preset_picker/preset_search_field'):type('miners')
        ds.get('preset_picker/save_preset_button'):raw().label.on_activate()
        assert.spy(callbacks.on_save).was_called()
        assert.equals('miners', ds.get('preset_picker/preset_search_field'):inspect().text)
    end)
end)
