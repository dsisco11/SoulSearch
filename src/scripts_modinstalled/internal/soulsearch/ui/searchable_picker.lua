--@ module=true

local widgets = require('gui.widgets')
local ui_layout = reqscript('internal/soulsearch/ui_layout')

---@class SoulSearchSearchablePickerInputs
---@field on_query fun(text: string)
---@field on_close fun()
---@field on_submit fun(choice: table|nil)

local PICKER_CONFIGS = {
    attribute={
        close_id='close_filter_picker_button', search_id='attribute_search_field',
        list_id='available_filter_list', key='CUSTOM_T',
    },
    skill={
        close_id='close_skill_picker_button', search_id='skill_search_field',
        list_id='available_skill_list', key='CUSTOM_K',
    },
    race={
        close_id='close_race_picker_button', search_id='race_search_field',
        list_id='available_race_list', key='CUSTOM_G',
    },
}

---Popup widget shared by the attribute, skill, and race pickers. It owns its
---child views while the host retains query filtering and descriptor semantics.
---@class SearchablePicker: widgets.Window
---@field inputs SoulSearchSearchablePickerInputs
SearchablePicker = defclass(SearchablePicker, widgets.Window)

function SearchablePicker:init(info)
    self.inputs = info.inputs
    local inputs = self.inputs
    local config = assert(PICKER_CONFIGS[info.kind], 'unknown searchable picker kind')
    self:addviews{
            widgets.TextButton{
                view_id=config.close_id,
                frame=ui_layout.get_frame('picker_close'),
                label='X',
                on_activate=inputs.on_close,
            },
            widgets.EditField{
                view_id=config.search_id,
                frame=ui_layout.get_frame('picker_search'),
                label_text='Search: ',
                key=config.key,
                on_change=inputs.on_query,
            },
            widgets.List{
                view_id=config.list_id,
                frame=ui_layout.get_frame('picker_list'),
                on_submit=function(_, choice) inputs.on_submit(choice) end,
            },
    }
end
