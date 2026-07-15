--@ module=true

local widgets = require('gui.widgets')
local ui_layout = reqscript('internal/soulsearch/ui_layout')

---@class SoulSearchUnitScopePickerInputs
---@field options {label: string, value: SoulSearchUnitScope}[]
---@field on_select fun(scope: SoulSearchUnitScope)

---Popup widget that owns the unit-scope list while the host owns scope state.
---@class UnitScopePicker: widgets.Window
---@field inputs SoulSearchUnitScopePickerInputs
UnitScopePicker = defclass(UnitScopePicker, widgets.Window)

function UnitScopePicker:init(info)
    self.inputs = info.inputs
    local inputs = self.inputs
    self:addviews{
            widgets.List{
                view_id='unit_scope_picker_list',
                frame=ui_layout.get_unit_scope_picker_list_frame(#inputs.options),
                on_submit=function(_, choice)
                    if choice and choice.scope then inputs.on_select(choice.scope) end
                end,
            },
    }
end
