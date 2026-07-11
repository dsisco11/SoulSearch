--@ module=true

local widgets = require('gui.widgets')
local stats_presenter = reqscript('internal/soulsearch/stats_presenter')
local ui_format = reqscript('internal/soulsearch/ui_format')
local ui_layout = reqscript('internal/soulsearch/ui_layout')

CONTROL_TOOLTIPS = {
    {id='add_filter_button', text='Add attribute filter'},
    {id='add_skill_button', text='Add skill filter'},
    {id='clear_filters_button', text='Clear filters'},
    {id='close_filter_picker_button', text='Close'},
    {id='close_skill_picker_button', text='Close'},
    {id='close_button', text='Close'},
}

STATS_HEADER_TOOLTIPS = {
    label='Sort by stat name.',
    value='Sort by baseline difference.',
}

---@class SoulSearchFilterPanelInputs
---@field is_attribute_picker_open fun(): boolean
---@field is_skill_picker_open fun(): boolean
---@field on_toggle_attribute_picker fun()
---@field on_toggle_skill_picker fun()
---@field on_clear fun()
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
            text=ui_format.title_underline('Search filters'),
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
        widgets.List{
            view_id='filter_list',
            frame=ui_layout.get_frame('filter_list'),
            visible=function()
                return not inputs.is_attribute_picker_open() and
                    not inputs.is_skill_picker_open()
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
            text=ui_format.title_underline('Results'),
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
            text=ui_format.title_underline('Stats'),
            text_pen=COLOR_GREY,
        },
        widgets.Label{
            view_id='stats_header',
            frame=ui_layout.get_frame('stats_header'),
            auto_height=false,
            text='No resident selected.',
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
---@param body widgets.Label
---@param result SoulSearchResult|nil
---@param sort_key string|nil
---@param sort_reverse boolean
---@param frame_body table|nil
function update_stats_panel(
        header, body, result, sort_key, sort_reverse, frame_body)
    header:setText(stats_presenter.header(result))
    body:setText(stats_presenter.body(result, sort_key, sort_reverse))

    local header_top = ui_layout.STATS_CONTENT_TOP
    local available_height = math.max(
        1,
        (frame_body and frame_body.height or ui_layout.WINDOW_FRAME.h) -
            header_top)
    local header_height = math.min(
        header:getTextHeight(),
        math.max(1, available_height - 1))
    local body_top = header_top + header_height

    header.frame = {
        l=ui_layout.STATS_LEFT,
        t=header_top,
        r=1,
        h=header_height,
    }
    body.frame = {l=ui_layout.STATS_LEFT, t=body_top, r=1, b=0}
    if frame_body then
        header:updateLayout(frame_body)
        body:updateLayout(frame_body)
    end
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
