--@ module=true

local widgets = require('gui.widgets')
local descriptions = reqscript('internal/soulsearch/attribute_descriptions')
local presenter = reqscript('internal/soulsearch/stats_presenter')
local layout = reqscript('internal/soulsearch/stats_layout')
local sort_state = reqscript('internal/soulsearch/sort_state')
local sortable_header = reqscript('internal/soulsearch/ui/sortable_header')
local SORT_SPEC = sort_state.new_spec({'label', 'value'}, {value=true})

SoulSearchStatsPanel = defclass(SoulSearchStatsPanel, widgets.Panel)
SoulSearchStatsPanel.ATTRS{
    subject=DEFAULT_NIL,
    sort=DEFAULT_NIL,
    on_sort_change=DEFAULT_NIL,
}

function SoulSearchStatsPanel:init(info)
    self.subject = info.subject
    self.sort = sort_state.normalize(info.sort, SORT_SPEC)
    self.on_sort_change = info.on_sort_change
    self.stats_records = {}
    -- widgets.Panel initializes its on_layout attribute to nil, so a class
    -- method of that name would be shadowed before postComputeFrame() runs.
    -- Register the callback on this instance instead.
    self.on_layout = function(frame_body)
        self:layout_contents(frame_body)
    end
    self:addviews{
        widgets.Label{view_id='title', frame={l=0,t=0,h=1}, text='Stats', text_pen=COLOR_WHITE},
        widgets.Label{view_id='underline', frame={l=0,t=1,h=1}, text='-----', text_pen=COLOR_GREY},
        widgets.Label{view_id='header', auto_height=false, text='No unit selected.'},
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
function SoulSearchStatsPanel:get_sort() return copy_sort(self.sort) end
function SoulSearchStatsPanel:set_subject(subject) self.subject = subject; self:refresh() end
function SoulSearchStatsPanel:set_sort(sort) self.sort = copy_sort(sort); self:refresh() end
function SoulSearchStatsPanel:reset_view_state(sort)
    self.sort = copy_sort(sort)
    self.subviews.body.start_line_num = 1
    self:refresh()
end
function SoulSearchStatsPanel:cycle_sort(column)
    self.sort = sort_state.next(self.sort, column, SORT_SPEC)
    self:refresh()
    if self.on_sort_change then self.on_sort_change(self:get_sort()) end
end
function SoulSearchStatsPanel:refresh()
    local sort = self.sort
    self.subviews.header:setText(presenter.header(self.subject))
    sortable_header.set_sort(self.subviews.columns, sort.key == 'label', sort.reverse)
    sortable_header.set_sort(self.subviews.value_column, sort.key == 'value', sort.reverse)
    self.subviews.body:setText(presenter.body(self.subject, sort.key, sort.reverse))
    self.stats_records = presenter.get_display_records(self.subject, sort.key, sort.reverse)
    -- A changed subject can change the header height. Once the panel has been
    -- attached, refresh its own layout so the body begins below that header.
    -- Initial construction is laid out by the owning view.
    if self.frame_parent_rect then self:updateLayout() end
end
function SoulSearchStatsPanel:layout_contents(frame_body)
    local frames = layout.get_content_frames(frame_body.height,
        self.subviews.header:getTextHeight(), self.subviews.columns:getTextHeight())
    self.subviews.header.frame = frames.header
    self.subviews.columns.frame = frames.columns
    self.subviews.body.frame = frames.body
end
function SoulSearchStatsPanel:get_tooltip_text()
    local header_x, header_y = self.subviews.columns:getMousePos()
    if header_x and header_y == 0 then return 'Sort by stat name.' end
    header_x, header_y = self.subviews.value_column:getMousePos()
    if header_x and header_y == 0 then return 'Sort by baseline difference.' end
    local x, y = self.subviews.body:getMousePos()
    if layout.is_value_cell(x, y) then return 'Difference from the attribute average.' end
    if layout.is_label_cell(x, y) then
        local record = self.stats_records[(self.subviews.body.start_line_num or 1) + y]
        return record and descriptions.get_tooltip(record.kind, record.key) or nil
    end
    return nil
end

return SoulSearchStatsPanel
