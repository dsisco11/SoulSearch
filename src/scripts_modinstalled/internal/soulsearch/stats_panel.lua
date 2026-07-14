--@ module=true

local widgets = require('gui.widgets')
local descriptions = reqscript('internal/soulsearch/attribute_descriptions')
local presenter = reqscript('internal/soulsearch/stats_presenter')
local layout = reqscript('internal/soulsearch/stats_layout')
local sort_state = reqscript('internal/soulsearch/stats_sort')

local SortableHeader = defclass(SoulSearchStatsSortableHeader, widgets.Label)
function SortableHeader:init(info) self.owner = info.owner end
function SortableHeader:onInput(keys)
    if keys._MOUSE_L then
        local x, y = self:getMousePos()
        local column = layout.get_header_column(x, y)
        if column then self.owner:cycle_sort(column); return true end
    end
    return SortableHeader.super.onInput(self, keys)
end

SoulSearchStatsPanel = defclass(SoulSearchStatsPanel, widgets.Panel)
SoulSearchStatsPanel.ATTRS{
    subject=DEFAULT_NIL,
    sort=DEFAULT_NIL,
    on_sort_change=DEFAULT_NIL,
}

function SoulSearchStatsPanel:init(info)
    self.subject = info.subject
    self.sort = sort_state.normalize(info.sort)
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
        SortableHeader{view_id='columns', auto_height=false, text='', owner=self},
        widgets.Label{view_id='body', auto_height=false, text=''},
    }
    self:refresh()
end

local function copy_sort(value) return sort_state.normalize(value) end
function SoulSearchStatsPanel:get_sort() return copy_sort(self.sort) end
function SoulSearchStatsPanel:set_subject(subject) self.subject = subject; self:refresh() end
function SoulSearchStatsPanel:set_sort(sort) self.sort = copy_sort(sort); self:refresh() end
function SoulSearchStatsPanel:reset_view_state(sort)
    self.sort = copy_sort(sort)
    self.subviews.body.start_line_num = 1
    self:refresh()
end
function SoulSearchStatsPanel:cycle_sort(column)
    self.sort = sort_state.next(self.sort, column)
    self:refresh()
    if self.on_sort_change then self.on_sort_change(self:get_sort()) end
end
function SoulSearchStatsPanel:refresh()
    local sort = self.sort
    self.subviews.header:setText(presenter.header(self.subject))
    self.subviews.columns:setText(presenter.column_header(sort.key, sort.reverse))
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
    local column = layout.get_header_column(header_x, header_y)
    if column == 'label' then return 'Sort by stat name.' end
    if column == 'value' then return 'Sort by baseline difference.' end
    local x, y = self.subviews.body:getMousePos()
    if layout.is_value_cell(x, y) then return 'Difference from the attribute average.' end
    if layout.is_label_cell(x, y) then
        local record = self.stats_records[(self.subviews.body.start_line_num or 1) + y]
        return record and descriptions.get_tooltip(record.kind, record.key) or nil
    end
    return nil
end

return SoulSearchStatsPanel
