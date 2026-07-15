--@ module=true

local widgets = require('gui.widgets')
local ui_layout = reqscript('internal/soulsearch/ui_layout')

---@class SoulSearchSearchablePickerInputs
---@field window_id string
---@field list_id string
---@field search_id string
---@field close_id string
---@field title string
---@field visible fun(): boolean
---@field key string
---@field on_query fun(text: string)
---@field on_close fun()
---@field on_submit fun(choice: table|nil)

---Popup widget shared by the attribute, skill, and race pickers. It owns its
---child views while the host retains query filtering and descriptor semantics.
---@class SearchablePicker: widgets.Window
---@field inputs SoulSearchSearchablePickerInputs
SearchablePicker = defclass(SearchablePicker, widgets.Window)

function SearchablePicker:init(info)
    self.inputs = info.inputs
    local inputs = self.inputs
    self:addviews{
            widgets.TextButton{
                view_id=inputs.close_id,
                frame=ui_layout.get_frame('picker_close'),
                label='X',
                on_activate=inputs.on_close,
            },
            widgets.EditField{
                view_id=inputs.search_id,
                frame=ui_layout.get_frame('picker_search'),
                label_text='Search: ',
                key=inputs.key,
                on_change=inputs.on_query,
            },
            widgets.List{
                view_id=inputs.list_id,
                frame=ui_layout.get_frame('picker_list'),
                on_submit=function(_, choice) inputs.on_submit(choice) end,
            },
    }
end
