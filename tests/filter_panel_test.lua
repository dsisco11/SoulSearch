local soulsearch_env = require('support.soulsearch_env')

local function by_id(views, id)
    for _, view in ipairs(views or {}) do
        if view.view_id == id then return view end
    end
end

local function index_subviews(view, root)
    root = root or view
    for _, child in ipairs(view.subviews or {}) do
        view.subviews[child.view_id] = child
        root.subviews[child.view_id] = child
        index_subviews(child, root)
    end
end

return function(test, repo_root)
    local filter_panel, picker_modules = soulsearch_env.load_filter_panel(repo_root)
    local noop = function() end

    local function make_inputs(state, calls)
        return {
            is_filter_panel_open=function() return state.panel end,
            on_open_filter_panel=function() state.panel = true end,
            on_close_filter_panel_state=function() state.panel = false end,
            on_close_filter_panel=noop,
            is_attribute_picker_open=function() return state.attribute end,
            is_skill_picker_open=function() return state.skill end,
            is_race_picker_open=function() return state.race end,
            is_unit_scope_picker_open=function() return state.scope end,
            unit_scope='fort_residents',
            unit_scope_options={{label='Residents', value='fort_residents'},
                {label='Visitors', value='visitors'}},
            on_unit_scope_change=function(scope) calls.scope = scope end,
            on_toggle_unit_scope_picker=noop,
            on_toggle_attribute_picker=noop, on_toggle_skill_picker=noop,
            on_toggle_race_picker=noop, on_clear=noop, on_refresh=noop,
            is_preset_picker_open=function() return state.preset end,
            on_toggle_preset_picker=noop, on_close_preset_picker=noop,
            on_preset_query=function(text) calls.preset_query = text end,
            on_save_preset=function() calls.saved = true end,
            on_load_preset=function(name) calls.preset = name end,
            on_load_default_preset=function(id) calls.default = id end,
            on_load_role_preset=function(id) calls.role = id end,
            on_close_picker=noop,
            on_attribute_query=function(text) calls.attribute_query = text end,
            on_skill_query=function(text) calls.skill_query = text end,
            on_race_query=function(text) calls.race_query = text end,
            on_toggle_filter=function(id) calls.toggled = id end,
            on_filter_action=function(id, action) calls.action = {id, action} end,
        }
    end

    test.case('filter panel: picker modules export named window widget classes', function()
        test.assert_equal('table', type(picker_modules[
            'internal/soulsearch/ui/searchable_picker'].SearchablePicker))
        test.assert_equal('table', type(picker_modules[
            'internal/soulsearch/ui/preset_picker'].PresetPicker))
        test.assert_equal('table', type(picker_modules[
            'internal/soulsearch/ui/unit_scope_picker'].UnitScopePicker))
    end)

    test.case('filter panel: initializer owns picker hierarchy and paint order', function()
        local state, calls = {panel=true, attribute=false, skill=false, race=false,
            scope=false, preset=false}, {}
        local inputs = make_inputs(state, calls)
        local panel = filter_panel.FilterPanel{
            view_id='filter_panel_window', is_open=inputs.is_filter_panel_open,
            on_open=inputs.on_open_filter_panel,
            on_close=inputs.on_close_filter_panel_state, inputs=inputs}
        test.assert_equal('filter_panel_window', panel.view_id)
        test.assert_sequence({
            'close_filter_panel_button', 'unit_scope_label', 'unit_scope_edit',
            'add_filter_button', 'add_skill_button', 'add_race_button',
            'clear_filters_button', 'preset_button', 'filter_list',
            'available_filter_window', 'available_race_window',
            'available_skill_window', 'preset_picker_window',
            'unit_scope_picker_window',
        }, (function()
            local ids = {}
            for _, view in ipairs(panel.subviews) do table.insert(ids, view.view_id) end
            return ids
        end)())
        test.assert_equal('unit_scope_picker_window',
            panel.subviews[#panel.subviews].view_id)
        test.assert_equal('Close', panel.subviews.close_filter_panel_button.tooltip)
        test.assert_equal('Choose which units are included in the results.',
            panel.subviews.unit_scope_edit.tooltip)
        test.assert_equal('Add an attribute or trait to the ranking criteria.',
            panel.subviews.add_filter_button.tooltip)
        test.assert_equal('Add a skill to the ranking criteria.',
            panel.subviews.add_skill_button.tooltip)
        test.assert_equal('Add a race to the candidate scope.',
            panel.subviews.add_race_button.tooltip)
        test.assert_equal('Save the current filters or load a custom, role, or skill preset.',
            panel.subviews.preset_button.tooltip)
        local attribute_picker = by_id(panel.subviews, 'available_filter_window')
        local preset_picker = by_id(panel.subviews, 'preset_picker_window')
        test.assert_equal('Close', attribute_picker.subviews[1].tooltip)
        test.assert_equal('Close', preset_picker.subviews[1].tooltip)
        test.assert_equal('Save the current ordered filters under this preset name.',
            preset_picker.subviews[2].tooltip)
        test.assert_equal('CUSTOM_T',
            by_id(panel.subviews, 'available_filter_window').subviews[2].key)
        test.assert_equal('CUSTOM_K',
            by_id(panel.subviews, 'available_skill_window').subviews[2].key)
        test.assert_equal('CUSTOM_G',
            by_id(panel.subviews, 'available_race_window').subviews[2].key)
        test.assert_true(by_id(panel.subviews, 'filter_list').frame ~= nil)
        test.assert_true(by_id(panel.subviews, 'available_filter_window').frame ~= nil)
        test.assert_false(by_id(panel.subviews, 'available_filter_window').visible)
        test.assert_true(by_id(panel.subviews, 'filter_list').visible())
        test.assert_equal('Include: Residents',
            by_id(panel.subviews, 'unit_scope_label').text)
        panel:toggle_picker('attribute')
        test.assert_false(by_id(panel.subviews, 'filter_list').visible())
        test.assert_true(by_id(panel.subviews, 'available_filter_window').visible)
    end)

    test.case('filter panel: picker submissions preserve descriptor and preset payloads', function()
        local state, calls = {panel=true}, {}
        local inputs = make_inputs(state, calls)
        local panel = filter_panel.FilterPanel{
            view_id='filter_panel_window', is_open=inputs.is_filter_panel_open,
            on_open=inputs.on_open_filter_panel,
            on_close=inputs.on_close_filter_panel_state, inputs=inputs}
        by_id(panel.subviews, 'available_filter_window').subviews[3].on_submit(
            1, {descriptor={id='attribute:strength'}})
        by_id(panel.subviews, 'preset_picker_window').subviews[4].on_submit(
            1, {role_id='miner'})
        by_id(panel.subviews, 'unit_scope_picker_window').subviews[1].on_submit(
            1, {scope='visitors'})
        test.assert_equal('attribute:strength', calls.toggled)
        test.assert_equal('miner', calls.role)
        test.assert_equal('visitors', calls.scope)
    end)

    test.case('filter panel: narrow update APIs own child choice updates', function()
        local state, calls = {panel=true}, {}
        local inputs = make_inputs(state, calls)
        local panel = filter_panel.FilterPanel{
            view_id='filter_panel_window', is_open=inputs.is_filter_panel_open,
            on_open=inputs.on_open_filter_panel,
            on_close=inputs.on_close_filter_panel_state, inputs=inputs}
        index_subviews(panel)
        local function choices(view, values, selected)
            view.last_choices, view.last_selected = values, selected
        end
        for _, id in ipairs({'filter_list', 'available_filter_list',
                'available_skill_list', 'available_race_list', 'preset_list',
                'unit_scope_picker_list'}) do
            panel.subviews[id].setChoices = choices
        end
        panel.subviews.unit_scope_label.setText=function(self, text) self.text = text end
        panel:set_active_filter_choices({'active'}, 1)
        panel:set_picker_choices('attribute', {'attribute'}, 2)
        panel:set_picker_choices('skill', {'skill'}, 3)
        panel:set_picker_choices('race', {'race'}, 4)
        panel:set_preset_choices({'preset'})
        panel:set_unit_scope_choices({'scope'}, 1, 'Residents')
        test.assert_sequence({'active'}, panel.subviews.filter_list.last_choices)
        test.assert_sequence({'race'}, panel.subviews.available_race_list.last_choices)
        test.assert_sequence({'preset'}, panel.subviews.preset_list.last_choices)
        test.assert_equal('Include: Residents', panel.subviews.unit_scope_label.text)
    end)

    test.case('filter panel: picker transition table is exclusive and closes cleanly', function()
        local state, calls = {panel=false}, {}
        local inputs = make_inputs(state, calls)
        local refreshes = {}
        inputs.on_refresh=function(request) table.insert(refreshes, request) end
        local panel = filter_panel.FilterPanel{
            view_id='filter_panel_window', inputs=inputs}
        panel.setFocus=noop
        index_subviews(panel)
        test.assert_false(panel.visible)
        test.assert_true(panel:open())
        test.assert_true(panel.visible)
        for _, kind in ipairs({'attribute', 'skill', 'race', 'scope', 'preset'}) do
            test.assert_true(panel:toggle_picker(kind))
            test.assert_true(panel:is_picker_open(kind))
            test.assert_false(panel.subviews.filter_list.visible())
        end
        test.assert_true(panel:close_picker())
        test.assert_false(panel:has_open_picker())
        test.assert_true(panel.subviews.filter_list.visible())
        panel:toggle_picker('race')
        test.assert_true(panel:close())
        test.assert_false(panel:is_open())
        test.assert_false(panel.visible)
        test.assert_false(panel:has_open_picker())
        test.assert_equal(13, #refreshes)
    end)

    test.case('filter panel: picker lists own dynamic descriptor tooltips', function()
        local state, calls = {panel=true}, {}
        local inputs = make_inputs(state, calls)
        local panel = filter_panel.FilterPanel{
            view_id='filter_panel_window', is_open=inputs.is_filter_panel_open,
            on_open=inputs.on_open_filter_panel,
            on_close=inputs.on_close_filter_panel_state, inputs=inputs}
        panel:set_picker_choices('attribute', {
            {descriptor={kind='trait', key='PATIENCE'}},
        }, 1)
        local attribute_list = by_id(panel.subviews,
            'available_filter_window').subviews[3]
        attribute_list.on_pointer_update(attribute_list, 0, 0)
        test.assert_equal('A personality trait that shapes behavior and social interaction.',
            attribute_list.tooltip)

        panel:set_picker_choices('race', {
            {descriptor={kind='race', key='DWARF'}},
        }, 1)
        local race_list = by_id(panel.subviews,
            'available_race_window').subviews[3]
        race_list.on_pointer_update(race_list, 0, 0)
        test.assert_equal('Filters by a creatures race.', race_list.tooltip)
        race_list.on_pointer_update(race_list, 0, 4)
        test.assert_equal(nil, race_list.tooltip)
    end)
end
