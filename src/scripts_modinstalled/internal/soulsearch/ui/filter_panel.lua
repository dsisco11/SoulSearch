--@ module=true

local widgets = require('gui.widgets')
local ui_format = reqscript('internal/soulsearch/ui_format')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local attribute_descriptions =
    reqscript('internal/soulsearch/attribute_descriptions')
local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS
local ModalPanelWindow =
    reqscript('internal/soulsearch/ui/modal_panel').ModalPanelWindow
local FilterActionList =
    reqscript('internal/soulsearch/ui/filter_action_list').FilterActionList
local searchable_picker =
    reqscript('internal/soulsearch/ui/searchable_picker')
local preset_picker = reqscript('internal/soulsearch/ui/preset_picker')
local unit_scope_picker = reqscript('internal/soulsearch/ui/unit_scope_picker')

local FILTER_KIND_RACE = filter_constants.kind.RACE

local FILTER_CONTROL_TOOLTIPS = {
    {id='close_filter_panel_button', text='Close'},
    {id='unit_scope_edit', text='Choose which units are included in the results.'},
    {id='add_filter_button', text='Add an attribute or trait to the ranking criteria.'},
    {id='add_skill_button', text='Add a skill to the ranking criteria.'},
    {id='add_race_button', text='Add a race to the candidate scope.'},
    {id='preset_button', text='Save the current filters or load a custom, role, or skill preset.'},
    {id='save_preset_button', text='Save the current ordered filters under this preset name.'},
    {id='close_preset_picker_button', text='Close'},
    {id='close_filter_picker_button', text='Close'},
    {id='close_skill_picker_button', text='Close'},
    {id='close_race_picker_button', text='Close'},
}

local function is_visible(view)
    while view do
        if type(view.visible) == 'function' then
            if not view.visible() then return false end
        elseif not view.visible then
            return false
        end
        view = view.parent_view
    end
    return true
end

local function is_mouse_over(view)
    local rect = view and view.frame_body
    local x, y = dfhack.screen.getMousePos()
    return rect and x and is_visible(view) and rect:inClipGlobalXY(x, y)
end

local function get_descriptor_tooltip(list, choices)
    local index = list and list:getIdxUnderMouse()
    local descriptor = index and choices and choices[index] and choices[index].descriptor
    if descriptor and descriptor.kind == FILTER_KIND_RACE then
        return 'Filters by a creatures race.'
    end
    return descriptor and attribute_descriptions.get_tooltip(
        descriptor.kind, descriptor.key) or nil
end

local function get_subview(panel, id)
    return panel.subviews[id] or
        (panel.parent_view and panel.parent_view.subviews[id])
end

---@class FilterPanel: ModalPanelWindow
---@field inputs SoulSearchFilterPanelInputs
---@field active_filter_choices table[]|nil
---@field picker_choices table<string, table[]>
FilterPanel = defclass(FilterPanel, ModalPanelWindow)

function FilterPanel:init(info)
    FilterPanel.super.init(self, info)
    self.inputs = info.inputs
    self.picker_choices = {}
end

---@param choices table[]
---@param selected integer|nil
function FilterPanel:set_active_filter_choices(choices, selected)
    self.active_filter_choices = choices
    get_subview(self, 'filter_list'):setChoices(choices, selected)
end

---@param kind 'attribute'|'skill'|'race'
---@param choices table[]
---@param selected integer|nil
function FilterPanel:set_picker_choices(kind, choices, selected)
    local ids = {
        attribute='available_filter_list', skill='available_skill_list',
        race='available_race_list',
    }
    self.picker_choices[kind] = choices
    get_subview(self, ids[kind]):setChoices(choices, selected)
end

---@param choices table[]
function FilterPanel:set_preset_choices(choices)
    get_subview(self, 'preset_list'):setChoices(choices)
end

---@param choices table[]
---@param selected integer|nil
---@param label string|nil
function FilterPanel:set_unit_scope_choices(choices, selected, label)
    get_subview(self, 'unit_scope_picker_list'):setChoices(choices, selected)
    get_subview(self, 'unit_scope_label'):setText(
        ui_format.format_unit_scope_control(label))
end

---@return string|nil
function FilterPanel:get_control_tooltip()
    for _, tooltip in ipairs(FILTER_CONTROL_TOOLTIPS) do
        if is_mouse_over(get_subview(self, tooltip.id)) then return tooltip.text end
    end
end

---@return string|nil
function FilterPanel:get_filter_action_tooltip()
    local inputs = self.inputs
    if not self:is_open() or inputs.is_attribute_picker_open() or
            inputs.is_skill_picker_open() or inputs.is_race_picker_open() or
            inputs.is_preset_picker_open() then
        return nil
    end
    local index, _, action = get_subview(self, 'filter_list'):getActionUnderMouse()
    local choice = index and self.active_filter_choices and
        self.active_filter_choices[index]
    if not choice then return nil end
    local descriptor = choice.descriptor
    if descriptor and descriptor.kind == FILTER_KIND_RACE and action then
        if action.callback == 'set_high' then return 'Include in results.' end
        if action.callback == 'set_low' then return 'Exclude from results.' end
        if action.callback == 'move_up' or action.callback == 'move_down' then
            return nil
        end
    end
    return action and action.tooltip or nil
end

---@return string|nil
function FilterPanel:get_descriptor_tooltip()
    local inputs = self.inputs
    if not self:is_open() or inputs.is_preset_picker_open() then return nil end
    if inputs.is_attribute_picker_open() then
        return get_descriptor_tooltip(get_subview(self, 'available_filter_list'),
            self.picker_choices.attribute)
    end
    if inputs.is_skill_picker_open() then return nil end
    if inputs.is_race_picker_open() then
        return get_descriptor_tooltip(get_subview(self, 'available_race_list'),
            self.picker_choices.race)
    end
    local list = get_subview(self, 'filter_list')
    local x = list and list:getMousePos()
    if ui_layout.get_filter_action_at_x(x) then return nil end
    return get_descriptor_tooltip(list, self.active_filter_choices)
end

---@class SoulSearchFilterPanelInputs
---@field is_filter_panel_open fun(): boolean
---@field on_open_filter_panel fun()
---@field on_close_filter_panel_state fun()
---@field on_close_filter_panel fun()
---@field is_attribute_picker_open fun(): boolean
---@field is_skill_picker_open fun(): boolean
---@field is_race_picker_open fun(): boolean
---@field is_unit_scope_picker_open fun(): boolean
---@field unit_scope SoulSearchUnitScope
---@field unit_scope_options {label: string, value: SoulSearchUnitScope}[]
---@field on_unit_scope_change fun(scope: SoulSearchUnitScope)
---@field on_toggle_unit_scope_picker fun()
---@field on_toggle_attribute_picker fun()
---@field on_toggle_skill_picker fun()
---@field on_toggle_race_picker fun()
---@field on_clear fun()
---@field is_preset_picker_open fun(): boolean
---@field on_toggle_preset_picker fun()
---@field on_close_preset_picker fun()
---@field on_preset_query fun(text: string)
---@field on_save_preset fun()
---@field on_load_preset fun(name: string)
---@field on_load_default_preset fun(id: string)
---@field on_load_role_preset fun(id: string)
---@field on_close_picker fun()
---@field on_attribute_query fun(text: string)
---@field on_skill_query fun(text: string)
---@field on_race_query fun(text: string)
---@field on_add fun(filter_id: string)
---@field on_filter_action fun(filter_id: string, action: string)

---@param inputs SoulSearchFilterPanelInputs
---@return FilterPanel
function create(inputs)
    local unit_scope_label
    for _, option in ipairs(inputs.unit_scope_options) do
        if option.value == inputs.unit_scope then unit_scope_label = option.label break end
    end
    return FilterPanel{
        view_id='filter_panel_window', frame=ui_layout.get_frame('filter_panel'),
        frame_title='Search filters', draggable=false,
        visible=inputs.is_filter_panel_open, is_open=inputs.is_filter_panel_open,
        on_open=inputs.on_open_filter_panel, on_close=inputs.on_close_filter_panel_state,
        inputs=inputs,
        subviews={
            widgets.TextButton{view_id='close_filter_panel_button',
                frame=ui_layout.get_frame('filter_panel_close'), label='X',
                on_activate=inputs.on_close_filter_panel},
            widgets.Label{view_id='unit_scope_label', frame=ui_layout.get_frame('unit_scope'),
                text=ui_format.format_unit_scope_control(unit_scope_label)},
            widgets.TextButton{view_id='unit_scope_edit', frame=ui_layout.get_frame('unit_scope_edit'),
                label='Edit', on_activate=inputs.on_toggle_unit_scope_picker},
            widgets.TextButton{view_id='add_filter_button', frame=ui_layout.get_frame('add_filter'),
                key='CUSTOM_A', label='Add attribute filter', on_activate=inputs.on_toggle_attribute_picker},
            widgets.TextButton{view_id='add_skill_button', frame=ui_layout.get_frame('add_skill'),
                key='CUSTOM_S', label='Add skill filter', on_activate=inputs.on_toggle_skill_picker},
            widgets.TextButton{view_id='add_race_button', frame=ui_layout.get_frame('add_race'),
                key='CUSTOM_G', label='Add race filter', on_activate=inputs.on_toggle_race_picker},
            widgets.TextButton{view_id='clear_filters_button', frame=ui_layout.get_frame('clear_filters'),
                key='CUSTOM_C', label='Clear filters', on_activate=inputs.on_clear},
            widgets.TextButton{view_id='preset_button', frame=ui_layout.get_frame('presets'),
                key='CUSTOM_P', label='Filter presets', on_activate=inputs.on_toggle_preset_picker},
            FilterActionList{view_id='filter_list', frame=ui_layout.get_frame('filter_list'),
                visible=function()
                    return not inputs.is_attribute_picker_open() and not inputs.is_skill_picker_open() and
                        not inputs.is_race_picker_open() and not inputs.is_unit_scope_picker_open() and
                        not inputs.is_preset_picker_open()
                end, on_filter_action=inputs.on_filter_action},
            searchable_picker.SearchablePicker{view_id='available_filter_window',
                frame=ui_layout.get_frame('picker'), frame_title='Select attribute/trait',
                draggable=false, visible=inputs.is_attribute_picker_open, inputs={
                window_id='available_filter_window', list_id='available_filter_list',
                search_id='attribute_search_field', close_id='close_filter_picker_button',
                title='Select attribute/trait', visible=inputs.is_attribute_picker_open, key='CUSTOM_T',
                on_query=inputs.on_attribute_query, on_close=inputs.on_close_picker,
                on_submit=function(choice) if choice and choice.descriptor then inputs.on_add(choice.descriptor.id) end end}},
            searchable_picker.SearchablePicker{view_id='available_race_window',
                frame=ui_layout.get_frame('picker'), frame_title='Select race',
                draggable=false, visible=inputs.is_race_picker_open, inputs={
                window_id='available_race_window', list_id='available_race_list',
                search_id='race_search_field', close_id='close_race_picker_button', title='Select race',
                visible=inputs.is_race_picker_open, key='CUSTOM_G', on_query=inputs.on_race_query,
                on_close=inputs.on_close_picker,
                on_submit=function(choice) if choice and choice.descriptor then inputs.on_add(choice.descriptor.id) end end}},
            searchable_picker.SearchablePicker{view_id='available_skill_window',
                frame=ui_layout.get_frame('picker'), frame_title='Select skill',
                draggable=false, visible=inputs.is_skill_picker_open, inputs={
                window_id='available_skill_window', list_id='available_skill_list',
                search_id='skill_search_field', close_id='close_skill_picker_button', title='Select skill',
                visible=inputs.is_skill_picker_open, key='CUSTOM_K', on_query=inputs.on_skill_query,
                on_close=inputs.on_close_picker,
                on_submit=function(choice) if choice and choice.descriptor then inputs.on_add(choice.descriptor.id) end end}},
            preset_picker.PresetPicker{view_id='preset_picker_window',
                frame=ui_layout.get_frame('preset_picker'), frame_title='Filter presets',
                draggable=false, visible=inputs.is_preset_picker_open, inputs={
                visible=inputs.is_preset_picker_open,
                on_close=inputs.on_close_preset_picker, on_save=inputs.on_save_preset,
                on_query=inputs.on_preset_query, on_load=inputs.on_load_preset,
                on_load_default=inputs.on_load_default_preset, on_load_role=inputs.on_load_role_preset}},
            unit_scope_picker.UnitScopePicker{view_id='unit_scope_picker_window',
                frame=ui_layout.get_unit_scope_picker_frame(#inputs.unit_scope_options),
                frame_title='Search scope', draggable=false,
                visible=inputs.is_unit_scope_picker_open, inputs={
                visible=inputs.is_unit_scope_picker_open,
                options=inputs.unit_scope_options, on_select=inputs.on_unit_scope_change}},
        },
    }
end

---@param on_activate fun()
---@return table
function create_button(on_activate)
    return widgets.TextButton{view_id='filters_button', frame=ui_layout.get_frame('filters_button'),
        label='Edit', text_pen=COLOR_YELLOW, on_activate=on_activate}
end

---@return table
function create_active_filter_count()
    return widgets.Label{view_id='active_filter_count',
        frame=ui_layout.get_frame('active_filter_count'), text='Filters: 0', text_pen=COLOR_GREY}
end

---@param view table|nil
---@return string|nil
function get_button_tooltip(view)
    return is_mouse_over(view) and 'Edit the current filters.' or nil
end
