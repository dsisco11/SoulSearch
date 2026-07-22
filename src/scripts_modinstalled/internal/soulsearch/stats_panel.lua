--@ module=true

local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')
local layout = reqscript('internal/soulsearch/stats_layout')
local UnitIdentity = reqscript('internal/soulsearch/ui/unit_identity').UnitIdentity
local MatchedFiltersPanel = reqscript(
    'internal/soulsearch/ui/matched_filters_panel').MatchedFiltersPanel
local UnitStatsList = reqscript('internal/soulsearch/ui/unit_stats_list').UnitStatsList

---Main-window unit information panel that composes its identity, matched-filter,
---and reusable sortable stat-list sections.
UnitInfoPanel = defclass(UnitInfoPanel, widgets.Panel)
UnitInfoPanel.ATTRS{
    subject=DEFAULT_NIL,
    sort=DEFAULT_NIL,
    on_sort_change=DEFAULT_NIL,
}

---Initializes identity, matched-filter, and sortable-stat subpanels.
---@param info table unit information construction parameters
function UnitInfoPanel:init(info)
    self.subject, self.sort, self.on_sort_change = info.subject, info.sort, info.on_sort_change
    self.on_layout = function(frame_body) self:layout_contents(frame_body) end
    self:addviews{
        UnitIdentity{view_id='unit_identity', frame={l=0, t=0, r=0, h=1},
            subject=self.subject},
        MatchedFiltersPanel{view_id='matched_filters', frame={l=0, t=1, r=0, h=0},
            subject=self.subject},
        UnitStatsList{view_id='stats_list', frame={l=0,t=1,r=0,b=0},
            subject=self.subject, sort=self.sort,
            on_sort_change=function(sort)
                self.sort = sort
                if self.on_sort_change then self.on_sort_change(sort) end
            end},
    }
    self:refresh()
end

function UnitInfoPanel:get_sort() return self.subviews.stats_list:get_sort() end
function UnitInfoPanel:set_subject(subject) self.subject = subject; self:refresh() end
function UnitInfoPanel:set_sort(sort)
    self.sort = sort
    self.subviews.stats_list:set_sort(sort)
end
function UnitInfoPanel:reset_view_state(sort)
    self.sort = sort
    self.subviews.stats_list:reset_view_state(sort)
end
function UnitInfoPanel:cycle_sort(column) self.subviews.stats_list:cycle_sort(column) end
function UnitInfoPanel:refresh()
    self.subviews.unit_identity:set_subject(self.subject)
    self.subviews.matched_filters:set_subject(self.subject)
    self.subviews.stats_list:set_subject(self.subject)
    if self.frame_parent_rect then self:updateLayout() end
end
function UnitInfoPanel:layout_contents(frame_body)
    local identity_height = self.subviews.unit_identity:get_height()
    local matched_filters_height = self.subviews.matched_filters:get_height()
    local frames = layout.get_content_frames(frame_body.height,
        identity_height + matched_filters_height, 1)
    self.subviews.unit_identity.frame = {l=0, t=frames.header.t, r=0, h=identity_height}
    self.subviews.matched_filters.frame = {
        l=0, t=identity_height, r=0, h=matched_filters_height,
    }
    self.subviews.stats_list.frame = {l=0, t=frames.columns.t, r=0, b=0}
    self.subviews.stats_list:set_header_height(frames.columns.h)
end
return UnitInfoPanel
