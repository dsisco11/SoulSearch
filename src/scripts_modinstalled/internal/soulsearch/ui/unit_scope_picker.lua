--@ module=true

local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local ModalPanelWindow =
    reqscript('internal/soulsearch/ui/modal_panel').ModalPanelWindow

---@class SoulSearchUnitScopePickerInputs
---@field options {label: string, value: SoulSearchUnitScope}[]
---@field on_select fun(scope: SoulSearchUnitScope)

---Popup widget that owns the unit-scope list while the host owns scope state.
---@class UnitScopePicker: ModalPanelWindow
---@field inputs SoulSearchUnitScopePickerInputs
UnitScopePicker = defclass(UnitScopePicker, ModalPanelWindow)

function UnitScopePicker:init(info)
    UnitScopePicker.super.init(self, info)
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
