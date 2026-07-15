--@ module=true

local dialogs = require('gui.dialogs')
local widgets = require('gui.widgets')

local residents = reqscript('internal/soulsearch/residents')
local unit_scope_provider = reqscript('internal/soulsearch/unit_scope_provider')
local race_filter_provider = reqscript('internal/soulsearch/race_filter_provider')
local search_session = reqscript('internal/soulsearch/search_session')
local QUERY_KIND = search_session.SEARCH_QUERY_KIND
local descriptors = reqscript('internal/soulsearch/descriptors')
local window_settings = reqscript('internal/soulsearch/window_settings')
local window_config = reqscript('internal/soulsearch/window_config')
local filter_defaults = reqscript('internal/soulsearch/filter_defaults')
local role_presets = reqscript('internal/soulsearch/role_presets')
local filter_presets = reqscript('internal/soulsearch/filter_presets')
local skill_categories = reqscript('internal/soulsearch/skill_categories')
local filter_panel = reqscript('internal/soulsearch/ui/filter_panel')
local FilterPanel = filter_panel.FilterPanel
local ResultsPanel = reqscript('internal/soulsearch/ui/results_panel').ResultsPanel
local ui_format = reqscript('internal/soulsearch/ui_format')
local result_presenter = reqscript('internal/soulsearch/result_presenter')
local filter_presenter = reqscript('internal/soulsearch/filter_presenter')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local ui_refresh = reqscript('internal/soulsearch/ui_refresh')
local StatsPanel = reqscript('internal/soulsearch/stats_panel').SoulSearchStatsPanel
local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

local FILTER_HIGH = filter_constants.direction.HIGH
local FILTER_LOW = filter_constants.direction.LOW

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

---@param on_close function
---@return widgets.HotkeyLabel
local function create_close_button(on_close)
    return widgets.HotkeyLabel{
        view_id='close_button',
        frame=ui_layout.get_frame('close'),
        key='LEAVESCREEN',
        label='Close',
        on_activate=on_close,
    }
end

---@class SoulSearchWindow: widgets.Window
---@field session SoulSearchSearchSession
---@field suppress_result_select_refresh boolean
---@field filter_catalog SoulSearchFilterCatalog
---@field attribute_filter_descriptors SoulSearchFilterDescriptor[]
---@field skill_filter_descriptors SoulSearchFilterDescriptor[]
---@field race_filter_descriptors SoulSearchFilterDescriptor[]
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
    self.session = search_session.new(settings)
    self.suppress_result_select_refresh = false
    local filter_catalog = descriptors.get_catalog()
    local filter_descriptor_groups = filter_catalog.groups
    self.filter_catalog = filter_catalog
    self.attribute_filter_descriptors = {}
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.physical_attributes)
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.mental_attributes)
    append_descriptors(self.attribute_filter_descriptors, filter_descriptor_groups.traits)
    self.skill_filter_descriptors = filter_descriptor_groups.skills or {}
    self.race_filter_descriptors = filter_descriptor_groups.races or {}

    local views = {}
    -- The Results Panel remains first, and its query field remains its first
    -- child, preserving the effective focus traversal order.
    table.insert(views, ResultsPanel{view_id='results_panel',
        frame={l=0, t=0, r=0, b=0}, inputs={
            on_query=function(text)
                if self.session:set_query(QUERY_KIND.RESULT, text) then
                    self:refresh_views{results=true}
                end
            end,
            on_select=function(result)
                self.session:set_selected_result(result,
                    self.subviews.results_panel:get_selected_index())
                if not self.suppress_result_select_refresh then
                    self:refresh_views{stats=true, result=result}
                end
            end,
            on_submit=function(result) self:zoom_to_result(result) end,
            on_sort=function(column) self:cycle_result_sort(column) end,
        }})
    table.insert(views, filter_panel.create_button(function()
        self:toggle_filter_panel()
    end))
    table.insert(views, filter_panel.create_active_filter_count())
    table.insert(views, StatsPanel{
        view_id='stats_panel',
        frame={l=ui_layout.STATS_LEFT, t=ui_layout.HEADER_ROW, r=1, b=0},
        subject=nil,
        sort=settings.stats_sort,
        on_sort_change=function(sort)
            self:update_session_settings{stats_sort=sort}
        end,
    })
    -- Native Divider owns the visual junction with the framed window. It is a
    -- sibling added after the divided panel, as required by DFHack.
    table.insert(views, widgets.Divider{view_id='results_stats_divider',
        frame={l=ui_layout.DIVIDER_XS[1], t=ui_layout.HEADER_ROW, w=1, b=0}})
    table.insert(views, create_close_button(function()
        self.parent_view:dismiss()
    end))
    table.insert(views, FilterPanel{
        view_id='filter_panel_window', frame=ui_layout.get_frame('filter_panel'),
        frame_title='Search filters', draggable=false,
        inputs={
        unit_scope=self.session:get_unit_scope(),
        unit_scope_options=unit_scope_provider.get_options(),
        on_unit_scope_change=function(scope) self:select_unit_scope(scope) end,
        on_clear=function() self:clear_filters() end,
        on_refresh=function(request) self:refresh_views(request) end,
        on_preset_query=function(text)
            if self.session:set_query(QUERY_KIND.PRESET, text) then
                self:refresh_views{presets=true}
            end
        end,
        on_save_preset=function() self:save_filter_preset() end,
        on_load_preset=function(name) self:load_filter_preset(name) end,
        on_load_default_preset=function(id) self:load_default_filter_preset(id) end,
        on_load_role_preset=function(id) self:load_role_filter_preset(id) end,
        on_attribute_query=function(text)
            if self.session:set_query(QUERY_KIND.ATTRIBUTE, text) then
                self:refresh_views{pickers=true}
            end
        end,
        on_skill_query=function(text)
            if self.session:set_query(QUERY_KIND.SKILL, text) then
                self:refresh_views{pickers=true}
            end
        end,
        on_race_query=function(text)
            if self.session:set_query(QUERY_KIND.RACE, text) then
                self:refresh_views{pickers=true}
            end
        end,
        on_add=function(filter_id) self:add_filter(filter_id) end,
        on_filter_action=function(filter_id, action)
            self:handle_filter_action(filter_id, action)
        end,
        },
    })
    self:addviews(views)

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

---@return string|nil
function SoulSearchWindow:get_filter_action_tooltip()
    return self.subviews.filter_panel_window:get_filter_action_tooltip()
end


---@return string|nil
function SoulSearchWindow:get_result_header_tooltip()
    return self.subviews.results_panel:get_header_tooltip()
end

---@return string|nil
function SoulSearchWindow:get_filter_descriptor_tooltip()
    return self.subviews.filter_panel_window:get_descriptor_tooltip()
end


---@return string
function SoulSearchWindow:get_tooltip_text()
    local panel = self.subviews.filter_panel_window
    local filter_control_tooltip = filter_panel.get_button_tooltip(
        self.subviews.filters_button) or panel:get_control_tooltip()
    if filter_control_tooltip then return filter_control_tooltip end

    local stats_tooltip = self.subviews.stats_panel and
        self.subviews.stats_panel:get_tooltip_text() or nil
    return self:get_filter_action_tooltip() or self:get_result_header_tooltip() or
        stats_tooltip or self:get_filter_descriptor_tooltip() or ''
end

---@return SoulSearchFilterDescriptor[]
function SoulSearchWindow:get_active_filter_descriptors()
    local active_descriptors = {}

    for _, filter in ipairs(self.session:get_filters()) do
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
    return self.session:get_filter_priority(filter_id) or 1
end

---@param selected integer|nil
function SoulSearchWindow:refresh_active_filter_choices(selected)
    local choices = filter_presenter.present_active(
        self:get_active_filter_descriptors(), self.session:get_filters())
    self.subviews.filter_panel_window:set_active_filter_choices(choices, selected)
    self.subviews.active_filter_count:setText(
        'Filters: ' .. self.session:filter_count())
end

---Refreshes the two picker lists from filter state and picker queries.
function SoulSearchWindow:refresh_picker_choices()
    self:update_available_filter_choices()
    self:update_available_skill_choices()
    self:update_available_race_choices()
end

---Refreshes the saved preset names displayed by the preset picker.
function SoulSearchWindow:refresh_preset_choices()
    local choices = filter_presenter.present_presets(filter_presets.list(),
        role_presets.get_role_presets(), role_presets.get_combat_presets(),
        filter_defaults.get_all(), self.session.preset_query)
    self.subviews.filter_panel_window:set_preset_choices(choices)
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
        filters=self.session:get_filters(),
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
    local choices = filter_presenter.present_available(self.attribute_filter_descriptors,
        self.session:get_filters(), self.session.attribute_query, 'No matching attributes.')
    self.subviews.filter_panel_window:set_picker_choices(
        'attribute', choices, selected)
end

---@param selected integer|nil
function SoulSearchWindow:update_available_skill_choices(selected)
    local choices = filter_presenter.present_skills(self.skill_filter_descriptors,
        self.session:get_filters(), self.session.skill_query, skill_categories.get_order())
    self.subviews.filter_panel_window:set_picker_choices('skill', choices, selected)
end

---Recomputes results and preserves selection by unit ID when possible. If the
---previous resident disappears, the same list position is retained and clamped
---to the final row; an empty result set has no selection.
---@return SoulSearchResult|nil
function SoulSearchWindow:recompute_results()
    local results_panel = self.subviews.results_panel
    self.session:set_selected_result(results_panel:get_selected_result(),
        results_panel:get_selected_index())
    local results, selected = self.session:recompute_results()
    local sort = self.session:get_result_sort()
    local display = result_presenter.present(results, sort.key, sort.reverse)
    results_panel:set_header_text(display.title, display.underline, display.columns, sort)

    -- DFHack List:setChoices() force-fires on_select. Suppress that nested view
    -- refresh so the dispatcher remains the single owner of the Stats update.
    self.suppress_result_select_refresh = true
    results_panel:set_choices(display.choices, selected)
    self.suppress_result_select_refresh = false
    return results_panel:get_selected_result()
end

---@param result SoulSearchResult|nil
function SoulSearchWindow:refresh_stats(result)
    self.subviews.stats_panel:set_subject(result)
end

---@param column string
function SoulSearchWindow:cycle_result_sort(column)
    self:update_session_settings{result_sort=self.session:cycle_sort(column)}
    self:refresh_views{results=true}
end

---@param column string

---@return SoulSearchResult|nil
function SoulSearchWindow:get_selected_result()
    return self.subviews.results_panel:get_selected_result()
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
    if not self.session:add_filter(filter_id) then
        return false
    end
    self.subviews.filter_panel_window:close_picker()
    self:on_filter_state_changed(self:get_filter_choice_index(filter_id))
    return true
end

---@param filter_id string
---@return boolean
function SoulSearchWindow:remove_filter(filter_id)
    local selected = self.session:get_filter_priority(filter_id) or 1
    if not self.session:remove_filter(filter_id) then
        return false
    end
    self:on_filter_state_changed(math.max(
        1,
        math.min(selected, self.session:filter_count())))
    return true
end

---@return boolean
function SoulSearchWindow:clear_filters()
    if not self.session:clear_filters() then
        return false
    end

    self.subviews.filter_panel_window:close_picker()
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
        name, self.session:get_filters())
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
    self.session:replace_filters(filters)
    self.subviews.filter_panel_window:close_picker()
    self:on_filter_state_changed(1)
end

---Opens or closes the saved-filter preset picker.
function SoulSearchWindow:toggle_preset_picker()
    return self.subviews.filter_panel_window:toggle_picker('preset')
end

---Opens or closes the filter-panel overlay.
function SoulSearchWindow:toggle_filter_panel()
    local panel = self.subviews.filter_panel_window
    if panel:is_open() then panel:close() else panel:open() end
end

---Updates state after ModalPanelWindow has opened.
---@return boolean
function SoulSearchWindow:close_filter_panel()
    return self.subviews.filter_panel_window:close()
end

---Updates state after ModalPanelWindow has closed.
function SoulSearchWindow:close_filter_panel_state()
    return self:close_filter_panel()
end

---@return boolean
function SoulSearchWindow:close_preset_picker()
    local panel = self.subviews.filter_panel_window
    if not panel:is_picker_open('preset') then return false end
    return panel:close_picker()
end

---@param filter_id string
---@param direction SoulSearchFilterDirection
---@return boolean
function SoulSearchWindow:set_filter_direction(filter_id, direction)
    local was_active = self.session:contains_filter(filter_id)
    if not self.session:set_filter_direction(filter_id, direction) then
        return false
    end
    if not was_active then
        self.subviews.filter_panel_window:close_picker()
    end
    local selected = self:get_filter_choice_index(filter_id)
    self:on_filter_state_changed(selected)
    return true
end

---Opens or closes the attribute/trait filter picker.
function SoulSearchWindow:toggle_add_filter_dropdown()
    return self.subviews.filter_panel_window:toggle_picker('attribute')
end

---Opens or closes the skill filter picker.
function SoulSearchWindow:toggle_add_skill_dropdown()
    return self.subviews.filter_panel_window:toggle_picker('skill')
end

---Opens or closes the race candidate-scope picker.
function SoulSearchWindow:toggle_add_race_dropdown()
    return self.subviews.filter_panel_window:toggle_picker('race')
end

---@return boolean
function SoulSearchWindow:close_add_filter_dropdown()
    return self.subviews.filter_panel_window:close_picker()
end

---@param delta integer
---@return boolean
function SoulSearchWindow:move_selected_filter_priority(delta)
    local filter_id = self.subviews.filter_panel_window:get_selected_filter_id()
    if not filter_id then
        return false
    end

    return self:move_filter_priority(filter_id, delta)
end

---@param filter_id string
---@param delta integer
---@return boolean
function SoulSearchWindow:move_filter_priority(filter_id, delta)
    local changed, new_index = self.session:move_filter(filter_id, delta)
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
    local scope_provider = unit_scope_provider.new(self.session:get_unit_scope())
    local provider = race_filter_provider.new(
        scope_provider,
        self.session:get_candidate_filters())
    local rows, err = residents.collect_from_provider(provider)
    if not rows then
        print(err)
        self.session:replace_rows({})
    else
        self.session:replace_rows(rows)
    end
end

---@param scope SoulSearchUnitScope
---@return boolean changed
function SoulSearchWindow:set_unit_scope(scope)
    if not self.session:set_unit_scope(scope) then return false end
    self:update_session_settings{unit_scope=scope}
    self:refresh_views{candidates=true, results=true, pickers=true}
    return true
end

---Builds the unit-scope selector rows and reflects the active scope on its
---control. The popup is intentionally a short modal directly below Search.
function SoulSearchWindow:update_unit_scope_picker()
    local choices, selected, selected_label = filter_presenter.present_scopes(
        unit_scope_provider.get_options(), self.session:get_unit_scope())
    self.subviews.filter_panel_window:set_unit_scope_choices(
        choices, selected, selected_label)
end

---Opens or closes the unit-scope selector.
function SoulSearchWindow:toggle_unit_scope_picker()
    self:update_unit_scope_picker()
    return self.subviews.filter_panel_window:toggle_picker('scope')
end

---@param scope SoulSearchUnitScope
function SoulSearchWindow:select_unit_scope(scope)
    self.subviews.filter_panel_window:close_picker()
    local changed = self:set_unit_scope(scope)
    self:update_unit_scope_picker()
    if not changed then
        self:refresh_views{pickers=true}
    end
end

---@param selected integer|nil
function SoulSearchWindow:update_available_race_choices(selected)
    local choices = filter_presenter.present_races(self.race_filter_descriptors,
        self.session:get_filters(), self.session.race_query)
    self.subviews.filter_panel_window:set_picker_choices('race', choices, selected)
end

---Reloads candidate rows and then recomputes their ranking results.
function SoulSearchWindow:refresh_residents()
    self:refresh_views{candidates=true, results=true}
end

---@param delta integer
function SoulSearchWindow:move_result_cursor(delta)
    self.subviews.results_panel:move_cursor(delta)
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

