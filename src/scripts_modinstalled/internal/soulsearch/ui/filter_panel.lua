--@ module=true

local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')
local ui_format = reqscript('internal/soulsearch/ui_format')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local ModalPanelWindow =
    reqscript('internal/soulsearch/ui/modal_panel').ModalPanelWindow
local FilterActionList =
    reqscript('internal/soulsearch/ui/filter_action_list').FilterActionList
local searchable_picker =
    reqscript('internal/soulsearch/ui/searchable_picker')
local preset_picker = reqscript('internal/soulsearch/ui/preset_picker')

local PICKER_VIEW_IDS = {
    attribute='available_filter_window', skill='available_skill_window',
    race='available_race_window', unit_scope='available_unit_scope_window',
    preset='preset_picker_window',
}

local function get_subview(panel, id)
    return panel.subviews[id] or
        (panel.parent_view and panel.parent_view.subviews[id])
end

---@class FilterPanel: ModalPanelWindow
---@field inputs SoulSearchFilterPanelInputs
FilterPanel = defclass(FilterPanel, ModalPanelWindow)

---Initializes filter controls, active-filter rendering, and child pickers.
---@param info table filter panel construction parameters
function FilterPanel:init(info)
    info.on_open = function()
        self.inputs.on_refresh{pickers=true, presets=true}
    end
    info.on_close = function()
        self:close_picker(true)
        self.inputs.on_refresh{pickers=true, presets=true}
    end
    FilterPanel.super.init(self, info)
    self.inputs = info.inputs
    local inputs = self.inputs
    self:addviews{
        widgets.TextButton{view_id='close_filter_panel_button',
            frame=ui_layout.get_frame('filter_panel_close'), label='X',
            tooltip='Close',
            on_activate=function() self:close() end},
        widgets.TextButton{view_id='add_filter_button', frame=ui_layout.get_frame('add_filter'),
            key='CUSTOM_A', label='Add attribute filter',
            tooltip='Add an attribute or trait to the ranking criteria.',
            on_activate=function() self:toggle_picker('attribute') end},
        widgets.TextButton{view_id='add_skill_button', frame=ui_layout.get_frame('add_skill'),
            key='CUSTOM_S', label='Add skill filter',
            tooltip='Add a skill to the ranking criteria.',
            on_activate=function() self:toggle_picker('skill') end},
        widgets.TextButton{view_id='add_race_button', frame=ui_layout.get_frame('add_race'),
            key='CUSTOM_G', label='Add race filter',
            tooltip='Add a race to the candidate scope.',
            on_activate=function() self:toggle_picker('race') end},
        widgets.TextButton{view_id='clear_filters_button', frame=ui_layout.get_frame('clear_filters'),
            key='CUSTOM_C', label='Reset filters', on_activate=inputs.on_clear},
        widgets.TextButton{view_id='preset_button', frame=ui_layout.get_frame('presets'),
            key='CUSTOM_P', label='Filter presets',
            tooltip='Save the current filters or load a custom, role, or skill preset.',
            on_activate=function() self:toggle_picker('preset') end},
        widgets.TextButton{view_id='add_unit_scope_button', frame=ui_layout.get_frame('add_unit_scope'),
            label='Add unit scope filter', tooltip='Add a unit scope to the candidate set.',
            on_activate=function() self:toggle_picker('unit_scope') end},
        FilterActionList{view_id='filter_list', frame=ui_layout.get_frame('filter_list'),
            visible=function()
                return not self:has_open_picker()
            end, on_filter_action=inputs.on_filter_action},
        searchable_picker.SearchablePicker{view_id='available_filter_window',
            frame=ui_layout.get_frame('picker'), frame_title='Select attribute/trait',
            draggable=false, kind='attribute',
            on_open=function() self:on_picker_open('attribute') end,
            on_close=function() self:on_picker_close('attribute') end, inputs={
            on_query=inputs.on_attribute_query,
            on_submit=function(choice) if choice and choice.descriptor then inputs.on_toggle_filter(choice.descriptor.id) end end}},
        searchable_picker.SearchablePicker{view_id='available_race_window',
            frame=ui_layout.get_frame('picker'), frame_title='Select race',
            draggable=false, kind='race',
            on_open=function() self:on_picker_open('race') end,
            on_close=function() self:on_picker_close('race') end, inputs={
            on_query=inputs.on_race_query,
            on_submit=function(choice) if choice and choice.descriptor then inputs.on_toggle_filter(choice.descriptor.id) end end}},
        searchable_picker.SearchablePicker{view_id='available_unit_scope_window',
            frame=ui_layout.get_frame('picker'), frame_title='Select unit scope',
            draggable=false, kind='unit_scope',
            on_open=function() self:on_picker_open('unit_scope') end,
            on_close=function() self:on_picker_close('unit_scope') end, inputs={
            on_query=inputs.on_unit_scope_query,
            on_submit=function(choice) if choice and choice.descriptor then inputs.on_toggle_filter(choice.descriptor.id) end end}},
        searchable_picker.SearchablePicker{view_id='available_skill_window',
            frame=ui_layout.get_frame('picker'), frame_title='Select skill',
            draggable=false, kind='skill',
            on_open=function() self:on_picker_open('skill') end,
            on_close=function() self:on_picker_close('skill') end, inputs={
            on_query=inputs.on_skill_query,
            on_submit=function(choice) if choice and choice.descriptor then inputs.on_toggle_filter(choice.descriptor.id) end end}},
        preset_picker.PresetPicker{view_id='preset_picker_window',
            frame=ui_layout.get_frame('preset_picker'), frame_title='Filter presets',
            draggable=false, on_open=function() self:on_picker_open('preset') end,
            on_close=function() self:on_picker_close('preset') end, inputs={
            on_save=inputs.on_save_preset,
            on_query=inputs.on_preset_query, on_load=inputs.on_load_preset,
            on_load_default=inputs.on_load_default_preset, on_load_role=inputs.on_load_role_preset}},
    }
end

---@param kind 'attribute'|'skill'|'race'|'unit_scope'|'preset'
---@return boolean changed
function FilterPanel:toggle_picker(kind)
    local picker = get_subview(self, PICKER_VIEW_IDS[kind])
    assert(picker, 'unknown picker kind: ' .. tostring(kind))
    if picker:is_open() then return picker:close() end
    self:close_picker()
    return picker:open()
end

---@param kind 'attribute'|'skill'|'race'|'unit_scope'|'preset'
---@return boolean
function FilterPanel:is_picker_open(kind)
    local picker = get_subview(self, PICKER_VIEW_IDS[kind])
    return picker and picker:is_open() or false
end

---@return boolean changed
function FilterPanel:close_picker(suppress_refresh)
    for _, kind in ipairs({'attribute', 'skill', 'race', 'unit_scope', 'preset'}) do
        local picker = get_subview(self, PICKER_VIEW_IDS[kind])
        if picker:is_open() then
            self.suppress_picker_refresh = suppress_refresh
            local changed = picker:close()
            self.suppress_picker_refresh = false
            return changed
        end
    end
    return false
end

---@return boolean
function FilterPanel:has_open_picker()
    for _, kind in ipairs({'attribute', 'skill', 'race', 'unit_scope', 'preset'}) do
        if self:is_picker_open(kind) then return true end
    end
    return false
end

---@param kind 'attribute'|'skill'|'race'|'unit_scope'|'preset'
function FilterPanel:on_picker_open(kind)
    self.inputs.on_refresh{pickers=true, presets=kind == 'preset'}
end

---@param kind 'attribute'|'skill'|'race'|'unit_scope'|'preset'
function FilterPanel:on_picker_close(kind)
    if not self.suppress_picker_refresh then
        self.inputs.on_refresh{pickers=true, presets=kind == 'preset'}
    end
end

---@return string|nil
function FilterPanel:get_selected_filter_id()
    local _, choice = get_subview(self, 'filter_list'):getSelected()
    return choice and choice.descriptor and choice.descriptor.id or nil
end

---@param choices table[]
---@param selected integer|nil
function FilterPanel:set_active_filter_choices(choices, selected)
    get_subview(self, 'filter_list'):setChoices(choices, selected)
end

---@param kind 'attribute'|'skill'|'race'
---@param choices table[]
---@param selected integer|nil
function FilterPanel:set_picker_choices(kind, choices, selected)
    get_subview(self, PICKER_VIEW_IDS[kind]):set_choices(choices, selected)
end

---@param choices table[]
function FilterPanel:set_preset_choices(choices)
    get_subview(self, 'preset_list'):setChoices(choices)
end

---@param choices table[]
---@param selected integer|nil
---@param label string|nil

---@class SoulSearchFilterPanelInputs
---@field on_clear fun()
---@field on_refresh fun(request: SoulSearchRefreshRequest)
---@field on_preset_query fun(text: string)
---@field on_save_preset fun()
---@field on_load_preset fun(name: string)
---@field on_load_default_preset fun(id: string)
---@field on_load_role_preset fun(id: string)
---@field on_attribute_query fun(text: string)
---@field on_skill_query fun(text: string)
---@field on_race_query fun(text: string)
---@field on_unit_scope_query fun(text: string)
---@field on_toggle_filter fun(filter_id: string)
---@field on_filter_action fun(filter_id: string, action: string)

---@param on_activate fun()
---@return table
function create_button(on_activate)
    return widgets.TextButton{view_id='filters_button', frame=ui_layout.get_frame('filters_button'),
        label='Edit', text_pen=COLOR_YELLOW, tooltip='Edit the current filters.',
        on_activate=on_activate}
end

---@return table
function create_active_filter_count()
    return widgets.Label{view_id='active_filter_count',
        frame=ui_layout.get_frame('active_filter_count'), text='Filters: 0', text_pen=COLOR_GREY}
end
