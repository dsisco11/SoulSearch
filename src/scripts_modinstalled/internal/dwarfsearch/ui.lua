--@ module=true

local gui = require('gui')
local widgets = require('gui.widgets')

local residents = reqscript('internal/dwarfsearch/residents')
local search = reqscript('internal/dwarfsearch/search')

local view

local function truncate(text, width)
    text = tostring(text or '')
    if width <= 0 or #text <= width then
        return text
    end
    if width <= 3 then
        return text:sub(1, width)
    end
    return text:sub(1, width - 3) .. '...'
end

local function format_position(pos)
    if not pos then
        return 'unknown'
    end
    return ('%d, %d, %d'):format(pos.x, pos.y, pos.z)
end

local function make_position(x, y, z)
    if type(x) == 'table' then
        return {x=x.x, y=x.y, z=x.z}
    end
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then
        return nil
    end
    if x < 0 or y < 0 or z < 0 then
        return nil
    end
    return {x=x, y=y, z=z}
end

local function format_result_choice(result)
    return ('%-5s %-32s %s'):format(
        result.match_label,
        truncate(result.name, 32),
        truncate(result.profession or '', 24))
end

local function format_filter_choice(descriptor, selected)
    local marker = selected and '[x]' or '[ ]'
    local kind = 'Soul'
    if descriptor.kind == 'trait' then
        kind = 'Trait'
    elseif descriptor.kind == 'physical_attribute' then
        kind = 'Body'
    end
    return ('%s %-5s %s'):format(marker, kind, descriptor.label)
end

local function details_for_result(result)
    if not result then
        return 'No resident selected.'
    end

    local lines = {
        ('Name: %s'):format(result.name),
        ('Profession: %s'):format(result.profession or 'unknown'),
        ('Position: %s'):format(format_position(result.position)),
        ('Matches: %s'):format(result.match_label),
    }

    if #result.matched_criteria > 0 then
        table.insert(lines, 'Matched criteria:')
        for _, criterion in ipairs(result.matched_criteria) do
            table.insert(lines, ('  %s: %s'):format(criterion.label, criterion.value))
        end
    else
        table.insert(lines, 'Matched criteria: none')
    end

    return table.concat(lines, '\n')
end

local function get_live_position(result)
    if not result or not result.unit then
        return nil
    end

    local ok, x, y, z = pcall(dfhack.units.getPosition, result.unit)
    if ok then
        return make_position(x, y, z)
    end
    return nil
end

DwarfSearchWindow = defclass(DwarfSearchWindow, widgets.Window)
DwarfSearchWindow.ATTRS {
    frame_title='DwarfSearch',
    frame={w=120, h=45, xalign=0.5, yalign=0.5},
    resizable=true,
    resize_min={w=90, h=30},
}

function DwarfSearchWindow:init()
    self.rows = {}
    self.results = {}
    self.query = ''
    self.selected_filter_ids = {}
    self.selected_filter_id_set = {}
    self.filter_descriptors = search.get_flat_filter_descriptors()

    self:addviews{
        widgets.EditField{
            view_id='search_field',
            frame={l=1, t=0, r=1, h=1},
            label_text='Search: ',
            key='CUSTOM_F',
            modal=true,
            on_change=function(text)
                self.query = text
                self:update_results()
            end,
        },
        widgets.Label{
            frame={l=1, t=2, w=38, h=1},
            text='Search filters',
            text_pen=COLOR_LIGHTCYAN,
        },
        widgets.List{
            view_id='filter_list',
            frame={l=1, t=3, w=38, b=3},
            on_submit=function(index, choice)
                if choice and choice.descriptor then
                    self:toggle_filter(choice.descriptor.id)
                end
            end,
        },
        widgets.Label{
            view_id='result_header',
            frame={l=41, t=2, r=1, h=1},
            text='Results',
            text_pen=COLOR_LIGHTCYAN,
        },
        widgets.List{
            view_id='result_list',
            frame={l=41, t=3, r=1, b=10},
            on_select=function(index, choice)
                self:update_details(choice and choice.result or nil)
            end,
            on_submit=function(index, choice)
                self:zoom_to_result(choice and choice.result or nil)
            end,
        },
        widgets.Label{
            view_id='details',
            frame={l=41, r=1, b=3, h=6},
            text='No resident selected.',
        },
        widgets.HotkeyLabel{
            frame={l=1, b=1, w=18, h=1},
            key='CUSTOM_R',
            label='Refresh',
            on_activate=function() self:refresh_residents() end,
        },
        widgets.HotkeyLabel{
            frame={l=20, b=1, w=18, h=1},
            key='CUSTOM_Z',
            label='Zoom',
            on_activate=function() self:zoom_to_selected_result() end,
        },
        widgets.HotkeyLabel{
            frame={l=39, b=1, w=16, h=1},
            key='LEAVESCREEN',
            label='Close',
            on_activate=function() self.parent_view:dismiss() end,
        },
    }

    self:refresh_residents()
    self:update_filter_choices()
end

function DwarfSearchWindow:get_selected_filter_ids()
    local ids = {}
    for _, descriptor in ipairs(self.filter_descriptors) do
        if self.selected_filter_id_set[descriptor.id] then
            table.insert(ids, descriptor.id)
        end
    end
    return ids
end

function DwarfSearchWindow:update_filter_choices(selected)
    local choices = {}
    for _, descriptor in ipairs(self.filter_descriptors) do
        table.insert(choices, {
            text=format_filter_choice(descriptor, self.selected_filter_id_set[descriptor.id]),
            descriptor=descriptor,
            search_key=descriptor.label,
        })
    end
    if #choices == 0 then
        table.insert(choices, {text='No search filters found.'})
    end
    self.subviews.filter_list:setChoices(choices, selected)
end

function DwarfSearchWindow:update_results()
    self.selected_filter_ids = self:get_selected_filter_ids()
    self.results = search.apply(self.rows, {
        query=self.query,
        selected_filter_ids=self.selected_filter_ids,
    })

    local choices = {}
    for _, result in ipairs(self.results) do
        table.insert(choices, {
            text=format_result_choice(result),
            result=result,
            search_key=result.name,
        })
    end

    self.subviews.result_header:setText(('Results (%d)'):format(#choices))
    self.subviews.result_list:setChoices(choices, 1)
    local _, choice = self.subviews.result_list:getSelected()
    self:update_details(choice and choice.result or nil)
end

function DwarfSearchWindow:update_details(result)
    self.subviews.details:setText(details_for_result(result))
end

function DwarfSearchWindow:get_selected_result()
    local _, choice = self.subviews.result_list:getSelected()
    return choice and choice.result or nil
end

function DwarfSearchWindow:zoom_to_selected_result()
    self:zoom_to_result(self:get_selected_result())
end

function DwarfSearchWindow:zoom_to_result(result)
    if not result then
        print('DwarfSearch: no resident selected.')
        return
    end

    local pos = get_live_position(result)
    if not pos then
        print(('DwarfSearch: %s does not have a valid map position.'):format(result.name))
        return
    end

    dfhack.gui.revealInDwarfmodeMap(pos, true, true)
end

function DwarfSearchWindow:toggle_filter(filter_id)
    self.selected_filter_id_set[filter_id] = not self.selected_filter_id_set[filter_id] or nil
    local selected = self.subviews.filter_list:getSelected()
    self:update_filter_choices(selected)
    self:update_results()
end

function DwarfSearchWindow:refresh_residents()
    local rows, err = residents.collect_residents()
    if not rows then
        print(err)
        self.rows = {}
    else
        self.rows = rows
    end
    self:update_results()
end

function DwarfSearchWindow:onInput(keys)
    if keys.CUSTOM_R then
        self:refresh_residents()
        return true
    end
    if keys.CUSTOM_Z then
        self:zoom_to_selected_result()
        return true
    end
    return DwarfSearchWindow.super.onInput(self, keys)
end

DwarfSearchScreen = defclass(DwarfSearchScreen, gui.ZScreen)
DwarfSearchScreen.ATTRS {
    focus_path='dwarfsearch',
}

function DwarfSearchScreen:init()
    self:addviews{DwarfSearchWindow{}}
end

function DwarfSearchScreen:onDismiss()
    view = nil
end

function open(...)
    local err = residents.get_unavailable_reason()
    if err then
        print(err)
        return
    end

    view = view and view:raise() or DwarfSearchScreen{}:show()
end
