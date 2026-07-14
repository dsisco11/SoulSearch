--@ module=true

local gui = require('gui')
local dialogs = require('gui.dialogs')
local widgets = require('gui.widgets')

local residents = reqscript('internal/soulsearch/residents')
local unit_scope_provider = reqscript('internal/soulsearch/unit_scope_provider')
local race_filter_provider = reqscript('internal/soulsearch/race_filter_provider')
local search = reqscript('internal/soulsearch/search')
local descriptors = reqscript('internal/soulsearch/descriptors')
local filter_state = reqscript('internal/soulsearch/filter_state')
local window_settings = reqscript('internal/soulsearch/window_settings')
local window_config = reqscript('internal/soulsearch/window_config')
local screen_registry = reqscript('internal/soulsearch/screen_registry')
local filter_defaults = reqscript('internal/soulsearch/filter_defaults')
local role_presets = reqscript('internal/soulsearch/role_presets')
local filter_presets = reqscript('internal/soulsearch/filter_presets')
local skill_categories = reqscript('internal/soulsearch/skill_categories')
local text_match = reqscript('internal/soulsearch/text_match')
local ui_components = reqscript('internal/soulsearch/ui_components')
local ui_format = reqscript('internal/soulsearch/ui_format')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local ui_refresh = reqscript('internal/soulsearch/ui_refresh')
local SoulSearchTooltip = reqscript('internal/soulsearch/ui_tooltip')
local glyphs = reqscript('internal/soulsearch/ui_glyphs')
local attribute_descriptions = reqscript('internal/soulsearch/attribute_descriptions')
local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

local SECTION_DIVIDER_PEN = COLOR_DARKGREY
local FILTER_HIGH = filter_constants.direction.HIGH
local FILTER_LOW = filter_constants.direction.LOW
local FILTER_KIND_RACE = filter_constants.kind.RACE
local RACE_GROUP_ID_PREFIX = filter_constants.race.group_id_prefix
local STATS_SORT_LABEL = 'label'
local STATS_SORT_VALUE = 'value'

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

---Makes nested modal descendants addressable from the root window, matching
---the direct-subview access used by the refresh and tooltip paths.
---@param parent table
---@param root_subviews table
local function expose_descendant_subviews(parent, root_subviews)
    for _, child in ipairs(parent.subviews or {}) do
        if child.view_id then
            root_subviews[child.view_id] = child
        end
        expose_descendant_subviews(child, root_subviews)
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
---@field result_sort_key 'name'|'unit_id'|'profession'|nil
---@field result_sort_reverse boolean
---@field result_sort_phase integer
---@field suppress_result_select_refresh boolean
---@field filter_panel_open boolean
---@field add_filter_open boolean
---@field add_skill_open boolean
---@field add_race_open boolean
---@field unit_scope_picker_open boolean
---@field preset_picker_open boolean
---@field filter_catalog SoulSearchFilterCatalog
---@field attribute_filter_descriptors SoulSearchFilterDescriptor[]
---@field skill_filter_descriptors SoulSearchFilterDescriptor[]
---@field race_filter_descriptors SoulSearchFilterDescriptor[]
---@field filter_state SoulSearchFilterState
SoulSearchWindow = defclass(SoulSearchWindow, widgets.Window)
SoulSearchWindow.ATTRS {
    frame_title='SoulSearch',
    frame=ui_layout.copy_dimensions(ui_layout.WINDOW_FRAME),
    resizable=true,
    resize_min=ui_layout.copy_dimensions(ui_layout.WINDOW_RESIZE_MIN),
    settings_id=DEFAULT_NIL,
    settings=DEFAULT_NIL,
}

---Creates controls and loads the initial resident/filter data.
function SoulSearchWindow:init()
    local settings = self.settings
    if not settings then
        local screen_width, screen_height = dfhack.screen.getWindowSize()
        settings = window_config.resolve(nil, screen_width, screen_height)
    end
    self.settings_id = settings.settings_id
    self.frame = ui_layout.copy_dimensions(settings.frame)
    self.initial_frame = ui_layout.copy_dimensions(settings.frame)
    self.frame_explicit = settings.explicit and settings.explicit.frame ~= nil
    self.frame_dirty = false
    self.rows = {}
    self.results = {}
    self.query = ''
    self.attribute_query = ''
    self.skill_query = ''
    self.race_query = ''
    self.stats_sort_key = settings.stats_sort.key
    self.stats_sort_reverse = settings.stats_sort.reverse
    self.stats_sort_phase = settings.stats_sort.phase
    self.result_sort_key = settings.result_sort.key
    self.result_sort_reverse = settings.result_sort.reverse
    self.result_sort_phase = settings.result_sort.phase
    self.suppress_result_select_refresh = false
    self.filter_panel_open = false
    self.add_filter_open = false
    self.add_skill_open = false
    self.add_race_open = false
    self.unit_scope_picker_open = false
    self.preset_picker_open = false
    self.preset_query = ''
    self.unit_scope = settings.unit_scope
    local filter_catalog = descriptors.get_catalog()
    local filter_descriptor_groups = filter_catalog.groups
    self.filter_catalog = filter_catalog
    self.attribute_filter_descriptors = {}
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.physical_attributes)
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.mental_attributes)
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.traits)
    self.skill_filter_descriptors = filter_descriptor_groups.skills or {}
    self.race_filter_descriptors = filter_descriptor_groups.races or {}
    self.filter_state = filter_state.new(settings.filters)

    local views = {}
    -- Preserve the original child order: the modal results query remains first
    -- so keyboard focus traversal is unchanged by component extraction.
    table.insert(views, ui_components.create_results_query(function(text)
        self.query = text
        self:refresh_views{results=true}
    end))
    table.insert(views, ui_components.create_filter_panel_button(function()
        self:toggle_filter_panel()
    end))
    table.insert(views, ui_components.create_active_filter_count())
    append_views(views, ui_components.create_results_panel{
        on_select=function(result)
            if not self.suppress_result_select_refresh then
                self:refresh_views{stats=true, result=result}
            end
        end,
        on_submit=function(result) self:zoom_to_result(result) end,
        on_sort=function(column) self:cycle_result_sort(column) end,
    })
    append_views(views, ui_components.create_stats_panel(function(column)
        self:cycle_stats_sort(column)
    end))
    table.insert(views, ui_components.create_close_button(function()
        self.parent_view:dismiss()
    end))
    table.insert(views, ui_components.create_filter_panel{
        is_filter_panel_open=function() return self.filter_panel_open end,
        on_open_filter_panel=function() self:open_filter_panel() end,
        on_close_filter_panel_state=function()
            self:close_filter_panel_state()
        end,
        on_close_filter_panel=function() self:close_filter_panel() end,
        is_attribute_picker_open=function() return self.add_filter_open end,
        is_skill_picker_open=function() return self.add_skill_open end,
        is_race_picker_open=function() return self.add_race_open end,
        is_unit_scope_picker_open=function()
            return self.unit_scope_picker_open
        end,
        unit_scope=self.unit_scope,
        unit_scope_options=unit_scope_provider.get_options(),
        on_unit_scope_change=function(scope) self:select_unit_scope(scope) end,
        on_toggle_unit_scope_picker=function()
            self:toggle_unit_scope_picker()
        end,
        is_preset_picker_open=function() return self.preset_picker_open end,
        on_toggle_attribute_picker=function() self:toggle_add_filter_dropdown() end,
        on_toggle_skill_picker=function() self:toggle_add_skill_dropdown() end,
        on_toggle_race_picker=function() self:toggle_add_race_dropdown() end,
        on_clear=function() self:clear_filters() end,
        on_toggle_preset_picker=function() self:toggle_preset_picker() end,
        on_close_preset_picker=function() self:close_preset_picker() end,
        on_preset_query=function(text)
            self.preset_query = text
            self:refresh_views{presets=true}
        end,
        on_save_preset=function() self:save_filter_preset() end,
        on_load_preset=function(name) self:load_filter_preset(name) end,
        on_load_default_preset=function(id) self:load_default_filter_preset(id) end,
        on_load_role_preset=function(id) self:load_role_filter_preset(id) end,
        on_close_picker=function() self:close_add_filter_dropdown() end,
        on_attribute_query=function(text)
            self.attribute_query = text
            self:refresh_views{pickers=true}
        end,
        on_skill_query=function(text)
            self.skill_query = text
            self:refresh_views{pickers=true}
        end,
        on_race_query=function(text)
            self.race_query = text
            self:refresh_views{pickers=true}
        end,
        on_add=function(filter_id) self:add_filter(filter_id) end,
        on_filter_action=function(filter_id, action)
            self:handle_filter_action(filter_id, action)
        end,
    })
    self:addviews(views)
    expose_descendant_subviews(self, self.subviews)

    self:update_unit_scope_picker()
    self:refresh_residents()
    self:refresh_views{
        active_filters=true,
        pickers=true,
        presets=true,
    }
end

---Normalizes the frame after a drag begins so resizing remains stable.
function SoulSearchWindow:onDragBegin()
    SoulSearchWindow.super.onDragBegin(self)
    normalize_frame_for_drag(self)
    self.frame_dirty = true
end

---@return boolean
function SoulSearchWindow:should_persist_frame()
    if self.frame_explicit or self.frame_dirty then return true end
    local current = self.frame
    local initial = self.initial_frame
    return current.l ~= initial.l or current.t ~= initial.t or
        current.w ~= initial.w or current.h ~= initial.h
end

function SoulSearchWindow:persist_frame_if_needed()
    if not self:should_persist_frame() then return false end
    self:update_session_settings{
        frame=ui_layout.copy_dimensions(self.frame),
    }
    return true
end

---Draws the main window body and section dividers.
---@param dc gui.Painter
function SoulSearchWindow:onRenderBody(dc)
    SoulSearchWindow.super.onRenderBody(self, dc)
    draw_section_dividers(dc)
end

---@return string|nil
function SoulSearchWindow:get_filter_action_tooltip()
    if not self.filter_panel_open or self.add_filter_open or
            self.add_skill_open or self.add_race_open or
            self.preset_picker_open then
        return nil
    end

    local filter_list = self.subviews.filter_list
    if not filter_list then return nil end
    local index, _, action = filter_list:getActionUnderMouse()
    local choice = index and self.active_filter_choices and
        self.active_filter_choices[index]
    if not choice then return nil end
    local descriptor = choice and choice.descriptor
    if descriptor and descriptor.kind == FILTER_KIND_RACE and action then
        if action.callback == 'set_high' then
            return 'Include in results.'
        elseif action.callback == 'set_low' then
            return 'Exclude from results.'
        elseif action.callback == 'move_up' or action.callback == 'move_down' then
            return nil
        end
    end
    return action and action.tooltip or nil
end

---@return string|nil
function SoulSearchWindow:get_stats_header_column()
    local columns = self.subviews.stats_columns
    if not columns then
        return nil
    end

    local x, y = columns:getMousePos()
    return ui_layout.get_stats_header_column(x, y)
end

---@return string|nil
function SoulSearchWindow:get_stats_header_tooltip()
    local column = self:get_stats_header_column()
    return column and ui_components.STATS_HEADER_TOOLTIPS[column] or nil
end

---@return string|nil
function SoulSearchWindow:get_result_header_column()
    local columns = self.subviews.result_columns
    if not columns then return nil end
    local x, y = columns:getMousePos()
    return ui_layout.get_result_header_column(x, y)
end

---@return string|nil
function SoulSearchWindow:get_result_header_tooltip()
    local column = self:get_result_header_column()
    return column and ui_components.RESULT_HEADER_TOOLTIPS[column] or nil
end

---@param list widgets.List|nil
---@param choices table[]|nil
---@return string|nil
local function get_descriptor_tooltip(list, choices)
    local index = list and list:getIdxUnderMouse()
    local descriptor = index and choices and choices[index] and choices[index].descriptor
    if descriptor and descriptor.kind == FILTER_KIND_RACE then
        return 'Filters by a creatures race.'
    end
    return descriptor and attribute_descriptions.get_tooltip(
        descriptor.kind, descriptor.key) or nil
end

---@return string|nil
function SoulSearchWindow:get_filter_descriptor_tooltip()
    if not self.filter_panel_open or self.preset_picker_open then return nil end
    if self.add_filter_open then
        return get_descriptor_tooltip(
            self.subviews.available_filter_list,
            self.available_filter_choices)
    end
    if self.add_skill_open then
        return nil
    end
    if self.add_race_open then
        return get_descriptor_tooltip(
            self.subviews.available_race_list,
            self.available_race_choices)
    end
    local filter_list = self.subviews.filter_list
    local x = filter_list and filter_list:getMousePos()
    if ui_layout.get_filter_action_at_x(x) then return nil end
    return get_descriptor_tooltip(
        filter_list, self.active_filter_choices)
end

---@return string|nil
function SoulSearchWindow:get_stats_value_tooltip()
    local stats = self.subviews.stats
    if not stats then
        return nil
    end

    local x, y = stats:getMousePos()
    if ui_layout.is_stats_value_cell(x, y) then
        return ui_components.STATS_VALUE_TOOLTIP
    end
    return nil
end

---@return string|nil
function SoulSearchWindow:get_stats_attribute_tooltip()
    local stats = self.subviews.stats
    if not stats then return nil end
    local x, y = stats:getMousePos()
    -- Label mouse coordinates are relative to the visible viewport. Its
    -- records, however, retain every line, including section gaps, so apply
    -- the one-based first visible line when it has been scrolled.
    local record_index = (stats.start_line_num or 1) + y
    local record = self.stats_records and self.stats_records[record_index]
    if record and ui_layout.is_stats_label_cell(x, y) then
        return attribute_descriptions.get_tooltip(record.kind, record.key)
    end
    return nil
end

---@return string
function SoulSearchWindow:get_tooltip_text()
    for _, tooltip in ipairs(ui_components.CONTROL_TOOLTIPS) do
        if is_mouse_over(self.subviews[tooltip.id]) then
            return tooltip.text
        end
    end

    return self:get_filter_action_tooltip() or self:get_result_header_tooltip() or
        self:get_stats_header_tooltip() or
        self:get_stats_value_tooltip() or self:get_filter_descriptor_tooltip() or
        self:get_stats_attribute_tooltip() or ''
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
    local ranking_priorities = {}
    local ranking_filters = filter_state.get_ranking_filters(self.filter_state)
    for index, filter in ipairs(ranking_filters) do
        ranking_priorities[filter.id] = index
    end
    for _, descriptor in ipairs(self:get_active_filter_descriptors()) do
        table.insert(choices, {
            text=ui_format.format_active_filter_choice(
                descriptor,
                filter_state.get_direction(self.filter_state, descriptor.id),
                ranking_priorities[descriptor.id],
                #ranking_filters),
            descriptor=descriptor,
            search_key=descriptor.label,
        })
    end
    if #choices == 0 then
        table.insert(choices, {text='Use Add attribute, Add skill, or Add race.'})
    end
    self.subviews.filter_list:setChoices(choices, selected)
    self.active_filter_choices = choices
    self.subviews.active_filter_count:setText(
        'Filters: ' .. filter_state.count(self.filter_state))
end

---Refreshes the two picker lists from filter state and picker queries.
function SoulSearchWindow:refresh_picker_choices()
    self:update_available_filter_choices()
    self:update_available_skill_choices()
    self:update_available_race_choices()
end

---Refreshes the saved preset names displayed by the preset picker.
function SoulSearchWindow:refresh_preset_choices()
    local choices = {}
    local defaults = filter_defaults.get_all()
    local roles = role_presets.get_role_presets()
    local combat = role_presets.get_combat_presets()
    local saved = filter_presets.list()
    local has_saved = false
    for _, name in ipairs(saved) do
        if text_match.contains(name, self.preset_query) then
            has_saved = true
            break
        end
    end

    if has_saved then table.insert(choices, {text='Custom presets'}) end
    for _, name in ipairs(saved) do
        if text_match.contains(name, self.preset_query) then
            table.insert(choices, {text='  ' .. name, name=name, search_key=name})
        end
    end

    local has_roles = false
    for _, preset in ipairs(roles) do
        if text_match.contains(preset.label, self.preset_query) then
            has_roles = true
            break
        end
    end
    if has_roles then table.insert(choices, {text='Role presets'}) end
    for _, preset in ipairs(roles) do
        if text_match.contains(preset.label, self.preset_query) then
            table.insert(choices, {text='  ' .. preset.label, role_id=preset.id,
                search_key=preset.label})
        end
    end

    local has_combat = false
    for _, preset in ipairs(combat) do
        if text_match.contains(preset.label, self.preset_query) then
            has_combat = true
            break
        end
    end
    if has_combat then table.insert(choices, {text='Combat presets'}) end
    for _, preset in ipairs(combat) do
        if text_match.contains(preset.label, self.preset_query) then
            table.insert(choices, {text='  ' .. preset.label, role_id=preset.id,
                search_key=preset.label})
        end
    end

    local has_defaults = false
    for _, preset in ipairs(defaults) do
        if text_match.contains(preset.label, self.preset_query) then
            has_defaults = true
            break
        end
    end
    if has_defaults then table.insert(choices, {text='Skill presets'}) end
    for _, preset in ipairs(defaults) do
        if text_match.contains(preset.label, self.preset_query) then
            table.insert(choices, {
                text='  ' .. preset.label,
                default_id=preset.id,
                search_key=preset.label,
            })
        end
    end
    if #choices == 0 then table.insert(choices, {text='No matching presets.'}) end
    self.subviews.preset_list:setChoices(choices)
end

---Dispatches one explicit pass over the requested derived views.
---@param request SoulSearchRefreshRequest
function SoulSearchWindow:refresh_views(request)
    ui_refresh.apply(self, request)
end

---@param changes table
function SoulSearchWindow:update_session_settings(changes)
    window_settings.update(self.settings_id, changes)
end

---Persists filter state and refreshes every view derived from it once.
---@param selected integer|nil
function SoulSearchWindow:on_filter_state_changed(selected)
    self:update_session_settings{
        filters=filter_state.get_filters(self.filter_state),
    }
    self:refresh_views{
        active_filters=true,
        pickers=true,
        candidates=true,
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
    self.available_filter_choices = choices
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
        selected_filters=filter_state.get_ranking_filters(self.filter_state),
    })
    search.sort_results(
        self.results,
        self.result_sort_key,
        self.result_sort_reverse)

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
    self.subviews.result_columns:setText(ui_format.format_result_columns(
        self.result_sort_key,
        self.result_sort_reverse))

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
    self.stats_records = ui_components.update_stats_panel(
        self.subviews.stats_header,
        self.subviews.stats_columns,
        self.subviews.stats,
        result,
        self.stats_sort_key,
        self.stats_sort_reverse,
        self.frame_body)
end

---@param column string
function SoulSearchWindow:cycle_result_sort(column)
    if self.result_sort_key == column then
        self.result_sort_phase = self.result_sort_phase + 1
    else
        self.result_sort_key = column
        self.result_sort_phase = 1
    end

    if self.result_sort_phase >= 3 then
        self.result_sort_key = nil
        self.result_sort_reverse = false
        self.result_sort_phase = 0
    else
        self.result_sort_reverse = self.result_sort_phase == 2
    end

    self:update_session_settings{result_sort={
        key=self.result_sort_key,
        reverse=self.result_sort_reverse,
        phase=self.result_sort_phase,
    }}
    self:refresh_views{results=true}
end

---@param column string
function SoulSearchWindow:cycle_stats_sort(column)
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

    self:update_session_settings{stats_sort={
        key=self.stats_sort_key,
        reverse=self.stats_sort_reverse,
        phase=self.stats_sort_phase,
    }}
    self:refresh_views{stats=true}
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
    self.add_race_open = false
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
    self.add_race_open = false
    self:on_filter_state_changed(1)
    return true
end

---@return boolean
function SoulSearchWindow:save_filter_preset()
    dialogs.showInputPrompt(
        'Save filter preset',
        'Preset name:',
        COLOR_WHITE,
        '',
        function(name) self:save_filter_preset_named(name) end,
        nil,
        40)
end

---@param name string
---@return boolean
function SoulSearchWindow:save_filter_preset_named(name)
    local success, err = filter_presets.save(
        name, filter_state.get_filters(self.filter_state))
    if not success then
        print('SoulSearch: ' .. err)
        return false
    end
    self:refresh_views{presets=true}
    return true
end

---@param name string
---@return boolean
function SoulSearchWindow:load_filter_preset(name)
    local filters, err = filter_presets.load(name)
    if not filters then
        print('SoulSearch: ' .. err)
        return false
    end
    self:apply_loaded_filter_preset(filters)
    return true
end

---@param id string
---@return boolean
function SoulSearchWindow:load_default_filter_preset(id)
    local filters = filter_defaults.get(id)
    if not filters then
        print('SoulSearch: unknown built-in preset "' .. tostring(id) .. '".')
        return false
    end
    self:apply_loaded_filter_preset(filters)
    return true
end

---@param id string
---@return boolean
function SoulSearchWindow:load_role_filter_preset(id)
    local filters = role_presets.get(id)
    if not filters then
        print('SoulSearch: unknown role preset "' .. tostring(id) .. '".')
        return false
    end
    self:apply_loaded_filter_preset(filters)
    return true
end

---@param filters SoulSearchSelectedFilter[]
function SoulSearchWindow:apply_loaded_filter_preset(filters)
    filter_state.replace(self.filter_state, filters)
    self.preset_picker_open = false
    self:on_filter_state_changed(1)
end

---Opens or closes the saved-filter preset picker.
function SoulSearchWindow:toggle_preset_picker()
    self.preset_picker_open = not self.preset_picker_open
    if self.preset_picker_open then
        self.add_filter_open = false
        self.add_skill_open = false
        self.add_race_open = false
        self.unit_scope_picker_open = false
    end
    self:refresh_views{pickers=true, presets=true}
end

---Opens or closes the filter-panel overlay.
function SoulSearchWindow:toggle_filter_panel()
    local panel = self.subviews.filter_panel_window
    if panel:is_open() then panel:close() else panel:open() end
end

---Updates state after ModalPanelWindow has opened.
function SoulSearchWindow:open_filter_panel()
    self.filter_panel_open = true
    self:refresh_views{pickers=true, presets=true}
end

---@return boolean
function SoulSearchWindow:close_filter_panel()
    return self.subviews.filter_panel_window:close()
end

---Updates state after ModalPanelWindow has closed.
function SoulSearchWindow:close_filter_panel_state()
    if not self.filter_panel_open then return false end
    self.filter_panel_open = false
    self.add_filter_open = false
    self.add_skill_open = false
    self.add_race_open = false
    self.unit_scope_picker_open = false
    self.preset_picker_open = false
    self:refresh_views{pickers=true, presets=true}
    return true
end

---@return boolean
function SoulSearchWindow:close_preset_picker()
    if not self.preset_picker_open then return false end
    self.preset_picker_open = false
    self:refresh_views{pickers=true}
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
        self.add_race_open = false
        self.unit_scope_picker_open = false
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
        self.add_race_open = false
        self.unit_scope_picker_open = false
        self.preset_picker_open = false
    end
    self:refresh_views{pickers=true}
end

---Opens or closes the skill filter picker.
function SoulSearchWindow:toggle_add_skill_dropdown()
    self.add_skill_open = not self.add_skill_open
    if self.add_skill_open then
        self.add_filter_open = false
        self.add_race_open = false
        self.unit_scope_picker_open = false
        self.preset_picker_open = false
    end
    self:refresh_views{pickers=true}
end

---Opens or closes the race candidate-scope picker.
function SoulSearchWindow:toggle_add_race_dropdown()
    self.add_race_open = not self.add_race_open
    if self.add_race_open then
        self.add_filter_open = false
        self.add_skill_open = false
        self.unit_scope_picker_open = false
        self.preset_picker_open = false
    end
    self:refresh_views{pickers=true}
end

---@return boolean
function SoulSearchWindow:close_add_filter_dropdown()
    if not self.add_filter_open and not self.add_skill_open and
            not self.add_race_open and not self.unit_scope_picker_open then
        return false
    end

    self.add_filter_open = false
    self.add_skill_open = false
    self.add_race_open = false
    self.unit_scope_picker_open = false
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

    return self:move_filter_priority(filter_id, delta)
end

---@param filter_id string
---@param delta integer
---@return boolean
function SoulSearchWindow:move_filter_priority(filter_id, delta)
    local changed, new_index = filter_state.move(self.filter_state, filter_id, delta)
    if not changed then
        return false
    end

    self:on_filter_state_changed(new_index)
    return true
end

---@param filter_id string
---@param action string
function SoulSearchWindow:handle_filter_action(filter_id, action)
    if action == 'set_high' then
        self:set_filter_direction(filter_id, FILTER_HIGH)
    elseif action == 'set_low' then
        self:set_filter_direction(filter_id, FILTER_LOW)
    elseif action == 'remove' then
        self:remove_filter(filter_id)
    elseif action == 'move_up' then
        self:move_filter_priority(filter_id, -1)
    elseif action == 'move_down' then
        self:move_filter_priority(filter_id, 1)
    end
end

---Rebuilds rows from the active unit scope and race candidate filters.
function SoulSearchWindow:refresh_candidates()
    local scope_provider = unit_scope_provider.new(self.unit_scope)
    local provider = race_filter_provider.new(
        scope_provider,
        filter_state.get_candidate_filters(self.filter_state))
    local rows, err = residents.collect_from_provider(provider)
    if not rows then
        print(err)
        self.rows = {}
    else
        self.rows = rows
    end
end

---@param scope SoulSearchUnitScope
---@return boolean changed
function SoulSearchWindow:set_unit_scope(scope)
    if scope == self.unit_scope then return false end
    unit_scope_provider.new(scope)
    self.unit_scope = scope
    self:update_session_settings{unit_scope=scope}
    self:refresh_views{candidates=true, results=true, pickers=true}
    return true
end

---Builds the unit-scope selector rows and reflects the active scope on its
---control. The popup is intentionally a short modal directly below Search.
function SoulSearchWindow:update_unit_scope_picker()
    local choices = {}
    local selected
    local selected_label
    for index, option in ipairs(unit_scope_provider.get_options()) do
        local is_selected = option.value == self.unit_scope
        if is_selected then
            selected = index
            selected_label = option.label
        end
        table.insert(choices, {
            text=ui_format.format_unit_scope_choice(option.label, is_selected),
            scope=option.value,
        })
    end
    self.subviews.unit_scope_picker_list:setChoices(choices, selected)
    self.subviews.unit_scope_label:setText(ui_format.format_unit_scope_control(
        selected_label))
end

---Opens or closes the unit-scope selector.
function SoulSearchWindow:toggle_unit_scope_picker()
    self.unit_scope_picker_open = not self.unit_scope_picker_open
    if self.unit_scope_picker_open then
        self.add_filter_open = false
        self.add_skill_open = false
        self.add_race_open = false
        self.preset_picker_open = false
    end
    self:update_unit_scope_picker()
    self:refresh_views{pickers=true}
end

---@param scope SoulSearchUnitScope
function SoulSearchWindow:select_unit_scope(scope)
    self.unit_scope_picker_open = false
    local changed = self:set_unit_scope(scope)
    self:update_unit_scope_picker()
    if not changed then
        self:refresh_views{pickers=true}
    end
end

---@param selected integer|nil
function SoulSearchWindow:update_available_race_choices(selected)
    local choices = {}
    local has_group_choice = false
    local inserted_group_gap = false
    for _, descriptor in ipairs(self.race_filter_descriptors) do
        if not filter_state.contains(self.filter_state, descriptor.id) and
                text_match.contains(descriptor.label, self.race_query) then
            local is_group = descriptor.id:sub(1, #RACE_GROUP_ID_PREFIX) ==
                RACE_GROUP_ID_PREFIX
            if not is_group and has_group_choice and not inserted_group_gap then
                table.insert(choices, {text=''})
                inserted_group_gap = true
            end
            table.insert(choices, {
                text=ui_format.format_available_filter_choice(descriptor),
                descriptor=descriptor,
                search_key=descriptor.label,
            })
            has_group_choice = has_group_choice or is_group
        end
    end
    if #choices == 0 then
        table.insert(choices, {text='No matching races.'})
    end
    self.subviews.available_race_list:setChoices(choices, selected)
    self.available_race_choices = choices
end

---Reloads candidate rows and then recomputes their ranking results.
function SoulSearchWindow:refresh_residents()
    self:refresh_views{candidates=true, results=true}
end

---@param delta integer
function SoulSearchWindow:move_result_cursor(delta)
    ui_components.move_result_cursor(self.subviews.result_list, delta)
end

---@param keys table
---@return boolean
function SoulSearchWindow:onInput(keys)
    if SoulSearchWindow.super.onInput(self, keys) then
        return true
    end
    if is_backspace_key(keys) and self:close_add_filter_dropdown() then
        return true
    end
    if is_backspace_key(keys) and self:close_filter_panel() then
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
    return false
end

---@class SoulSearchScreen: gui.ZScreen
---@field window SoulSearchWindow
SoulSearchScreen = defclass(SoulSearchScreen, gui.ZScreen)
SoulSearchScreen.ATTRS {
    focus_path='soulsearch',
    settings_id=DEFAULT_NIL,
    settings=DEFAULT_NIL,
}

---Creates the main SoulSearch window and tooltip overlay.
function SoulSearchScreen:init()
    self.window = SoulSearchWindow{
        settings_id=self.settings_id,
        settings=self.settings,
    }
    self:addviews{
        self.window,
        SoulSearchTooltip{get_text=function() return self.window:get_tooltip_text() end},
    }
end

function SoulSearchScreen:onShow()
    screen_registry.add(self)
end

---@return boolean cleaned
function SoulSearchScreen:cleanup()
    if self.cleaned_up then return false end
    self.cleaned_up = true
    self.window:persist_frame_if_needed()
    screen_registry.remove(self)
    return true
end

function SoulSearchScreen:onDismiss()
    self:cleanup()
end

function SoulSearchScreen:onDestroy()
    self:cleanup()
end

---Dismisses every screen owned by this loaded UI generation. Registry
---iteration uses a snapshot because each dismissal removes its own screen.
function dismiss_all()
    screen_registry.for_each_snapshot(function(screen)
        screen:dismiss()
        -- Keep teardown idempotent even if a screen implementation does not
        -- synchronously invoke its normal dismissal callback.
        screen_registry.remove(screen)
    end)
end

---Opens a new SoulSearch screen.
---@param options table|nil
---@return SoulSearchScreen|nil
function open(options)
    local err = residents.get_unavailable_reason()
    if err then
        print(err)
        return nil
    end

    options = type(options) == 'table' and options or nil
    local screen_width, screen_height = dfhack.screen.getWindowSize()
    local settings = window_config.resolve(options, screen_width, screen_height)
    if next(settings.explicit) then
        window_settings.update(settings.settings_id, settings.explicit)
    end
    if not settings.explicit.frame then
        settings.frame = screen_registry.place_frame(
            settings.frame, screen_width, screen_height)
    end
    local screen = SoulSearchScreen{
        settings_id=settings.settings_id,
        settings=settings,
    }:show()
    return screen
end
