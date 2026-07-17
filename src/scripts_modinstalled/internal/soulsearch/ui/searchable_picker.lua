--@ module=true

local widgets = require('gui.widgets')
reqscript('internal/soulsearch/ui/widget_extensions')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local descriptions = reqscript('internal/soulsearch/attribute_descriptions')
local filter_constants = reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS
local ModalPanelWindow =
    reqscript('internal/soulsearch/ui/modal_panel').ModalPanelWindow

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
    unit_scope={
        close_id='close_unit_scope_picker_button', search_id='unit_scope_search_field',
        list_id='available_unit_scope_list', key='CUSTOM_U',
    },
}
local FILTER_KIND_RACE = filter_constants.kind.RACE

---Popup widget shared by the attribute, skill, and race pickers. It owns its
---child views while the host retains query filtering and descriptor semantics.
---@class SearchablePicker: ModalPanelWindow
---@field inputs SoulSearchSearchablePickerInputs
SearchablePicker = defclass(SearchablePicker, ModalPanelWindow)

function SearchablePicker:init(info)
    SearchablePicker.super.init(self, info)
    self.inputs = info.inputs
    local inputs = self.inputs
    local config = assert(PICKER_CONFIGS[info.kind], 'unknown searchable picker kind')
    self:addviews{
            widgets.TextButton{
                view_id=config.close_id,
                frame=ui_layout.get_frame('picker_close'),
                label='X',
                tooltip='Close',
                on_activate=function() self:close() end,
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
                on_pointer_update=function(target, _, y)
                    local index = (target.start_line_num or 1) + y
                    local choice = self.choices and self.choices[index]
                    local descriptor = choice and choice.descriptor
                    if descriptor and descriptor.kind == FILTER_KIND_RACE then
                        target.tooltip = 'Filters by a creatures race.'
                    elseif descriptor and descriptor.kind == filter_constants.kind.UNIT_SCOPE then
                        target.tooltip = 'Filters which active units are considered.'
                    elseif descriptor and self.kind == 'attribute' then
                        target.tooltip = descriptions.get_tooltip(descriptor.kind, descriptor.key)
                    else
                        target.tooltip = nil
                    end
                end,
                on_submit=function(_, choice) inputs.on_submit(choice) end,
            },
    }
    self.kind = info.kind
end

---@param choices table[]
---@param selected integer|nil
function SearchablePicker:set_choices(choices, selected)
    self.choices = choices or {}
    local config = assert(PICKER_CONFIGS[self.kind], 'unknown searchable picker kind')
    self.subviews[config.list_id]:setChoices(self.choices, selected)
end
