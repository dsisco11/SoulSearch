--@ module=true

local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')
local ui_format = reqscript('internal/soulsearch/ui_format')

---Selected-filter title and criteria display used by the unit information panel.
---@class MatchedFiltersPanel: widgets.Panel
---@field subject SoulSearchStatsSubject|nil
MatchedFiltersPanel = defclass(MatchedFiltersPanel, widgets.Panel)
MatchedFiltersPanel.ATTRS{subject=DEFAULT_NIL}

function MatchedFiltersPanel:init(info)
    self.subject = info.subject
    self:addviews{
        widgets.Label{view_id='filters', frame={l=0, t=0, r=0, b=0},
            auto_height=false, text=''},
    }
    self:refresh()
end

function MatchedFiltersPanel:set_subject(subject)
    self.subject = subject
    self:refresh()
end

function MatchedFiltersPanel:refresh()
    local criteria = self.subject and self.subject.filter_criteria
    self.has_filters = criteria and #criteria > 0 or false
    local tokens = {}
    ui_format.append_selected_filter_section_tokens(tokens, criteria)
    self.subviews.filters:setText(tokens)
end

function MatchedFiltersPanel:get_height()
    return self.has_filters and self.subviews.filters:getTextHeight() or 0
end

return MatchedFiltersPanel
