--@ module=true

local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')

---Unit name and title header used by the unit information panel.
---@class UnitIdentity: widgets.Panel
---@field subject SoulSearchStatsSubject|nil
UnitIdentity = defclass(UnitIdentity, widgets.Panel)
UnitIdentity.ATTRS{subject=DEFAULT_NIL}

function UnitIdentity:init(info)
    self.subject = info.subject
    self:addviews{
        widgets.Label{view_id='name', frame={l=0, t=0, r=0, h=1},
            auto_height=false, text='No unit selected.', text_pen=COLOR_WHITE},
        widgets.Label{view_id='title', frame={l=0, t=1, r=0, h=1},
            auto_height=false, text='', text_pen=COLOR_DARKGREY},
    }
    self:refresh()
end

function UnitIdentity:set_subject(subject)
    self.subject = subject
    self:refresh()
end

function UnitIdentity:refresh()
    local subject = self.subject
    local has_subject = subject and subject.row
    self.subviews.name:setText(has_subject and (subject.name or 'Unknown unit') or
        'No unit selected.')
    self.subviews.title:setText(has_subject and (subject.profession or '') or '')
    self.has_subject = has_subject and true or false
end

---Returns the rendered identity height, including its intentional spacer row.
function UnitIdentity:get_height()
    return self.has_subject and 3 or 1
end

return UnitIdentity
