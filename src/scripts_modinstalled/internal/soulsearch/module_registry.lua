--@ module=true

---@class SoulSearchModuleSpec
---@field name string
---@field contract string
---@field contract_type string|nil

---Dependencies precede consumers so an explicit environment clear/reload
---cannot leave local reqscript references pointing at mixed generations.
---@type SoulSearchModuleSpec[]
MODULES = {
    {name='internal/soulsearch/df_enums', contract='entries'},
    {name='internal/soulsearch/skill_categories', contract='get_category'},
    {name='internal/soulsearch/text_match', contract='contains'},
    {name='internal/soulsearch/attribute_descriptions', contract='get_tooltip'},
    {name='internal/soulsearch/availability', contract='get_unavailable_reason'},
    {name='internal/soulsearch/ui_glyphs', contract='get_glyph'},
    {name='internal/soulsearch/stats_layout', contract='get_content_frames'},
    {name='internal/soulsearch/stats_popover_config', contract='resolve'},
    {name='internal/soulsearch/sort_state', contract='normalize'},
    {name='internal/soulsearch/stats_subject', contract='from_row'},
    {name='internal/soulsearch/ui_layout', contract='get_frame'},
    {
        name='internal/soulsearch/filter_constants',
        contract='FILTER_CONSTANTS',
        contract_type='table',
    },
    {name='internal/soulsearch/ui_format', contract='format_result_choice'},
    {name='internal/soulsearch/filter_presenter', contract='present_active'},
    {name='internal/soulsearch/result_presenter', contract='present'},
    {
        name='internal/soulsearch/ui/widget_extensions',
        contract='install_tooltip_attribute',
    },
    {
        name='internal/soulsearch/ui/pointer_dispatcher',
        contract='PointerDispatcher', contract_type='table',
    },
    {
        name='internal/soulsearch/ui/modal_panel',
        contract='ModalPanelWindow', contract_type='table',
    },
    {
        name='internal/soulsearch/ui/filter_action_list',
        contract='FilterActionList', contract_type='table',
    },
    {
        name='internal/soulsearch/ui/sortable_header',
        contract='new',
    },
    {name='internal/soulsearch/ui/searchable_picker', contract='SearchablePicker', contract_type='table'},
    {name='internal/soulsearch/ui/preset_picker', contract='PresetPicker', contract_type='table'},
    {name='internal/soulsearch/ui/unit_scope_picker', contract='UnitScopePicker', contract_type='table'},
    {
        name='internal/soulsearch/ui/filter_panel',
        contract='FilterPanel', contract_type='table',
    },
    {
        name='internal/soulsearch/ui/results_panel',
        contract='ResultsPanel', contract_type='table',
    },
    {name='internal/soulsearch/window_settings', contract='load'},
    {name='internal/soulsearch/attributes', contract='evaluate'},
    {name='internal/soulsearch/stats_presenter', contract='build_records'},
    {
        name='internal/soulsearch/ui/unit_stats_list',
        contract='UnitStatsList', contract_type='table',
    },
    {
        name='internal/soulsearch/stats_panel',
        contract='SoulSearchStatsPanel', contract_type='table',
    },
    {name='internal/soulsearch/race_catalog', contract='get_descriptors'},
    {name='internal/soulsearch/descriptors', contract='get_catalog'},
    {name='internal/soulsearch/candidate_provider', contract='new'},
    {name='internal/soulsearch/unit_scope_provider', contract='new'},
    {name='internal/soulsearch/filter_state', contract='get_filters'},
    {name='internal/soulsearch/window_config', contract='resolve'},
    {name='internal/soulsearch/screen_registry', contract='add'},
    {name='internal/soulsearch/race_filter_provider', contract='new'},
    {name='internal/soulsearch/filter_defaults', contract='get_all'},
    {name='internal/soulsearch/role_presets', contract='get_all'},
    {name='internal/soulsearch/filter_presets', contract='list'},
    {name='internal/soulsearch/search', contract='apply'},
    {name='internal/soulsearch/search_session', contract='new'},
    {
        name='internal/soulsearch/ui_tooltip',
        contract='SoulSearchTooltip', contract_type='table',
    },
    {name='internal/soulsearch/ui_refresh', contract='apply'},
    {name='internal/soulsearch/residents', contract='collect_from_provider'},
    {
        name='internal/soulsearch/stats_popover',
        contract='open',
    },
    {name='internal/soulsearch/keybindings', contract='ensure_default'},
    {name='internal/soulsearch/lifecycle', contract='prepare_for_world'},
    {
        name='internal/soulsearch/ui/main_window',
        contract='SoulSearchWindow', contract_type='table',
    },
    {
        name='internal/soulsearch/ui/main_screen',
        contract='SoulSearchScreen', contract_type='table',
    },
    {name='internal/soulsearch/ui', contract='open'},
}

local REGISTRY_SCRIPT = 'internal/soulsearch/module_registry'

---@param loader fun(name: string): table
---@return table<string, table>
function load_all(loader)
    local loaded = {}
    for _, spec in ipairs(MODULES) do
        local module = loader(spec.name)
        local expected_type = spec.contract_type or 'function'
        local suffix = expected_type == 'function' and '()' or ''
        assert(type(module[spec.contract]) == expected_type,
            ('SoulSearch module %s is missing %s%s'):format(
                spec.name, spec.contract, suffix))
        loaded[spec.name] = module
    end
    return loaded
end

---@return string[]
function get_script_names()
    -- Include this registry itself so an explicit reload cannot retain stale
    -- module names or contracts from an earlier development generation.
    local names = {REGISTRY_SCRIPT}
    -- Clear consumers before dependencies; load_all() rebuilds forward.
    for index = #MODULES, 1, -1 do
        table.insert(names, MODULES[index].name)
    end
    return names
end
