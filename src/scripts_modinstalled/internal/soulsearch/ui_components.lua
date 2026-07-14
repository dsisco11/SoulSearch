--@ module=true

local widgets = require('gui.widgets')
local stats_presenter = reqscript('internal/soulsearch/stats_presenter')
local ui_format = reqscript('internal/soulsearch/ui_format')
local ui_layout = reqscript('internal/soulsearch/ui_layout')

local ModalPanelWindow = defclass(ModalPanelWindow, widgets.Window)

function ModalPanelWindow:init(info)
    self.is_open = info.is_open
    self.on_open = info.on_open
    self.on_close = info.on_close
end

---@return boolean
function ModalPanelWindow:open()
    if self.is_open() then return false end
    self.on_open()
    self:setFocus(true)
    return true
end

---@return boolean
function ModalPanelWindow:close()
    if not self.is_open() then return false end
    self:setFocus(false)
    self.on_close()
    return true
end

function ModalPanelWindow:onInput(keys)
    if not self.is_open() then return false end
    if ModalPanelWindow.super.onInput(self, keys) then return true end

    if keys._MOUSE_R and self:getMouseFramePos() then
        self:close()
        return true
    end
    return self:getMouseFramePos() ~= nil
end

local FilterActionList = defclass(FilterActionList, widgets.List)

function FilterActionList:init(info)
    self.on_filter_action = info.on_filter_action
end

function FilterActionList:setChoices(choices, selected)
    self.action_choices = choices
    return FilterActionList.super.setChoices(self, choices, selected)
end

---@return integer|nil, table|nil, SoulSearchFilterActionMetadata|nil
function FilterActionList:getActionUnderMouse()
    local x, y = self:getMousePos()
    local action = ui_layout.get_filter_action_at_x(x)
    if not action or not y then return nil end

    local index = self:getIdxUnderMouse()
    if not index then
        index = (self.start_line_num or 1) + y
    end
    return index, self.action_choices and self.action_choices[index], action
end

function FilterActionList:onInput(keys)
    if keys._MOUSE_L then
        local index, choice, action = self:getActionUnderMouse()
        if choice and action then
            self:setSelected(index)
            local descriptor = choice and choice.descriptor
            if descriptor then
                self.on_filter_action(descriptor.id, action.callback)
                return true
            end
        end
    end
    return FilterActionList.super.onInput(self, keys)
end

local SortableHeader = defclass(SortableHeader, widgets.Label)

function SortableHeader:init(info)
    self.get_column = info.get_column
    self.on_sort = info.on_sort
end

function SortableHeader:onInput(keys)
    if keys._MOUSE_L then
        local column = self.get_column(self:getMousePos())
        if column then
            self.on_sort(column)
            return true
        end
    end
    return SortableHeader.super.onInput(self, keys)
end

CONTROL_TOOLTIPS = {
    {id='filters_button', text='Edit the current filters.'},
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

STATS_HEADER_TOOLTIPS = {
    label='Sort by stat name.',
    value='Sort by baseline difference.',
}

RESULT_HEADER_TOOLTIPS = {
    name='Sort by name.',
    unit_id='Sort by unit ID.',
    profession='Sort by profession.',
}

STATS_VALUE_TOOLTIP = 'Difference from the attribute average.'

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
---@return table
function create_filter_panel(inputs)
    local unit_scope_label
    for _, option in ipairs(inputs.unit_scope_options) do
        if option.value == inputs.unit_scope then
            unit_scope_label = option.label
            break
        end
    end
    local subviews = {
        widgets.TextButton{
            view_id='close_filter_panel_button',
            frame=ui_layout.get_frame('filter_panel_close'),
            label='X',
            on_activate=inputs.on_close_filter_panel,
        },
        widgets.Label{
            view_id='unit_scope_label',
            frame=ui_layout.get_frame('unit_scope'),
            text=ui_format.format_unit_scope_control(
                unit_scope_label),
        },
        widgets.TextButton{
            view_id='unit_scope_edit',
            frame=ui_layout.get_frame('unit_scope_edit'),
            label='Edit',
            on_activate=inputs.on_toggle_unit_scope_picker,
        },
        widgets.TextButton{
            view_id='add_filter_button',
            frame=ui_layout.get_frame('add_filter'),
            key='CUSTOM_A',
            label='Add attribute filter',
            on_activate=inputs.on_toggle_attribute_picker,
        },
        widgets.TextButton{
            view_id='add_skill_button',
            frame=ui_layout.get_frame('add_skill'),
            key='CUSTOM_S',
            label='Add skill filter',
            on_activate=inputs.on_toggle_skill_picker,
        },
        widgets.TextButton{
            view_id='add_race_button',
            frame=ui_layout.get_frame('add_race'),
            key='CUSTOM_G',
            label='Add race filter',
            on_activate=inputs.on_toggle_race_picker,
        },
        widgets.TextButton{
            view_id='clear_filters_button',
            frame=ui_layout.get_frame('clear_filters'),
            key='CUSTOM_C',
            label='Clear filters',
            on_activate=inputs.on_clear,
        },
        widgets.TextButton{
            view_id='preset_button',
            frame=ui_layout.get_frame('presets'),
            key='CUSTOM_P',
            label='Filter presets',
            on_activate=inputs.on_toggle_preset_picker,
        },
        FilterActionList{
            view_id='filter_list',
            frame=ui_layout.get_frame('filter_list'),
            visible=function()
                return not inputs.is_attribute_picker_open() and
                    not inputs.is_skill_picker_open() and
                    not inputs.is_race_picker_open() and
                    not inputs.is_unit_scope_picker_open() and
                    not inputs.is_preset_picker_open()
            end,
            on_filter_action=inputs.on_filter_action,
        },
        widgets.Window{
            view_id='available_filter_window',
            frame=ui_layout.get_frame('picker'),
            frame_title='Select attribute/trait',
            draggable=false,
            visible=inputs.is_attribute_picker_open,
            subviews={
                widgets.TextButton{
                    view_id='close_filter_picker_button',
                    frame=ui_layout.get_frame('picker_close'),
                    label='X',
                    on_activate=inputs.on_close_picker,
                },
                widgets.EditField{
                    view_id='attribute_search_field',
                    frame=ui_layout.get_frame('picker_search'),
                    label_text='Search: ',
                    key='CUSTOM_T',
                    on_change=inputs.on_attribute_query,
                },
                widgets.List{
                    view_id='available_filter_list',
                    frame=ui_layout.get_frame('picker_list'),
                    on_submit=function(index, choice)
                        if choice and choice.descriptor then
                            inputs.on_add(choice.descriptor.id)
                        end
                    end,
                },
            },
        },
        widgets.Window{
            view_id='available_race_window',
            frame=ui_layout.get_frame('picker'),
            frame_title='Select race',
            draggable=false,
            visible=inputs.is_race_picker_open,
            subviews={
                widgets.TextButton{
                    view_id='close_race_picker_button',
                    frame=ui_layout.get_frame('picker_close'),
                    label='X',
                    on_activate=inputs.on_close_picker,
                },
                widgets.EditField{
                    view_id='race_search_field',
                    frame=ui_layout.get_frame('picker_search'),
                    label_text='Search: ',
                    key='CUSTOM_G',
                    on_change=inputs.on_race_query,
                },
                widgets.List{
                    view_id='available_race_list',
                    frame=ui_layout.get_frame('picker_list'),
                    on_submit=function(index, choice)
                        if choice and choice.descriptor then
                            inputs.on_add(choice.descriptor.id)
                        end
                    end,
                },
            },
        },
        widgets.Window{
            view_id='available_skill_window',
            frame=ui_layout.get_frame('picker'),
            frame_title='Select skill',
            draggable=false,
            visible=inputs.is_skill_picker_open,
            subviews={
                widgets.TextButton{
                    view_id='close_skill_picker_button',
                    frame=ui_layout.get_frame('picker_close'),
                    label='X',
                    on_activate=inputs.on_close_picker,
                },
                widgets.EditField{
                    view_id='skill_search_field',
                    frame=ui_layout.get_frame('picker_search'),
                    label_text='Search: ',
                    key='CUSTOM_K',
                    on_change=inputs.on_skill_query,
                },
                widgets.List{
                    view_id='available_skill_list',
                    frame=ui_layout.get_frame('picker_list'),
                    on_submit=function(index, choice)
                        if choice and choice.descriptor then
                            inputs.on_add(choice.descriptor.id)
                        end
                    end,
                },
            },
        },
        widgets.Window{
            view_id='preset_picker_window',
            frame=ui_layout.get_frame('preset_picker'),
            frame_title='Filter presets',
            draggable=false,
            visible=inputs.is_preset_picker_open,
            subviews={
                widgets.TextButton{
                    view_id='close_preset_picker_button',
                    frame=ui_layout.get_frame('picker_close'),
                    label='X',
                    on_activate=inputs.on_close_preset_picker,
                },
                widgets.TextButton{
                    view_id='save_preset_button',
                    frame=ui_layout.get_frame('preset_save'),
                    key='CUSTOM_W',
                    label='Save preset',
                    on_activate=inputs.on_save_preset,
                },
                widgets.EditField{
                    view_id='preset_search_field',
                    frame=ui_layout.get_frame('preset_search'),
                    label_text='Search: ',
                    key='CUSTOM_F',
                    on_change=inputs.on_preset_query,
                },
                widgets.List{
                    view_id='preset_list',
                    frame=ui_layout.get_frame('preset_list'),
                    on_submit=function(index, choice)
                        if choice and choice.role_id then
                            inputs.on_load_role_preset(choice.role_id)
                        elseif choice and choice.default_id then
                            inputs.on_load_default_preset(choice.default_id)
                        elseif choice and choice.name then
                            inputs.on_load_preset(choice.name)
                        end
                    end,
                },
            },
        },
        -- Keep this last: sibling views paint in creation order, and this
        -- short popup deliberately overlaps the controls beneath Search.
        widgets.Window{
            view_id='unit_scope_picker_window',
            frame=ui_layout.get_unit_scope_picker_frame(
                #inputs.unit_scope_options),
            frame_title='Search scope',
            draggable=false,
            visible=inputs.is_unit_scope_picker_open,
            subviews={
                widgets.List{
                    view_id='unit_scope_picker_list',
                    frame=ui_layout.get_unit_scope_picker_list_frame(
                        #inputs.unit_scope_options),
                    on_submit=function(index, choice)
                        if choice and choice.scope then
                            inputs.on_unit_scope_change(choice.scope)
                        end
                    end,
                },
            },
        },
    }
    return ModalPanelWindow{
        view_id='filter_panel_window',
        frame=ui_layout.get_frame('filter_panel'),
        frame_title='Search filters',
        draggable=false,
        visible=inputs.is_filter_panel_open,
        is_open=inputs.is_filter_panel_open,
        on_open=inputs.on_open_filter_panel,
        on_close=inputs.on_close_filter_panel_state,
        subviews=subviews,
    }
end

---@param on_activate fun()
---@return table
function create_filter_panel_button(on_activate)
    return widgets.TextButton{
        view_id='filters_button',
        frame=ui_layout.get_frame('filters_button'),
        label='Edit',
        text_pen=COLOR_YELLOW,
        on_activate=on_activate,
    }
end

---@return table
function create_active_filter_count()
    return widgets.Label{
        view_id='active_filter_count',
        frame=ui_layout.get_frame('active_filter_count'),
        text='Filters: 0',
        text_pen=COLOR_GREY,
    }
end

---@param on_query fun(text: string)
---@return table
function create_results_query(on_query)
    return widgets.EditField{
        view_id='search_field',
        frame=ui_layout.get_frame('search_field'),
        label_text='Search: ',
        key='CUSTOM_F',
        modal=true,
        on_change=on_query,
    }
end

---@class SoulSearchResultsPanelInputs
---@field on_select fun(result: SoulSearchResult|nil)
---@field on_submit fun(result: SoulSearchResult|nil)
---@field on_sort fun(column: string)

---@param inputs SoulSearchResultsPanelInputs
---@return table[]
function create_results_panel(inputs)
    return {
        widgets.Label{
            view_id='result_header',
            frame=ui_layout.get_frame('result_title'),
            text='Results',
            text_pen=COLOR_WHITE,
        },
        widgets.Label{
            view_id='result_header_underline',
            frame=ui_layout.get_frame('result_underline'),
            text=ui_format.get_title_underline('Results'),
            text_pen=COLOR_GREY,
        },
        SortableHeader{
            view_id='result_columns',
            frame=ui_layout.get_frame('result_columns'),
            text=ui_format.format_result_columns(),
            text_pen=COLOR_GREY,
            get_column=ui_layout.get_result_header_column,
            on_sort=inputs.on_sort,
        },
        widgets.List{
            view_id='result_list',
            frame=ui_layout.get_frame('result_list'),
            on_select=function(index, choice)
                inputs.on_select(choice and choice.result or nil)
            end,
            on_submit=function(index, choice)
                inputs.on_submit(choice and choice.result or nil)
            end,
        },
    }
end

---@param list widgets.List
---@param choices table[]
---@param selected integer
function set_result_choices(list, choices, selected)
    list:setChoices(choices, selected)
end

---@param list widgets.List
---@param delta integer
function move_result_cursor(list, delta)
    list:moveCursor(delta)
end

---@param on_sort fun(column: string)
---@return table[]
function create_stats_panel(on_sort)
    return {
        widgets.Label{
            frame=ui_layout.get_frame('stats_title'),
            text='Stats',
            text_pen=COLOR_WHITE,
        },
        widgets.Label{
            frame=ui_layout.get_frame('stats_underline'),
            text=ui_format.get_title_underline('Stats'),
            text_pen=COLOR_GREY,
        },
        widgets.Label{
            view_id='stats_header',
            frame=ui_layout.get_frame('stats_header'),
            auto_height=false,
            text='No unit selected.',
        },
        SortableHeader{
            view_id='stats_columns',
            frame=ui_layout.get_frame('stats_columns'),
            auto_height=false,
            text='',
            get_column=ui_layout.get_stats_header_column,
            on_sort=on_sort,
        },
        widgets.Label{
            view_id='stats',
            frame=ui_layout.get_frame('stats_body'),
            auto_height=false,
            text='',
        },
    }
end

---@param header widgets.Label
---@param columns widgets.Label
---@param body widgets.Label
---@param result SoulSearchResult|nil
---@param sort_key string|nil
---@param sort_reverse boolean
---@param frame_body table|nil
function update_stats_panel(
        header, columns, body, result, sort_key, sort_reverse, frame_body)
    header:setText(stats_presenter.header(result))
    columns:setText(stats_presenter.column_header(sort_key, sort_reverse))
    body:setText(stats_presenter.body(result, sort_key, sort_reverse))
    local records = stats_presenter.get_display_records(
        result, sort_key, sort_reverse)

    local header_top = ui_layout.STATS_CONTENT_TOP
    local available_height = math.max(
        1,
        (frame_body and frame_body.height or ui_layout.WINDOW_FRAME.h) -
            header_top)
    local header_height = math.min(
        header:getTextHeight(),
        math.max(1, available_height - 3))
    local columns_top = header_top + header_height
    local columns_height = math.min(
        columns:getTextHeight(),
        math.max(1, available_height - header_height - 1))
    local body_top = columns_top + columns_height

    header.frame = {
        l=ui_layout.STATS_LEFT,
        t=header_top,
        r=1,
        h=header_height,
    }
    columns.frame = {
        l=ui_layout.STATS_LEFT,
        t=columns_top,
        r=1,
        h=columns_height,
    }
    body.frame = {l=ui_layout.STATS_LEFT, t=body_top, r=1, b=0}
    if frame_body then
        header:updateLayout(frame_body)
        columns:updateLayout(frame_body)
        body:updateLayout(frame_body)
    end
    return records
end

---@param on_close fun()
---@return table
function create_close_button(on_close)
    return widgets.HotkeyLabel{
        view_id='close_button',
        frame=ui_layout.get_frame('close'),
        key='LEAVESCREEN',
        label='Close',
        on_activate=on_close,
    }
end
