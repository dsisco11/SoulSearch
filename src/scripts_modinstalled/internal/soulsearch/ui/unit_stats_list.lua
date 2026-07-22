--@ module=true

local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')
local descriptions = reqscript('internal/soulsearch/attribute_descriptions')
local presenter = reqscript('internal/soulsearch/stats_presenter')
local layout = reqscript('internal/soulsearch/stats_layout')
local sort_state = reqscript('internal/soulsearch/sort_state')
local sortable_header = reqscript('internal/soulsearch/ui/sortable_header')
local glyphs = reqscript('internal/soulsearch/ui_glyphs')

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
    adaptive_columns=false,
    show_header_underline=false,
}

function UnitStatsList:init(info)
    self.subject = info.subject
    self.sort = sort_state.normalize(info.sort, SORT_SPEC)
    self.on_sort_change = info.on_sort_change
    self.adaptive_columns = info.adaptive_columns
    self.show_header_underline = info.show_header_underline
    self.stats_records = {}
    self.header_height = self.show_header_underline and 2 or 1
    self.columns_layout = self.adaptive_columns and layout.get_overlay_columns(false) or {
        value_column_x=layout.VALUE_COLUMN_X,
        label_width=layout.LABEL_WIDTH,
    }
    local views = {
        sortable_header.new{view_id='columns', auto_height=false,
            frame={l=0, t=0, w=self.columns_layout.label_width}, label='Stat',
            tooltip='Sort by stat name.',
            on_cycle=function() self:cycle_sort('label') end},
        sortable_header.new{view_id='value_column', auto_height=false,
            frame={l=self.columns_layout.value_column_x, t=0,
                w=layout.VALUE_HEADER_WIDTH},
            tooltip='Sort by baseline difference.',
            label='Delta', on_cycle=function() self:cycle_sort('value') end},
        -- A parent can reserve additional header rows during layout, but the
        -- list must remain visible before that callback has run (as it does
        -- when hosted by an overlay).
        widgets.Label{view_id='body', frame={l=0, t=self.header_height, r=0, b=0},
            auto_height=false, text='',
            on_pointer_update=function(target, x, y)
                self:update_body_tooltip(target, x, y)
            end},
    }
    if self.show_header_underline then
        table.insert(views, widgets.Label{view_id='columns_underline',
            frame={l=0, t=1, w=self.columns_layout.label_width, h=1},
            text=glyphs.CP437_HORIZONTAL_LINE:rep(self.columns_layout.label_width)})
        table.insert(views, widgets.Label{view_id='value_underline',
            frame={l=self.columns_layout.value_column_x, t=1,
                w=layout.VALUE_HEADER_WIDTH, h=1},
            text=glyphs.CP437_HORIZONTAL_LINE:rep(layout.VALUE_HEADER_WIDTH)})
    end
    self:addviews(views)
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
    self.stats_records = presenter.get_display_records(self.subject, sort.key, sort.reverse)
    self:refresh_body()
    if self.frame_parent_rect then self:updateLayout() end
    self:update_columns_for_scrollbar()
end

function UnitStatsList:refresh_body()
    local sort = self.sort
    self.subviews.body:setText(presenter.body(
        self.subject, sort.key, sort.reverse, self.columns_layout))
end

function UnitStatsList:update_columns_for_scrollbar()
    if not self.adaptive_columns then return end
    local scrollbar = self.subviews.body.scrollbar
    local has_scrollbar = scrollbar and scrollbar.elems_per_page < scrollbar.num_elems
    local columns_layout = layout.get_overlay_columns(has_scrollbar)
    if columns_layout.value_column_x == self.columns_layout.value_column_x then
        return
    end
    self.columns_layout = columns_layout
    self:set_header_height(self.header_height)
    self:refresh_body()
    if self.frame_parent_rect then self:updateLayout() end
end

---Sets the number of lines reserved for the native column headers.
---@param height integer|nil
function UnitStatsList:set_header_height(height)
    self.header_height = math.max(1, height or 1)
    self.subviews.columns.frame = {l=0, t=0, r=0, h=self.header_height}
    self.subviews.value_column.frame = {
        l=self.columns_layout.value_column_x, t=0, w=layout.VALUE_HEADER_WIDTH,
        h=self.header_height,
    }
    if self.show_header_underline then
        self.subviews.columns_underline.frame = {
            l=0, t=1, w=self.columns_layout.label_width, h=1,
        }
        self.subviews.columns_underline:setText(
            glyphs.CP437_HORIZONTAL_LINE:rep(self.columns_layout.label_width))
        self.subviews.value_underline.frame = {
            l=self.columns_layout.value_column_x, t=1,
            w=layout.VALUE_HEADER_WIDTH, h=1,
        }
        self.subviews.value_underline:setText(
            glyphs.CP437_HORIZONTAL_LINE:rep(layout.VALUE_HEADER_WIDTH))
    end
    self.subviews.body.frame = {l=0, t=self.header_height, r=0, b=0}
end

function UnitStatsList:update_body_tooltip(target, x, y)
    if layout.is_value_cell(x, y, self.columns_layout) then
        target.tooltip = 'Difference from the attribute average.'
        return
    end
    if layout.is_label_cell(x, y, self.columns_layout) then
        local record = self.stats_records[(self.subviews.body.start_line_num or 1) + y]
        target.tooltip = record and descriptions.get_tooltip(record.kind, record.key) or nil
        return
    end
    target.tooltip = nil
end
