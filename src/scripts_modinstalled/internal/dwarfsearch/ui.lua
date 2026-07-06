--@ module=true

local gui = require('gui')
local widgets = require('gui.widgets')

local residents = reqscript('internal/dwarfsearch/residents')
local search = reqscript('internal/dwarfsearch/search')
local attributes = reqscript('internal/dwarfsearch/attributes')

local view
local saved_filter_modes = {}
local saved_filter_order = {}
local SECTION_DIVIDER_PEN = COLOR_DARKGREY
local SECTION_DIVIDER_XS = {39, 105}
local FILTER_HIGH = 'high'
local FILTER_LOW = 'low'
local MATCHED_FILTER_LABEL_WIDTH = 24
local MATCHED_FILTER_VALUE_WIDTH = 6
local TITLE_UNDERLINE_PEN = COLOR_GREY
local FILTER_ACTION_PLUS = 'plus'
local FILTER_ACTION_MINUS = 'minus'
local FILTER_ACTION_REMOVE = 'remove'
local FILTER_ACTION_UP = 'up'
local FILTER_ACTION_DOWN = 'down'
local FILTER_ACTION_WIDTH = 3
local ACTIVE_FILTER_BUTTON_START_X = 21
local ACTIVE_FILTER_LABEL_WIDTH = ACTIVE_FILTER_BUTTON_START_X - 1
local ADD_FILTER_LABEL = 'Add attribute/trait'
local CLOSE_FILTER_MENU_LABEL = 'Close attribute menu'
local ADD_SKILL_LABEL = 'Add skill'
local CLOSE_SKILL_MENU_LABEL = 'Close skill menu'
local SKILL_CATEGORY_ORDER = {
    'Labor',
    'Combat',
    'Social',
    'Other Skills',
    'Knowledge',
}

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

local function contains_text(haystack, needle)
    if not needle or needle == '' then
        return true
    end
    return tostring(haystack or ''):lower():find(needle:lower(), 1, true) ~= nil
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
    return ('%-45s %s'):format(
        truncate(result.name, 45),
        truncate(result.profession or '', 18))
end

local function get_category_pen(descriptor)
    if descriptor.kind == 'skill' then
        return COLOR_YELLOW
    end
    if descriptor.kind == 'physical_attribute' then
        return COLOR_LIGHTGREEN
    end
    if descriptor.kind == 'mental_attribute' then
        return COLOR_LIGHTBLUE
    end
    return COLOR_LIGHTMAGENTA
end

local function get_category_info(kind)
    if kind == 'physical_attribute' then
        return 'Body', COLOR_LIGHTGREEN
    end
    if kind == 'mental_attribute' then
        return 'Soul', COLOR_LIGHTBLUE
    end
    return 'Mind', COLOR_LIGHTMAGENTA
end

local function get_deviation_pen(deviation, tier_distance)
    if deviation < 0 then
        if tier_distance >= 2 then
            return COLOR_LIGHTRED
        end
        return COLOR_RED
    end
    if tier_distance >= 4 then
        return COLOR_LIGHTGREEN
    end
    if tier_distance >= 2 then
        return COLOR_LIGHTGREEN
    end
    return COLOR_GREEN
end

local function format_deviation(deviation)
    if deviation > 0 then
        return ('+%d'):format(deviation)
    end
    return tostring(deviation)
end

local function format_skill_value(value)
    value = math.floor((value or 0) * 10) / 10
    return ('%.1f'):format(value)
end

local function format_evaluation_value(criterion, evaluation)
    if criterion.kind == 'skill' then
        return format_skill_value(evaluation.value)
    end
    return format_deviation(evaluation.deviation)
end

local function get_title_underline(title)
    return ('-'):rep(#tostring(title or ''))
end

local function add_underlined_title(tokens, title, pen)
    table.insert(tokens, {text=title, pen=pen})
    table.insert(tokens, NEWLINE)
    table.insert(tokens, {text=get_title_underline(title), pen=pen})
    table.insert(tokens, NEWLINE)
end

local function format_active_filter_choice(descriptor, mode, priority_index, priority_count)
    local high_selected = mode == FILTER_HIGH
    local low_selected = mode == FILTER_LOW
    local can_move_up = priority_index and priority_index > 1
    local can_move_down = priority_index and priority_index < priority_count
    local label = truncate(descriptor.label, ACTIVE_FILTER_LABEL_WIDTH)
    local spacer_width = math.max(1, ACTIVE_FILTER_BUTTON_START_X - #label)
    return {
        {text=label, pen=get_category_pen(descriptor)},
        {text=(' '):rep(spacer_width), pen=COLOR_DARKGREY},
        {text='[+]', pen=high_selected and COLOR_LIGHTGREEN or COLOR_DARKGREY},
        {text='[-]', pen=low_selected and COLOR_LIGHTRED or COLOR_DARKGREY},
        {text='[^]', pen=can_move_up and COLOR_WHITE or COLOR_DARKGREY},
        {text='[v]', pen=can_move_down and COLOR_WHITE or COLOR_DARKGREY},
        {text='[x]', pen=COLOR_LIGHTRED},
    }
end

local function format_available_filter_choice(descriptor)
    return {
        {text=descriptor.label, pen=get_category_pen(descriptor)},
    }
end

local function format_available_skill_choice(descriptor)
    return {
        {text='  ', pen=COLOR_DARKGREY},
        {text=descriptor.label, pen=get_category_pen(descriptor)},
    }
end

local function format_skill_category_choice(category)
    return {
        {text=category, pen=COLOR_WHITE},
    }
end

local function get_filter_action_at_x(x)
    if not x then
        return nil
    end
    if x < ACTIVE_FILTER_BUTTON_START_X then
        return nil
    end

    x = x - ACTIVE_FILTER_BUTTON_START_X
    if x < FILTER_ACTION_WIDTH then
        return FILTER_ACTION_PLUS
    end
    if x < FILTER_ACTION_WIDTH * 2 then
        return FILTER_ACTION_MINUS
    end
    if x < FILTER_ACTION_WIDTH * 3 then
        return FILTER_ACTION_UP
    end
    if x < FILTER_ACTION_WIDTH * 4 then
        return FILTER_ACTION_DOWN
    end
    if x < FILTER_ACTION_WIDTH * 5 then
        return FILTER_ACTION_REMOVE
    end
    return nil
end

local function is_backspace_key(keys)
    return keys._BACKSPACE or keys.BACKSPACE or keys.KEYBOARD_BACKSPACE
end

local function copy_filter_modes(filter_modes)
    local copy = {}
    for filter_id, mode in pairs(filter_modes or {}) do
        copy[filter_id] = mode
    end
    return copy
end

local function copy_filter_order(filter_order)
    local copy = {}
    for _, filter_id in ipairs(filter_order or {}) do
        table.insert(copy, filter_id)
    end
    return copy
end

local function append_descriptors(target, descriptors)
    for _, descriptor in ipairs(descriptors or {}) do
        table.insert(target, descriptor)
    end
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

local function is_notable_value(kind, key, value, unit)
    local evaluation = attributes.evaluate(kind, key, value, unit)
    return evaluation and evaluation.tier_distance ~= 0
end

local function add_attribute_section(tokens, title, pen, kind, values, unit)
    add_underlined_title(tokens, title, pen)

    if not values or not unit then
        table.insert(tokens, {text='  none notable', pen=COLOR_DARKGREY})
        table.insert(tokens, NEWLINE)
        return
    end

    local keys = {}
    for key, value in pairs(values) do
        if is_notable_value(kind, key, value, unit) then
            table.insert(keys, key)
        end
    end
    table.sort(keys)

    if #keys == 0 then
        table.insert(tokens, {text='  none notable', pen=COLOR_DARKGREY})
        table.insert(tokens, NEWLINE)
        return
    end

    for _, key in ipairs(keys) do
        local label = key:gsub('_', ' '):lower():gsub('^%l', string.upper)
        local evaluation = attributes.evaluate(kind, key, values[key], unit)
        table.insert(tokens, {text=('  %-24s '):format(label), pen=pen})
        table.insert(tokens, {
            text=format_deviation(evaluation.deviation),
            pen=get_deviation_pen(evaluation.deviation, evaluation.tier_distance),
        })
        table.insert(tokens, NEWLINE)
    end
end

local function get_filter_criterion_pen(criterion, default_pen)
    if criterion.matched then
        return default_pen
    end
    return COLOR_DARKGREY
end

local function get_criterion_evaluation(criterion, unit)
    if criterion.deviation ~= nil and criterion.tier_distance ~= nil then
        return criterion
    end
    return attributes.evaluate(criterion.kind, criterion.key, criterion.value, unit)
end

local function add_selected_filter_section(tokens, filter_criteria, unit)
    if not filter_criteria or #filter_criteria == 0 then
        return
    end

    add_underlined_title(tokens, 'Selected filters', COLOR_WHITE)

    for _, criterion in ipairs(filter_criteria) do
        local is_low = criterion.direction == FILTER_LOW
        local evaluation = get_criterion_evaluation(criterion, unit)
        if evaluation then
            local direction_pen = get_filter_criterion_pen(
                criterion,
                is_low and COLOR_LIGHTRED or COLOR_LIGHTGREEN)
            local label_pen = get_filter_criterion_pen(criterion, get_category_pen(criterion))
            local value_pen = get_filter_criterion_pen(
                criterion,
                get_deviation_pen(evaluation.deviation, evaluation.tier_distance))
            table.insert(tokens, {text='  ', pen=COLOR_DARKGREY})
            table.insert(tokens, {text=is_low and '[-] ' or '[+] ', pen=direction_pen})
            table.insert(tokens, {text=('%-' .. MATCHED_FILTER_LABEL_WIDTH .. 's'):format(
                truncate(criterion.label, MATCHED_FILTER_LABEL_WIDTH)), pen=label_pen})
            table.insert(tokens, {text=('%' .. MATCHED_FILTER_VALUE_WIDTH .. 's'):format(
                format_evaluation_value(criterion, evaluation)), pen=value_pen})
            table.insert(tokens, NEWLINE)
        end
    end

    table.insert(tokens, NEWLINE)
end

local function attributes_for_result(result)
    if not result or not result.row then
        return 'No resident selected.'
    end

    local tokens = {}
    add_selected_filter_section(tokens, result.filter_criteria, result.unit)
    table.insert(tokens, {text=result.name or 'Unknown resident', pen=COLOR_WHITE})
    table.insert(tokens, NEWLINE)
    table.insert(tokens, NEWLINE)

    local body_label, body_pen = get_category_info('physical_attribute')
    local soul_label, soul_pen = get_category_info('mental_attribute')
    local mind_label, mind_pen = get_category_info('trait')

    add_attribute_section(tokens, body_label, body_pen, 'physical_attribute', result.row.physical_attributes, result.unit)
    table.insert(tokens, NEWLINE)
    add_attribute_section(tokens, soul_label, soul_pen, 'mental_attribute', result.row.mental_attributes, result.unit)
    table.insert(tokens, NEWLINE)
    add_attribute_section(tokens, mind_label, mind_pen, 'trait', result.row.traits, result.unit)

    return tokens
end

local function normalize_frame_for_drag(window)
    window.frame = {
        l=window.frame_rect.x1,
        t=window.frame_rect.y1,
        w=window.frame_rect.width,
        h=window.frame_rect.height,
    }
end

local function draw_section_dividers(dc)
    local y2 = math.max(2, dc.height)
    for _, x in ipairs(SECTION_DIVIDER_XS) do
        for y = 2, y2 do
            dc:seek(x, y):char('|', SECTION_DIVIDER_PEN)
        end
    end
end

DwarfSearchWindow = defclass(DwarfSearchWindow, widgets.Window)
DwarfSearchWindow.ATTRS {
    frame_title='DwarfSearch',
    frame={w=150, h=45, xalign=0.5, yalign=0.5},
    resizable=true,
    resize_min={w=120, h=30},
}

function DwarfSearchWindow:init()
    self.rows = {}
    self.results = {}
    self.query = ''
    self.skill_query = ''
    self.add_filter_open = false
    self.add_skill_open = false
    local filter_descriptor_groups = search.get_filter_descriptors()
    self.filter_descriptors = search.get_flat_filter_descriptors()
    self.attribute_filter_descriptors = {}
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.physical_attributes)
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.mental_attributes)
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.traits)
    self.skill_filter_descriptors = filter_descriptor_groups.skills or {}
    self.selected_filters = {}
    self.selected_filter_modes = self:get_valid_filter_modes(saved_filter_modes)
    self.selected_filter_order = self:get_valid_filter_order(saved_filter_order)

    self:addviews{
        widgets.EditField{
            view_id='search_field',
            frame={l=41, t=4, w=64, h=1},
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
            text_pen=COLOR_WHITE,
        },
        widgets.Label{
            frame={l=1, t=3, w=38, h=1},
            text=get_title_underline('Search filters'),
            text_pen=TITLE_UNDERLINE_PEN,
        },
        widgets.HotkeyLabel{
            view_id='add_filter_button',
            frame={l=1, t=4, w=25, h=1},
            key='CUSTOM_A',
            label=ADD_FILTER_LABEL,
            on_activate=function() self:toggle_add_filter_dropdown() end,
        },
        widgets.HotkeyLabel{
            view_id='add_skill_button',
            frame={l=1, t=5, w=25, h=1},
            key='CUSTOM_S',
            label='Add skill',
            on_activate=function() self:toggle_add_skill_dropdown() end,
        },
        widgets.HotkeyLabel{
            frame={l=1, t=6, w=20, h=1},
            key='CUSTOM_C',
            label='Clear filters',
            on_activate=function() self:clear_filters() end,
        },
        widgets.List{
            view_id='filter_list',
            frame={l=1, t=8, w=38, b=0},
            visible=function() return not self.add_filter_open and not self.add_skill_open end,
        },
        widgets.List{
            view_id='available_filter_list',
            frame={l=1, t=8, w=38, b=0},
            visible=function() return self.add_filter_open end,
            on_submit=function(index, choice)
                if choice and choice.descriptor then
                    self:add_filter(choice.descriptor.id)
                end
            end,
        },
        widgets.EditField{
            view_id='skill_search_field',
            frame={l=1, t=8, w=38, h=1},
            label_text='Skill search: ',
            key='CUSTOM_K',
            modal=true,
            visible=function() return self.add_skill_open end,
            on_change=function(text)
                self.skill_query = text
                self:update_available_skill_choices()
            end,
        },
        widgets.List{
            view_id='available_skill_list',
            frame={l=1, t=10, w=38, b=0},
            visible=function() return self.add_skill_open end,
            on_submit=function(index, choice)
                if choice and choice.descriptor then
                    self:add_filter(choice.descriptor.id)
                end
            end,
        },
        widgets.Label{
            view_id='result_header',
            frame={l=41, t=2, w=64, h=1},
            text='Results',
            text_pen=COLOR_WHITE,
        },
        widgets.Label{
            view_id='result_header_underline',
            frame={l=41, t=3, w=64, h=1},
            text=get_title_underline('Results'),
            text_pen=TITLE_UNDERLINE_PEN,
        },
        widgets.List{
            view_id='result_list',
            frame={l=41, t=6, w=64, b=0},
            on_select=function(index, choice)
                self:update_attributes(choice and choice.result or nil)
            end,
            on_submit=function(index, choice)
                self:zoom_to_result(choice and choice.result or nil)
            end,
        },
        widgets.Label{
            frame={l=107, t=1, r=1, h=1},
            text='Attributes',
            text_pen=COLOR_WHITE,
        },
        widgets.Label{
            frame={l=107, t=2, r=1, h=1},
            text=get_title_underline('Attributes'),
            text_pen=TITLE_UNDERLINE_PEN,
        },
        widgets.Label{
            view_id='attributes',
            frame={l=107, t=3, r=1, b=0},
            text='No resident selected.',
        },
        widgets.HotkeyLabel{
            frame={r=1, t=0, w=16, h=1},
            key='LEAVESCREEN',
            label='Close',
            on_activate=function() self.parent_view:dismiss() end,
        },
    }

    self:refresh_residents()
    self:update_filter_choices()
    self:update_available_filter_choices()
    self:update_available_skill_choices()
end

function DwarfSearchWindow:onDragBegin()
    DwarfSearchWindow.super.onDragBegin(self)
    normalize_frame_for_drag(self)
end

function DwarfSearchWindow:onRenderBody(dc)
    DwarfSearchWindow.super.onRenderBody(self, dc)
    draw_section_dividers(dc)
end

function DwarfSearchWindow:get_selected_filters()
    local selected_filters = {}
    for _, filter_id in ipairs(self.selected_filter_order) do
        local mode = self.selected_filter_modes[filter_id]
        if mode then
            table.insert(selected_filters, {
                id=filter_id,
                direction=mode,
            })
        end
    end
    return selected_filters
end

function DwarfSearchWindow:get_filter_descriptor_by_id(filter_id)
    for _, descriptor in ipairs(self.filter_descriptors) do
        if descriptor.id == filter_id then
            return descriptor
        end
    end
    return nil
end

function DwarfSearchWindow:get_valid_filter_modes(filter_modes)
    local valid_modes = {}
    for filter_id, mode in pairs(filter_modes or {}) do
        if self:get_filter_descriptor_by_id(filter_id) then
            valid_modes[filter_id] = mode
        end
    end
    return valid_modes
end

function DwarfSearchWindow:get_valid_filter_order(filter_order)
    local valid_order = {}
    for _, filter_id in ipairs(filter_order or {}) do
        if self.selected_filter_modes[filter_id] and self:get_filter_descriptor_by_id(filter_id) then
            table.insert(valid_order, filter_id)
        end
    end
    return valid_order
end

function DwarfSearchWindow:save_filter_state()
    saved_filter_modes = copy_filter_modes(self.selected_filter_modes)
    saved_filter_order = copy_filter_order(self.selected_filter_order)
end

function DwarfSearchWindow:get_filter_priority(filter_id)
    for index, ordered_filter_id in ipairs(self.selected_filter_order) do
        if ordered_filter_id == filter_id then
            return index
        end
    end
    return nil
end

function DwarfSearchWindow:get_active_filter_descriptors()
    local descriptors = {}

    for _, filter_id in ipairs(self.selected_filter_order) do
        local descriptor = self:get_filter_descriptor_by_id(filter_id)
        if descriptor then
            table.insert(descriptors, descriptor)
        end
    end

    return descriptors
end

function DwarfSearchWindow:get_filter_choice_index(filter_id)
    for index, descriptor in ipairs(self:get_active_filter_descriptors()) do
        if descriptor.id == filter_id then
            return index
        end
    end
    return 1
end

function DwarfSearchWindow:update_filter_choices(selected)
    local choices = {}
    local priority_count = #self.selected_filter_order
    for _, descriptor in ipairs(self:get_active_filter_descriptors()) do
        table.insert(choices, {
            text=format_active_filter_choice(
                descriptor,
                self.selected_filter_modes[descriptor.id],
                self:get_filter_priority(descriptor.id),
                priority_count),
            descriptor=descriptor,
            search_key=descriptor.label,
        })
    end
    if #choices == 0 then
        table.insert(choices, {text='Use Add attribute/trait or Add skill.'})
    end
    self.subviews.filter_list:setChoices(choices, selected)
end

function DwarfSearchWindow:update_available_filter_choices(selected)
    local choices = {}
    for _, descriptor in ipairs(self.attribute_filter_descriptors) do
        if not self.selected_filter_modes[descriptor.id] then
            table.insert(choices, {
                text=format_available_filter_choice(descriptor),
                descriptor=descriptor,
                search_key=descriptor.label,
            })
        end
    end
    if #choices == 0 then
        table.insert(choices, {text='All attributes have been added.'})
    end
    self.subviews.available_filter_list:setChoices(choices, selected)
end

function DwarfSearchWindow:update_available_skill_choices(selected)
    local choices = {}
    local choices_by_category = {}
    for _, descriptor in ipairs(self.skill_filter_descriptors) do
        if not self.selected_filter_modes[descriptor.id] and
                contains_text(descriptor.label, self.skill_query) then
            local category = descriptor.category or 'Other Skills'
            choices_by_category[category] = choices_by_category[category] or {}
            table.insert(choices_by_category[category], {
                text=format_available_skill_choice(descriptor),
                descriptor=descriptor,
                search_key=descriptor.label,
            })
        end
    end
    for _, category in ipairs(SKILL_CATEGORY_ORDER) do
        local category_choices = choices_by_category[category]
        if category_choices and #category_choices > 0 then
            table.insert(choices, {
                text=format_skill_category_choice(category),
                search_key=category,
            })
            for _, choice in ipairs(category_choices) do
                table.insert(choices, choice)
            end
        end
    end
    if #choices == 0 then
        table.insert(choices, {text='No matching skills.'})
    end
    self.subviews.available_skill_list:setChoices(choices, selected)
end

function DwarfSearchWindow:update_results()
    self:save_filter_state()
    self.selected_filters = self:get_selected_filters()
    self.results = search.apply(self.rows, {
        query=self.query,
        selected_filters=self.selected_filters,
    })

    local choices = {}
    for _, result in ipairs(self.results) do
        table.insert(choices, {
            text=format_result_choice(result),
            result=result,
            search_key=result.name,
        })
    end

    local result_header = ('Results (%d)'):format(#choices)
    self.subviews.result_header:setText(result_header)
    self.subviews.result_header_underline:setText(get_title_underline(result_header))
    self.subviews.result_list:setChoices(choices, 1)
    local _, choice = self.subviews.result_list:getSelected()
    self:update_attributes(choice and choice.result or nil)
end

function DwarfSearchWindow:update_attributes(result)
    self.subviews.attributes:setText(attributes_for_result(result))
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

function DwarfSearchWindow:is_filter_active(filter_id)
    return self.selected_filter_modes[filter_id] ~= nil
end

function DwarfSearchWindow:add_filter(filter_id)
    if not self:is_filter_active(filter_id) then
        self.selected_filter_modes[filter_id] = FILTER_HIGH
        table.insert(self.selected_filter_order, filter_id)
    end
    self.add_filter_open = false
    self.add_skill_open = false
    self:update_add_filter_button()
    self:update_add_skill_button()
    self:update_filter_choices(self:get_filter_choice_index(filter_id))
    self:update_available_filter_choices()
    self:update_available_skill_choices()
    self:update_results()
end

function DwarfSearchWindow:remove_filter(filter_id)
    self.selected_filter_modes[filter_id] = nil
    local selected = self:get_filter_priority(filter_id) or 1
    for index, ordered_filter_id in ipairs(self.selected_filter_order) do
        if ordered_filter_id == filter_id then
            table.remove(self.selected_filter_order, index)
            break
        end
    end
    self:update_filter_choices(math.max(1, math.min(selected, #self.selected_filter_order)))
    self:update_available_filter_choices()
    self:update_available_skill_choices()
    self:update_results()
end

function DwarfSearchWindow:clear_filters()
    if #self.selected_filter_order == 0 then
        return false
    end

    self.selected_filter_modes = {}
    self.selected_filter_order = {}
    self.add_filter_open = false
    self.add_skill_open = false
    self:update_add_filter_button()
    self:update_add_skill_button()
    self:update_filter_choices(1)
    self:update_available_filter_choices()
    self:update_available_skill_choices()
    self:update_results()
    return true
end

function DwarfSearchWindow:set_filter_direction(filter_id, direction)
    if not self:is_filter_active(filter_id) then
        self:add_filter(filter_id)
        self.selected_filter_modes[filter_id] = direction
    else
        self.selected_filter_modes[filter_id] = direction
    end
    local selected = self:get_filter_choice_index(filter_id)
    self:update_filter_choices(selected)
    self:update_available_filter_choices()
    self:update_available_skill_choices()
    self:update_results()
end

function DwarfSearchWindow:toggle_add_filter_dropdown()
    self.add_filter_open = not self.add_filter_open
    if self.add_filter_open then
        self.add_skill_open = false
    end
    self:update_add_filter_button()
    self:update_add_skill_button()
    self:update_available_filter_choices()
    self:update_available_skill_choices()
end

function DwarfSearchWindow:toggle_add_skill_dropdown()
    self.add_skill_open = not self.add_skill_open
    if self.add_skill_open then
        self.add_filter_open = false
    end
    self:update_add_filter_button()
    self:update_add_skill_button()
    self:update_available_filter_choices()
    self:update_available_skill_choices()
end

function DwarfSearchWindow:close_add_filter_dropdown()
    if not self.add_filter_open and not self.add_skill_open then
        return false
    end

    self.add_filter_open = false
    self.add_skill_open = false
    self:update_add_filter_button()
    self:update_add_skill_button()
    self:update_available_filter_choices()
    self:update_available_skill_choices()
    return true
end

function DwarfSearchWindow:update_add_filter_button()
    local label = self.add_filter_open and CLOSE_FILTER_MENU_LABEL or ADD_FILTER_LABEL
    self.subviews.add_filter_button:setLabel(label)
end

function DwarfSearchWindow:update_add_skill_button()
    local label = self.add_skill_open and CLOSE_SKILL_MENU_LABEL or ADD_SKILL_LABEL
    self.subviews.add_skill_button:setLabel(label)
end

function DwarfSearchWindow:move_selected_filter_priority(delta)
    local _, choice = self.subviews.filter_list:getSelected()
    local filter_id = choice and choice.descriptor and choice.descriptor.id
    if not filter_id or not self.selected_filter_modes[filter_id] then
        return false
    end

    local index = self:get_filter_priority(filter_id)
    local new_index = index and math.max(1, math.min(#self.selected_filter_order, index + delta))
    if not new_index or new_index == index then
        return false
    end

    table.remove(self.selected_filter_order, index)
    table.insert(self.selected_filter_order, new_index, filter_id)
    self:update_filter_choices(new_index)
    self:update_results()
    return true
end

function DwarfSearchWindow:handle_filter_action_click()
    if self.add_filter_open or self.add_skill_open then
        return false
    end

    local filter_list = self.subviews.filter_list
    local index = filter_list:getIdxUnderMouse()
    if not index then
        return false
    end

    filter_list:setSelected(index)
    local x = filter_list:getMousePos()
    local _, choice = filter_list:getSelected()
    local filter_id = choice and choice.descriptor and choice.descriptor.id
    local action = get_filter_action_at_x(x)
    if not filter_id or not action then
        return false
    end

    if action == FILTER_ACTION_PLUS then
        self:set_filter_direction(filter_id, FILTER_HIGH)
    elseif action == FILTER_ACTION_MINUS then
        self:set_filter_direction(filter_id, FILTER_LOW)
    elseif action == FILTER_ACTION_REMOVE then
        self:remove_filter(filter_id)
    elseif action == FILTER_ACTION_UP then
        self:move_selected_filter_priority(-1)
    elseif action == FILTER_ACTION_DOWN then
        self:move_selected_filter_priority(1)
    end
    return true
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

function DwarfSearchWindow:move_result_cursor(delta)
    self.subviews.result_list:moveCursor(delta)
end

function DwarfSearchWindow:onInput(keys)
    if is_backspace_key(keys) and self:close_add_filter_dropdown() then
        return true
    end
    if keys._MOUSE_L and self:handle_filter_action_click() then
        return true
    end
    if keys.CUSTOM_R then
        self:refresh_residents()
        return true
    end
    if keys.CUSTOM_Z then
        self:zoom_to_selected_result()
        return true
    end
    if keys.CUSTOM_U and self:move_selected_filter_priority(-1) then
        return true
    end
    if keys.CUSTOM_D and self:move_selected_filter_priority(1) then
        return true
    end
    if keys.KEYBOARD_CURSOR_UP then
        self:move_result_cursor(-1)
        return true
    end
    if keys.KEYBOARD_CURSOR_DOWN then
        self:move_result_cursor(1)
        return true
    end
    if keys.KEYBOARD_CURSOR_UP_FAST then
        self:move_result_cursor(-10)
        return true
    end
    if keys.KEYBOARD_CURSOR_DOWN_FAST then
        self:move_result_cursor(10)
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
