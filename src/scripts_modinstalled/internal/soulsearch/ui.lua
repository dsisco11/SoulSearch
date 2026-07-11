--@ module=true

local gui = require('gui')
local widgets = require('gui.widgets')

local residents = reqscript('internal/soulsearch/residents')
local search = reqscript('internal/soulsearch/search')
local descriptors = reqscript('internal/soulsearch/descriptors')
local filter_state = reqscript('internal/soulsearch/filter_state')
local skill_categories = reqscript('internal/soulsearch/skill_categories')
local text_match = reqscript('internal/soulsearch/text_match')
local ui_components = reqscript('internal/soulsearch/ui_components')
local ui_format = reqscript('internal/soulsearch/ui_format')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local ui_refresh = reqscript('internal/soulsearch/ui_refresh')
local glyphs = reqscript('internal/soulsearch/ui_glyphs')

local view
local saved_stats_sort_key
local saved_stats_sort_reverse = false
local saved_stats_sort_phase = 0
local SECTION_DIVIDER_PEN = COLOR_DARKGREY
local FILTER_HIGH = 'high'
local FILTER_LOW = 'low'
local STATS_SORT_LABEL = 'label'
local STATS_SORT_VALUE = 'value'
local TOOLTIP_BACKGROUND_PEN = dfhack.pen.parse{ch=32, fg=COLOR_BLACK, bg=COLOR_BLACK}
local TOOLTIP_TEXT_PEN = dfhack.pen.parse{fg=COLOR_WHITE, bg=COLOR_BLACK}

---@class SoulSearchPosition
---@field x integer
---@field y integer
---@field z integer

---@param x integer|table
---@param y integer|nil
---@param z integer|nil
---@return SoulSearchPosition|nil
local function normalize_position(x, y, z)
    if type(x) == 'table' then
        return {x=x.x, y=x.y, z=x.z}
    end
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' or
            x < 0 or y < 0 or z < 0 then
        return nil
    end
    return {x=x, y=y, z=z}
end

---@param keys table
---@return boolean
local function is_backspace_key(keys)
    return keys._BACKSPACE or keys.BACKSPACE or keys.KEYBOARD_BACKSPACE
end

---@param view table|nil
---@return boolean
local function is_visible(view)
    while view do
        if type(view.visible) == 'function' then
            if not view.visible() then
                return false
            end
        elseif not view.visible then
            return false
        end
        view = view.parent_view
    end
    return true
end

---@param view table|nil
---@return boolean
local function is_mouse_over(view)
    local rect = view and view.frame_body
    local x, y = dfhack.screen.getMousePos()
    return rect and x and is_visible(view) and rect:inClipGlobalXY(x, y)
end

---@param text string
---@param max_width integer
---@return string tooltip_text
---@return integer tooltip_width
local function get_tooltip_box(text, max_width)
    local text_width = math.min(#text, math.min(52, max_width - 2))
    local tooltip_text = ui_format.truncate_text(text, text_width)
    return tooltip_text, #tooltip_text + 2
end

---@class SoulSearchTooltip: widgets.Window
---@field label widgets.Label
---@field owner SoulSearchWindow|nil
SoulSearchTooltip = defclass(SoulSearchTooltip, widgets.Window)
SoulSearchTooltip.ATTRS{
    frame={l=0, t=0, w=1, h=3},
    frame_style=gui.FRAME_THIN,
    frame_background=TOOLTIP_BACKGROUND_PEN,
    frame_inset=0,
    draggable=false,
    no_force_pause_badge=true,
    owner=DEFAULT_NIL,
}

---Creates tooltip label content.
function SoulSearchTooltip:init()
    self.label = widgets.Label{
        frame={l=0, t=0, w=1, h=1},
        auto_height=false,
        text_pen=TOOLTIP_TEXT_PEN,
        text='',
    }
    self:addviews{self.label}
end

---Positions and draws the tooltip near the mouse cursor.
---@param dc gui.Painter
function SoulSearchTooltip:render(dc)
    local owner = self.owner
    local mouse_x, mouse_y = dfhack.screen.getMousePos()
    if not owner or not mouse_x then
        return
    end

    local text = owner:get_tooltip_text()
    if text == '' then
        return
    end

    local screen_width, screen_height = dfhack.screen.getWindowSize()
    local tooltip_text, tooltip_width = get_tooltip_box(text, screen_width)
    local x = math.min(mouse_x + 2, screen_width - tooltip_width)
    local y = math.min(mouse_y + 1, screen_height - 3)

    self.frame = {
        l=math.max(0, x),
        t=math.max(0, y),
        w=tooltip_width,
        h=3,
    }
    self.label.frame.w = math.max(1, tooltip_width - 2)
    self.label:setText(tooltip_text)
    self:updateLayout()
    SoulSearchTooltip.super.render(self, dc)
end

---@param target SoulSearchFilterDescriptor[]
---@param descriptors SoulSearchFilterDescriptor[]|nil
local function append_descriptors(target, descriptors)
    for _, descriptor in ipairs(descriptors or {}) do
        table.insert(target, descriptor)
    end
end

---@param target table[]
---@param views table[]
local function append_views(target, views)
    for _, child in ipairs(views) do
        table.insert(target, child)
    end
end

---@param result SoulSearchResult|nil
---@return SoulSearchPosition|nil
local function get_live_position(result)
    if not result or not result.unit then
        return nil
    end

    return normalize_position(dfhack.units.getPosition(result.unit))
end

---@param window widgets.Window
local function normalize_frame_for_drag(window)
    window.frame = {
        l=window.frame_rect.x1,
        t=window.frame_rect.y1,
        w=window.frame_rect.width,
        h=window.frame_rect.height,
    }
end

---@param dc gui.Painter
local function draw_section_dividers(dc)
    local y2 = math.max(2, dc.height)
    for _, x in ipairs(ui_layout.DIVIDER_XS) do
        for y = 2, y2 do
            dc:seek(x, y):char(glyphs.CP437_VERTICAL_LINE, SECTION_DIVIDER_PEN)
        end
    end
end

---@class SoulSearchWindow: widgets.Window
---@field rows SoulSearchResidentRow[]
---@field results SoulSearchResult[]
---@field query string
---@field attribute_query string
---@field skill_query string
---@field stats_sort_key string|nil
---@field stats_sort_reverse boolean
---@field stats_sort_phase integer
---@field suppress_result_select_refresh boolean
---@field add_filter_open boolean
---@field add_skill_open boolean
---@field filter_catalog SoulSearchFilterCatalog
---@field attribute_filter_descriptors SoulSearchFilterDescriptor[]
---@field skill_filter_descriptors SoulSearchFilterDescriptor[]
---@field filter_state SoulSearchFilterState
SoulSearchWindow = defclass(SoulSearchWindow, widgets.Window)
SoulSearchWindow.ATTRS {
    frame_title='SoulSearch',
    frame=ui_layout.copy_dimensions(ui_layout.WINDOW_FRAME),
    resizable=true,
    resize_min=ui_layout.copy_dimensions(ui_layout.WINDOW_RESIZE_MIN),
}

---Creates controls and loads the initial resident/filter data.
function SoulSearchWindow:init()
    self.rows = {}
    self.results = {}
    self.query = ''
    self.attribute_query = ''
    self.skill_query = ''
    self.stats_sort_key = saved_stats_sort_key
    self.stats_sort_reverse = saved_stats_sort_reverse
    self.stats_sort_phase = saved_stats_sort_phase
    self.suppress_result_select_refresh = false
    self.add_filter_open = false
    self.add_skill_open = false
    local filter_catalog = descriptors.get_catalog()
    local filter_descriptor_groups = filter_catalog.groups
    self.filter_catalog = filter_catalog
    self.attribute_filter_descriptors = {}
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.physical_attributes)
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.mental_attributes)
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.traits)
    self.skill_filter_descriptors = filter_descriptor_groups.skills or {}
    self.filter_state = filter_state.load()

    local views = {}
    -- Preserve the original child order: the modal results query remains first
    -- so keyboard focus traversal is unchanged by component extraction.
    table.insert(views, ui_components.create_results_query(function(text)
        self.query = text
        self:refresh_views{results=true}
    end))
    append_views(views, ui_components.create_filter_panel{
        is_attribute_picker_open=function() return self.add_filter_open end,
        is_skill_picker_open=function() return self.add_skill_open end,
        on_toggle_attribute_picker=function() self:toggle_add_filter_dropdown() end,
        on_toggle_skill_picker=function() self:toggle_add_skill_dropdown() end,
        on_clear=function() self:clear_filters() end,
        on_close_picker=function() self:close_add_filter_dropdown() end,
        on_attribute_query=function(text)
            self.attribute_query = text
            self:refresh_views{pickers=true}
        end,
        on_skill_query=function(text)
            self.skill_query = text
            self:refresh_views{pickers=true}
        end,
        on_add=function(filter_id) self:add_filter(filter_id) end,
    })
    append_views(views, ui_components.create_results_panel{
        on_select=function(result)
            if not self.suppress_result_select_refresh then
                self:refresh_views{stats=true, result=result}
            end
        end,
        on_submit=function(result) self:zoom_to_result(result) end,
    })
    append_views(views, ui_components.create_stats_panel())
    table.insert(views, ui_components.create_close_button(function()
        self.parent_view:dismiss()
    end))
    self:addviews(views)

    self:refresh_residents()
    self:refresh_views{
        active_filters=true,
        pickers=true,
    }
end

---Normalizes the frame after a drag begins so resizing remains stable.
function SoulSearchWindow:onDragBegin()
    SoulSearchWindow.super.onDragBegin(self)
    normalize_frame_for_drag(self)
end

---Draws the main window body and section dividers.
---@param dc gui.Painter
function SoulSearchWindow:onRenderBody(dc)
    SoulSearchWindow.super.onRenderBody(self, dc)
    draw_section_dividers(dc)
end

---@return string|nil
function SoulSearchWindow:get_filter_action_tooltip()
    if self.add_filter_open or self.add_skill_open then
        return nil
    end

    local filter_list = self.subviews.filter_list
    if not filter_list or not filter_list:getIdxUnderMouse() then
        return nil
    end

    local x = filter_list:getMousePos()
    local action = ui_layout.get_filter_action_at_x(x)
    return action and action.tooltip or nil
end

---@return string|nil
function SoulSearchWindow:get_stats_header_column()
    local stats = self.subviews.stats
    if not stats then
        return nil
    end

    local x, y = stats:getMousePos()
    return ui_layout.get_stats_header_column(x, y)
end

---@return string|nil
function SoulSearchWindow:get_stats_header_tooltip()
    local column = self:get_stats_header_column()
    return column and ui_components.STATS_HEADER_TOOLTIPS[column] or nil
end

---@return string
function SoulSearchWindow:get_tooltip_text()
    for _, tooltip in ipairs(ui_components.CONTROL_TOOLTIPS) do
        if is_mouse_over(self.subviews[tooltip.id]) then
            return tooltip.text
        end
    end

    return self:get_filter_action_tooltip() or self:get_stats_header_tooltip() or ''
end

---@return SoulSearchFilterDescriptor[]
function SoulSearchWindow:get_active_filter_descriptors()
    local active_descriptors = {}

    for _, filter in ipairs(filter_state.get_filters(self.filter_state)) do
        local descriptor = self.filter_catalog.by_id[filter.id]
        if descriptor then
            table.insert(active_descriptors, descriptor)
        end
    end

    return active_descriptors
end

---@param filter_id string
---@return integer
function SoulSearchWindow:get_filter_choice_index(filter_id)
    return filter_state.get_priority(self.filter_state, filter_id) or 1
end

---@param selected integer|nil
function SoulSearchWindow:refresh_active_filter_choices(selected)
    local choices = {}
    local priority_count = filter_state.count(self.filter_state)
    for _, descriptor in ipairs(self:get_active_filter_descriptors()) do
        table.insert(choices, {
            text=ui_format.format_active_filter_choice(
                descriptor,
                filter_state.get_direction(self.filter_state, descriptor.id),
                filter_state.get_priority(self.filter_state, descriptor.id),
                priority_count),
            descriptor=descriptor,
            search_key=descriptor.label,
        })
    end
    if #choices == 0 then
        table.insert(choices, {text='Use Add attribute or Add skill.'})
    end
    self.subviews.filter_list:setChoices(choices, selected)
end

---Refreshes the two picker lists from filter state and picker queries.
function SoulSearchWindow:refresh_picker_choices()
    self:update_available_filter_choices()
    self:update_available_skill_choices()
end

---Dispatches one explicit pass over the requested derived views.
---@param request SoulSearchRefreshRequest
function SoulSearchWindow:refresh_views(request)
    ui_refresh.apply(self, request)
end

---Persists filter state and refreshes every view derived from it once.
---@param selected integer|nil
function SoulSearchWindow:on_filter_state_changed(selected)
    filter_state.save(self.filter_state)
    self:refresh_views{
        active_filters=true,
        pickers=true,
        results=true,
        selected_filter=selected,
    }
end

---@param selected integer|nil
function SoulSearchWindow:update_available_filter_choices(selected)
    local choices = {}
    for _, descriptor in ipairs(self.attribute_filter_descriptors) do
        if not filter_state.contains(self.filter_state, descriptor.id) and
                text_match.contains(descriptor.label, self.attribute_query) then
            table.insert(choices, {
                text=ui_format.format_available_filter_choice(descriptor),
                descriptor=descriptor,
                search_key=descriptor.label,
            })
        end
    end
    if #choices == 0 then
        table.insert(choices, {text='No matching attributes.'})
    end
    self.subviews.available_filter_list:setChoices(choices, selected)
end

---@param selected integer|nil
function SoulSearchWindow:update_available_skill_choices(selected)
    local choices = {}
    local choices_by_category = {}
    for _, descriptor in ipairs(self.skill_filter_descriptors) do
        if not filter_state.contains(self.filter_state, descriptor.id) and
                text_match.contains(descriptor.label, self.skill_query) then
            local category = descriptor.category or 'Other Skills'
            choices_by_category[category] = choices_by_category[category] or {}
            table.insert(choices_by_category[category], {
                text=ui_format.format_available_skill_choice(descriptor),
                descriptor=descriptor,
                search_key=descriptor.label,
            })
        end
    end
    for _, category in ipairs(skill_categories.get_order()) do
        local category_choices = choices_by_category[category]
        if category_choices and #category_choices > 0 then
            table.insert(choices, {
                text=ui_format.format_skill_category_choice(category),
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

---Recomputes results and preserves selection by unit ID when possible. If the
---previous resident disappears, the same list position is retained and clamped
---to the final row; an empty result set has no selection.
---@return SoulSearchResult|nil
function SoulSearchWindow:recompute_results()
    local previous_index, previous_choice = self.subviews.result_list:getSelected()
    local previous_result = previous_choice and previous_choice.result
    local previous_unit_id = previous_result and previous_result.unit_id

    self.results = search.apply(self.rows, {
        query=self.query,
        selected_filters=filter_state.get_filters(self.filter_state),
    })

    local choices = {}
    for _, result in ipairs(self.results) do
        table.insert(choices, {
            text=ui_format.format_result_choice(result),
            result=result,
            search_key=result.name,
        })
    end

    local result_header = ('Results (%d)'):format(#choices)
    self.subviews.result_header:setText(result_header)
    self.subviews.result_header_underline:setText(
        ui_format.get_title_underline(result_header))

    local selected = ui_refresh.get_result_selection(
        self.results,
        previous_unit_id,
        previous_index)
    -- DFHack List:setChoices() force-fires on_select. Suppress that nested view
    -- refresh so the dispatcher remains the single owner of the Stats update.
    self.suppress_result_select_refresh = true
    ui_components.set_result_choices(
        self.subviews.result_list,
        choices,
        selected)
    self.suppress_result_select_refresh = false
    local _, choice = self.subviews.result_list:getSelected()
    return choice and choice.result or nil
end

---@param result SoulSearchResult|nil
function SoulSearchWindow:refresh_stats(result)
    ui_components.update_stats_panel(
        self.subviews.stats_header,
        self.subviews.stats,
        result,
        self.stats_sort_key,
        self.stats_sort_reverse,
        self.frame_body)
end

---@return boolean
function SoulSearchWindow:handle_stats_header_click()
    local column = self:get_stats_header_column()
    if not column then
        return false
    end

    if self.stats_sort_key == column then
        self.stats_sort_phase = self.stats_sort_phase + 1
    else
        self.stats_sort_key = column
        self.stats_sort_phase = 1
    end

    if self.stats_sort_phase >= 3 then
        self.stats_sort_key = nil
        self.stats_sort_reverse = false
        self.stats_sort_phase = 0
    elseif self.stats_sort_phase == 1 then
        self.stats_sort_reverse = column == STATS_SORT_VALUE
    else
        self.stats_sort_reverse = column ~= STATS_SORT_VALUE
    end

    -- Retain the presentation mode while this UI module remains loaded, which
    -- matches the session lifetime used by the filter-state persistence model.
    saved_stats_sort_key = self.stats_sort_key
    saved_stats_sort_reverse = self.stats_sort_reverse
    saved_stats_sort_phase = self.stats_sort_phase
    self:refresh_views{stats=true}
    return true
end

---@return SoulSearchResult|nil
function SoulSearchWindow:get_selected_result()
    local _, choice = self.subviews.result_list:getSelected()
    return choice and choice.result or nil
end

---Centers the map on the currently selected result when possible.
function SoulSearchWindow:zoom_to_selected_result()
    self:zoom_to_result(self:get_selected_result())
end

---@param result SoulSearchResult|nil
function SoulSearchWindow:zoom_to_result(result)
    if not result then
        print('SoulSearch: no resident selected.')
        return
    end

    local pos = get_live_position(result)
    if not pos then
        print(('SoulSearch: %s does not have a valid map position.'):format(result.name))
        return
    end

    dfhack.gui.revealInDwarfmodeMap(pos, true, true)
end

---@param filter_id string
---@return boolean
function SoulSearchWindow:add_filter(filter_id)
    if not filter_state.add(self.filter_state, filter_id, FILTER_HIGH) then
        return false
    end
    self.add_filter_open = false
    self.add_skill_open = false
    self:on_filter_state_changed(self:get_filter_choice_index(filter_id))
    return true
end

---@param filter_id string
---@return boolean
function SoulSearchWindow:remove_filter(filter_id)
    local selected = filter_state.get_priority(self.filter_state, filter_id) or 1
    if not filter_state.remove(self.filter_state, filter_id) then
        return false
    end
    self:on_filter_state_changed(math.max(
        1,
        math.min(selected, filter_state.count(self.filter_state))))
    return true
end

---@return boolean
function SoulSearchWindow:clear_filters()
    if not filter_state.clear(self.filter_state) then
        return false
    end

    self.add_filter_open = false
    self.add_skill_open = false
    self:on_filter_state_changed(1)
    return true
end

---@param filter_id string
---@param direction SoulSearchFilterDirection
---@return boolean
function SoulSearchWindow:set_filter_direction(filter_id, direction)
    local was_active = filter_state.contains(self.filter_state, filter_id)
    if not filter_state.set_direction(self.filter_state, filter_id, direction) then
        return false
    end
    if not was_active then
        self.add_filter_open = false
        self.add_skill_open = false
    end
    local selected = self:get_filter_choice_index(filter_id)
    self:on_filter_state_changed(selected)
    return true
end

---Opens or closes the attribute/trait filter picker.
function SoulSearchWindow:toggle_add_filter_dropdown()
    self.add_filter_open = not self.add_filter_open
    if self.add_filter_open then
        self.add_skill_open = false
    end
    self:refresh_views{pickers=true}
end

---Opens or closes the skill filter picker.
function SoulSearchWindow:toggle_add_skill_dropdown()
    self.add_skill_open = not self.add_skill_open
    if self.add_skill_open then
        self.add_filter_open = false
    end
    self:refresh_views{pickers=true}
end

---@return boolean
function SoulSearchWindow:close_add_filter_dropdown()
    if not self.add_filter_open and not self.add_skill_open then
        return false
    end

    self.add_filter_open = false
    self.add_skill_open = false
    self:refresh_views{pickers=true}
    return true
end

---@param delta integer
---@return boolean
function SoulSearchWindow:move_selected_filter_priority(delta)
    local _, choice = self.subviews.filter_list:getSelected()
    local filter_id = choice and choice.descriptor and choice.descriptor.id
    if not filter_id then
        return false
    end

    local changed, new_index = filter_state.move(self.filter_state, filter_id, delta)
    if not changed then
        return false
    end

    self:on_filter_state_changed(new_index)
    return true
end

---@return boolean
function SoulSearchWindow:handle_filter_action_click()
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
    local action = ui_layout.get_filter_action_at_x(x)
    if not filter_id or not action then
        return false
    end

    if action.callback == 'set_high' then
        self:set_filter_direction(filter_id, FILTER_HIGH)
    elseif action.callback == 'set_low' then
        self:set_filter_direction(filter_id, FILTER_LOW)
    elseif action.callback == 'remove' then
        self:remove_filter(filter_id)
    elseif action.callback == 'move_up' then
        self:move_selected_filter_priority(-1)
    elseif action.callback == 'move_down' then
        self:move_selected_filter_priority(1)
    end
    return true
end

---Reloads resident rows from the current fortress map.
function SoulSearchWindow:refresh_residents()
    local rows, err = residents.collect_residents()
    if not rows then
        print(err)
        self.rows = {}
    else
        self.rows = rows
    end
    self:refresh_views{results=true}
end

---@param delta integer
function SoulSearchWindow:move_result_cursor(delta)
    ui_components.move_result_cursor(self.subviews.result_list, delta)
end

---@param keys table
---@return boolean
function SoulSearchWindow:onInput(keys)
    if is_backspace_key(keys) and self:close_add_filter_dropdown() then
        return true
    end
    if keys._MOUSE_L and self:handle_filter_action_click() then
        return true
    end
    if keys._MOUSE_L and self:handle_stats_header_click() then
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
    return SoulSearchWindow.super.onInput(self, keys)
end

---@class SoulSearchScreen: gui.ZScreen
---@field window SoulSearchWindow
SoulSearchScreen = defclass(SoulSearchScreen, gui.ZScreen)
SoulSearchScreen.ATTRS {
    focus_path='soulsearch',
}

---Creates the main SoulSearch window and tooltip overlay.
function SoulSearchScreen:init()
    self.window = SoulSearchWindow{}
    self:addviews{
        self.window,
        SoulSearchTooltip{owner=self.window},
    }
end

---Clears the cached screen reference when the screen closes.
function SoulSearchScreen:onDismiss()
    view = nil
end

---Opens or raises the SoulSearch screen.
---@param ... any
function open(...)
    local err = residents.get_unavailable_reason()
    if err then
        print(err)
        return
    end

    view = view and view:raise() or SoulSearchScreen{}:show()
end
