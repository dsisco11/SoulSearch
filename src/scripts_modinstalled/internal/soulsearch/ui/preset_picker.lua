--@ module=true

local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local ModalPanelWindow =
    reqscript('internal/soulsearch/ui/modal_panel').ModalPanelWindow

---@class SoulSearchPresetPickerInputs
---@field on_close fun()
---@field on_save fun()
---@field on_query fun(text: string)
---@field on_load fun(name: string)
---@field on_load_default fun(id: string)
---@field on_load_role fun(id: string)

---Popup widget that owns the preset picker child views and dispatches preset
---actions through the host callbacks.
---@class PresetPicker: ModalPanelWindow
---@field inputs SoulSearchPresetPickerInputs
PresetPicker = defclass(PresetPicker, ModalPanelWindow)

function PresetPicker:init(info)
    PresetPicker.super.init(self, info)
    self.inputs = info.inputs
    local inputs = self.inputs
    self:addviews{
            widgets.TextButton{
                view_id='close_preset_picker_button',
                frame=ui_layout.get_frame('picker_close'),
                label='X', on_activate=function() self:close() end,
            },
            widgets.TextButton{
                view_id='save_preset_button',
                frame=ui_layout.get_frame('preset_save'),
                key='CUSTOM_W', label='Save preset', on_activate=inputs.on_save,
            },
            widgets.EditField{
                view_id='preset_search_field',
                frame=ui_layout.get_frame('preset_search'),
                label_text='Search: ', key='CUSTOM_F', on_change=inputs.on_query,
            },
            widgets.List{
                view_id='preset_list', frame=ui_layout.get_frame('preset_list'),
                on_submit=function(_, choice)
                    if choice and choice.role_id then
                        inputs.on_load_role(choice.role_id)
                    elseif choice and choice.default_id then
                        inputs.on_load_default(choice.default_id)
                    elseif choice and choice.name then
                        inputs.on_load(choice.name)
                    end
                end,
            },
    }
end
