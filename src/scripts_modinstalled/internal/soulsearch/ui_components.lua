--@ module=true

local widgets = require('gui.widgets')
local stats_presenter = reqscript('internal/soulsearch/stats_presenter')
local ui_format = reqscript('internal/soulsearch/ui_format')
local ui_layout = reqscript('internal/soulsearch/ui_layout')

CONTROL_TOOLTIPS = {
    {id='add_filter_button', text='Add an attribute or trait to the ranking criteria.'},
    {id='add_skill_button', text='Add a skill to the ranking criteria.'},
    {id='preset_button', text='Save the current filters or load a custom or skill preset.'},
    {id='save_preset_button', text='Save the current ordered filters under this preset name.'},
    {id='close_preset_picker_button', text='Close'},
    {id='close_filter_picker_button', text='Close'},
    {id='close_skill_picker_button', text='Close'},
}

STATS_HEADER_TOOLTIPS = {
    label='Sort by stat name.',
    value='Sort by baseline difference.',
}

STATS_VALUE_TOOLTIP = 'Difference from the attribute average.'

---@class SoulSearchFilterPanelInputs
---@field is_attribute_picker_open fun(): boolean
---@field is_skill_picker_open fun(): boolean
---@field on_toggle_attribute_picker fun()
---@field on_toggle_skill_picker fun()
---@field on_clear fun()
---@field is_preset_picker_open fun(): boolean
---@field on_toggle_preset_picker fun()
---@field on_close_preset_picker fun()
---@field on_preset_query fun(text: string)
---@field on_save_preset fun()
---@field on_load_preset fun(name: string)
---@field on_load_default_preset fun(id: string)
---@field on_close_picker fun()
---@field on_attribute_query fun(text: string)
---@field on_skill_query fun(text: string)
---@field on_add fun(filter_id: string)

---@param inputs SoulSearchFilterPanelInputs
---@return table[]
function create_filter_panel(inputs)
    return {
        widgets.Label{
            frame=ui_layout.get_frame('filter_title'),
            text='Search filters',
            text_pen=COLOR_WHITE,
        },
        widgets.Label{
            frame=ui_layout.get_frame('filter_underline'),
            text=ui_format.get_title_underline('Search filters'),
            text_pen=COLOR_GREY,
        },
        widgets.HotkeyLabel{
            view_id='add_filter_button',
            frame=ui_layout.get_frame('add_filter'),
            key='CUSTOM_A',
            label='Add attribute filter',
            on_activate=inputs.on_toggle_attribute_picker,
        },
        widgets.HotkeyLabel{
            view_id='add_skill_button',
            frame=ui_layout.get_frame('add_skill'),
            key='CUSTOM_S',
            label='Add skill filter',
            on_activate=inputs.on_toggle_skill_picker,
        },
        widgets.HotkeyLabel{
            view_id='clear_filters_button',
            frame=ui_layout.get_frame('clear_filters'),
            key='CUSTOM_C',
            label='Clear filters',
            on_activate=inputs.on_clear,
        },
        widgets.HotkeyLabel{
            view_id='preset_button',
            frame=ui_layout.get_frame('presets'),
            key='CUSTOM_P',
            label='Filter presets',
            on_activate=inputs.on_toggle_preset_picker,
        },
        widgets.List{
            view_id='filter_list',
            frame=ui_layout.get_frame('filter_list'),
            visible=function()
                return not inputs.is_attribute_picker_open() and
                    not inputs.is_skill_picker_open() and
                    not inputs.is_preset_picker_open()
            end,
        },
        widgets.Window{
            view_id='available_filter_window',
            frame=ui_layout.get_frame('picker'),
            frame_title='Select attribute/trait',
            draggable=false,
            visible=inputs.is_attribute_picker_open,
            subviews={
                widgets.HotkeyLabel{
                    view_id='close_filter_picker_button',
                    frame=ui_layout.get_frame('picker_close'),
                    label='[X]',
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
            view_id='available_skill_window',
            frame=ui_layout.get_frame('picker'),
            frame_title='Select skill',
            draggable=false,
            visible=inputs.is_skill_picker_open,
            subviews={
                widgets.HotkeyLabel{
                    view_id='close_skill_picker_button',
                    frame=ui_layout.get_frame('picker_close'),
                    label='[X]',
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
                widgets.HotkeyLabel{
                    view_id='close_preset_picker_button',
                    frame=ui_layout.get_frame('picker_close'),
                    label='[X]',
                    on_activate=inputs.on_close_preset_picker,
                },
                widgets.HotkeyLabel{
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
                        if choice and choice.default_id then
                            inputs.on_load_default_preset(choice.default_id)
                        elseif choice and choice.name then
                            inputs.on_load_preset(choice.name)
                        end
                    end,
                },
            },
        },
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

---@return table[]
function create_stats_panel()
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
            text='No resident selected.',
        },
        widgets.Label{
            view_id='stats_columns',
            frame=ui_layout.get_frame('stats_columns'),
            auto_height=false,
            text='',
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
