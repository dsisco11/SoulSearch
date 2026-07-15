--@ module=true

local widgets = require('gui.widgets')
local descriptions = reqscript('internal/soulsearch/attribute_descriptions')
local presenter = reqscript('internal/soulsearch/stats_presenter')
local layout = reqscript('internal/soulsearch/stats_layout')
local sort_state = reqscript('internal/soulsearch/sort_state')
local sortable_header = reqscript('internal/soulsearch/ui/sortable_header')

local SORT_SPEC = sort_state.new_spec({'label', 'value'}, {value=true})

---Reusable sortable, scrollable list of meaningful unit stat deviations.
---@class UnitStatsList: widgets.Panel
---@field subject SoulSearchStatsSubject|nil
---@field sort SoulSearchSortState
---@field on_sort_change fun(sort: SoulSearchSortState)|nil
UnitStatsList = defclass(UnitStatsList, widgets.Panel)
UnitStatsList.ATTRS{
    subject=DEFAULT_NIL,
    sort=DEFAULT_NIL,
    on_sort_change=DEFAULT_NIL,
}

function UnitStatsList:init(info)
    self.subject = info.subject
    self.sort = sort_state.normalize(info.sort, SORT_SPEC)
    self.on_sort_change = info.on_sort_change
    self.stats_records = {}
    self.header_height = 1
    self:addviews{
        sortable_header.new{view_id='columns', auto_height=false,
            frame={l=0, t=0, w=layout.LABEL_WIDTH}, label='Stat',
            on_cycle=function() self:cycle_sort('label') end},
        sortable_header.new{view_id='value_column', auto_height=false,
            frame={l=layout.VALUE_COLUMN_X, t=0, w=layout.VALUE_HEADER_WIDTH},
            label='Delta', on_cycle=function() self:cycle_sort('value') end},
        widgets.Label{view_id='body', auto_height=false, text=''},
    }
    self:refresh()
end

local function copy_sort(value) return sort_state.normalize(value, SORT_SPEC) end
function UnitStatsList:get_sort() return copy_sort(self.sort) end
function UnitStatsList:set_subject(subject) self.subject = subject; self:refresh() end
function UnitStatsList:set_sort(sort) self.sort = copy_sort(sort); self:refresh() end
function UnitStatsList:reset_view_state(sort)
    self.sort = copy_sort(sort)
    self.subviews.body.start_line_num = 1
    self:refresh()
end
function UnitStatsList:cycle_sort(column)
    self.sort = sort_state.next(self.sort, column, SORT_SPEC)
    self:refresh()
    if self.on_sort_change then self.on_sort_change(self:get_sort()) end
end
function UnitStatsList:refresh()
    local sort = self.sort
    sortable_header.set_sort(self.subviews.columns, sort.key == 'label', sort.reverse)
    sortable_header.set_sort(self.subviews.value_column, sort.key == 'value', sort.reverse)
    self.subviews.body:setText(presenter.body(self.subject, sort.key, sort.reverse))
    self.stats_records = presenter.get_display_records(self.subject, sort.key, sort.reverse)
    if self.frame_parent_rect then self:updateLayout() end
end

---Sets the number of lines reserved for the native column headers.
---@param height integer|nil
function UnitStatsList:set_header_height(height)
    self.header_height = math.max(1, height or 1)
    self.subviews.columns.frame = {l=0, t=0, r=0, h=self.header_height}
    self.subviews.value_column.frame = {
        l=layout.VALUE_COLUMN_X, t=0, w=layout.VALUE_HEADER_WIDTH,
        h=self.header_height,
    }
    self.subviews.body.frame = {l=0, t=self.header_height, r=0, b=0}
end

function UnitStatsList:get_tooltip_text()
    local x, y = self.subviews.columns:getMousePos()
    if x and y == 0 then return 'Sort by stat name.' end
    x, y = self.subviews.value_column:getMousePos()
    if x and y == 0 then return 'Sort by baseline difference.' end
    x, y = self.subviews.body:getMousePos()
    if layout.is_value_cell(x, y) then return 'Difference from the attribute average.' end
    if layout.is_label_cell(x, y) then
        local record = self.stats_records[(self.subviews.body.start_line_num or 1) + y]
        return record and descriptions.get_tooltip(record.kind, record.key) or nil
    end
end
