--@ module=true

local widgets = require('gui.widgets')
local ui_format = reqscript('internal/soulsearch/ui_format')
local ui_layout = reqscript('internal/soulsearch/ui_layout')

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

local HEADER_TOOLTIPS = {
    name='Sort by name.', unit_id='Sort by unit ID.',
    profession='Sort by profession.',
}

---@class SoulSearchResultsPanelInputs
---@field on_query fun(text: string)
---@field on_select fun(result: SoulSearchResult|nil)
---@field on_submit fun(result: SoulSearchResult|nil)
---@field on_sort fun(column: string)

---Embedded Results component. The host owns query semantics, result creation,
---and sorting state; this panel owns the results view hierarchy and its narrow
---view update/navigation interface.
---@class ResultsPanel: widgets.Panel
---@field inputs SoulSearchResultsPanelInputs
ResultsPanel = defclass(ResultsPanel, widgets.Panel)

function ResultsPanel:init(info)
    self.inputs = info.inputs
    local inputs = self.inputs
    self:addviews{
        widgets.EditField{view_id='search_field',
            frame=ui_layout.get_frame('search_field'), label_text='Search: ',
            key='CUSTOM_F', modal=true, on_change=inputs.on_query},
        widgets.Label{view_id='result_header',
            frame=ui_layout.get_frame('result_title'), text='Results',
            text_pen=COLOR_WHITE},
        widgets.Label{view_id='result_header_underline',
            frame=ui_layout.get_frame('result_underline'),
            text=ui_format.get_title_underline('Results'), text_pen=COLOR_GREY},
        SortableHeader{view_id='result_columns',
            frame=ui_layout.get_frame('result_columns'),
            text=ui_format.format_result_columns(), text_pen=COLOR_GREY,
            get_column=ui_layout.get_result_header_column,
            on_sort=inputs.on_sort},
        widgets.List{view_id='result_list',
            frame=ui_layout.get_frame('result_list'),
            on_select=function(_, choice)
                inputs.on_select(choice and choice.result or nil)
            end,
            on_submit=function(_, choice)
                inputs.on_submit(choice and choice.result or nil)
            end},
    }
end

---@param text string
function ResultsPanel:set_query_text(text)
    self.subviews.search_field:setText(text)
end

---@param title string
---@param underline string
---@param columns string
function ResultsPanel:set_header_text(title, underline, columns)
    self.subviews.result_header:setText(title)
    self.subviews.result_header_underline:setText(underline)
    self.subviews.result_columns:setText(columns)
end

---@param choices table[]
---@param selected integer|nil
function ResultsPanel:set_choices(choices, selected)
    self.subviews.result_list:setChoices(choices, selected)
end

---@return integer|nil
function ResultsPanel:get_selected_index()
    local index = self.subviews.result_list:getSelected()
    return index
end

---@return SoulSearchResult|nil
function ResultsPanel:get_selected_result()
    local _, choice = self.subviews.result_list:getSelected()
    return choice and choice.result or nil
end

---@param delta integer
function ResultsPanel:move_cursor(delta)
    self.subviews.result_list:moveCursor(delta)
end

---@return string|nil
function ResultsPanel:get_header_tooltip()
    local x, y = self.subviews.result_columns:getMousePos()
    local column = ui_layout.get_result_header_column(x, y)
    return column and HEADER_TOOLTIPS[column] or nil
end
