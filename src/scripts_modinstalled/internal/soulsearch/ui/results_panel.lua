--@ module=true

local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')
local ui_format = reqscript('internal/soulsearch/ui_format')
local ui_layout = reqscript('internal/soulsearch/ui_layout')

local sortable_header = reqscript('internal/soulsearch/ui/sortable_header')

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
        sortable_header.new{view_id='result_columns',
            frame={l=ui_layout.RESULTS_LEFT, t=5, w=ui_layout.RESULT_NAME_WIDTH},
            label='Name', text_pen=COLOR_GREY, on_cycle=function() inputs.on_sort('name') end},
        sortable_header.new{view_id='result_profession_column',
            frame={l=ui_layout.RESULTS_LEFT + ui_layout.RESULT_PROFESSION_COLUMN_X, t=5,
                w=ui_layout.RESULT_PROFESSION_WIDTH}, label='Profession', text_pen=COLOR_GREY,
            on_cycle=function() inputs.on_sort('profession') end},
        sortable_header.new{view_id='result_unit_id_column',
            frame={l=ui_layout.RESULTS_LEFT + ui_layout.RESULT_UNIT_ID_COLUMN_X, t=5,
                w=ui_layout.RESULT_UNIT_ID_WIDTH}, label='Unit ID', text_pen=COLOR_GREY,
            on_cycle=function() inputs.on_sort('unit_id') end},
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
---@param sort SoulSearchSortState|nil
function ResultsPanel:set_header_text(title, underline, _, sort)
    self.subviews.result_header:setText(title)
    self.subviews.result_header_underline:setText(underline)
    local active, reverse = sort and sort.key, sort and sort.reverse
    sortable_header.set_sort(self.subviews.result_columns, active == 'name', reverse)
    sortable_header.set_sort(self.subviews.result_profession_column, active == 'profession', reverse)
    sortable_header.set_sort(self.subviews.result_unit_id_column, active == 'unit_id', reverse)
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
    local headers = {
        {view_id='result_columns', column='name'},
        {view_id='result_profession_column', column='profession'},
        {view_id='result_unit_id_column', column='unit_id'},
    }
    for _, header in ipairs(headers) do
        local x, y = self.subviews[header.view_id]:getMousePos()
        if x and y == 0 then return HEADER_TOOLTIPS[header.column] end
    end
end
