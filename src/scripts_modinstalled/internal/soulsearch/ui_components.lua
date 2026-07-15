--@ module=true

-- Temporary aggregate for Results and root-window controls. Filter components
-- now live under internal/soulsearch/ui/.
local widgets = require('gui.widgets')
local ui_format = reqscript('internal/soulsearch/ui_format')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local filter_panel = reqscript('internal/soulsearch/ui/filter_panel')

-- Temporary compatibility facade for Phase 2. Consumers now import the
-- Filter Panel directly; Phase 5 removes these aliases with this aggregate.
create_filter_panel = filter_panel.create
create_filter_panel_button = filter_panel.create_button
create_active_filter_count = filter_panel.create_active_filter_count

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

RESULT_HEADER_TOOLTIPS = {
    name='Sort by name.', unit_id='Sort by unit ID.',
    profession='Sort by profession.',
}

---@param on_query fun(text: string)
---@return table
function create_results_query(on_query)
    return widgets.EditField{view_id='search_field',
        frame=ui_layout.get_frame('search_field'), label_text='Search: ',
        key='CUSTOM_F', modal=true, on_change=on_query}
end

---@param inputs SoulSearchResultsPanelInputs
---@return table[]
function create_results_panel(inputs)
    return {
        widgets.Label{view_id='result_header', frame=ui_layout.get_frame('result_title'),
            text='Results', text_pen=COLOR_WHITE},
        widgets.Label{view_id='result_header_underline', frame=ui_layout.get_frame('result_underline'),
            text=ui_format.get_title_underline('Results'), text_pen=COLOR_GREY},
        SortableHeader{view_id='result_columns', frame=ui_layout.get_frame('result_columns'),
            text=ui_format.format_result_columns(), text_pen=COLOR_GREY,
            get_column=ui_layout.get_result_header_column, on_sort=inputs.on_sort},
        widgets.List{view_id='result_list', frame=ui_layout.get_frame('result_list'),
            on_select=function(_, choice) inputs.on_select(choice and choice.result or nil) end,
            on_submit=function(_, choice) inputs.on_submit(choice and choice.result or nil) end},
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

---@param on_close fun()
---@return table
function create_close_button(on_close)
    return widgets.HotkeyLabel{view_id='close_button', frame=ui_layout.get_frame('close'),
        key='LEAVESCREEN', label='Close', on_activate=on_close}
end
