local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local registry = soulsearch_env.load_module_registry(repo_root)

    add_test('module registry: validates real contracts in dependency order', function()
        local calls = {}
        local loaded = registry.load_all(function(name)
            table.insert(calls, name)
            for _, spec in ipairs(registry.MODULES) do
                if spec.name == name then
                    local value = spec.contract_type == 'table' and {} or
                        function() end
                    return {[spec.contract]=value}
                end
            end
        end)
        luaunit.assertIs(#registry.MODULES, #calls)
        luaunit.assertIs('internal/soulsearch/df_enums', calls[1])
        luaunit.assertIs('internal/soulsearch/ui', calls[#calls])
        local constants_index, settings_index, race_catalog_index, scope_catalog_index, descriptor_index
        local candidate_index, active_index, family_index, scope_filter_index, state_index, config_index
        local screen_registry_index, stats_layout_index, stats_config_index
        local residents_index, stats_presenter_index, stats_list_index
        local stats_panel_index, tooltip_index, popover_index
        local race_filter_index, layout_index, modal_index, action_list_index
        local format_index, filter_panel_index, results_panel_index
        local extensions_index, pointer_index, tooltip_agent_index
        local main_window_index, main_screen_index, ui_index
        for index, name in ipairs(calls) do
            if name == 'internal/soulsearch/filter_constants' then
                constants_index = index
            elseif name == 'internal/soulsearch/window_settings' then
                settings_index = index
            elseif name == 'internal/soulsearch/race_catalog' then
                race_catalog_index = index
            elseif name == 'internal/soulsearch/unit_scope_catalog' then
                scope_catalog_index = index
            elseif name == 'internal/soulsearch/descriptors' then
                descriptor_index = index
            elseif name == 'internal/soulsearch/candidate_provider' then
                candidate_index = index
            elseif name == 'internal/soulsearch/active_unit_provider' then
                active_index = index
            elseif name == 'internal/soulsearch/candidate_filter_family_provider' then
                family_index = index
            elseif name == 'internal/soulsearch/unit_scope_filter_provider' then
                scope_filter_index = index
            elseif name == 'internal/soulsearch/filter_state' then
                state_index = index
            elseif name == 'internal/soulsearch/window_config' then
                config_index = index
            elseif name == 'internal/soulsearch/screen_registry' then
                screen_registry_index = index
            elseif name == 'internal/soulsearch/stats_layout' then
                stats_layout_index = index
            elseif name == 'internal/soulsearch/stats_popover_config' then
                stats_config_index = index
            elseif name == 'internal/soulsearch/residents' then
                residents_index = index
            elseif name == 'internal/soulsearch/stats_panel' then
                stats_panel_index = index
            elseif name == 'internal/soulsearch/stats_presenter' then
                stats_presenter_index = index
            elseif name == 'internal/soulsearch/ui/unit_stats_list' then
                stats_list_index = index
            elseif name == 'internal/soulsearch/ui_tooltip' then
                tooltip_index = index
            elseif name == 'internal/soulsearch/stats_popover' then
                popover_index = index
            elseif name == 'internal/soulsearch/race_filter_provider' then
                race_filter_index = index
            elseif name == 'internal/soulsearch/ui_layout' then
                layout_index = index
            elseif name == 'internal/soulsearch/ui_format' then
                format_index = index
            elseif name == 'internal/soulsearch/ui/modal_panel' then
                modal_index = index
            elseif name == 'internal/soulsearch/ui/widget_extensions' then
                extensions_index = index
            elseif name == 'internal/soulsearch/ui/pointer_dispatcher' then
                pointer_index = index
            elseif name == 'internal/soulsearch/ui/tooltip_agent' then
                tooltip_agent_index = index
            elseif name == 'internal/soulsearch/ui/filter_action_list' then
                action_list_index = index
            elseif name == 'internal/soulsearch/ui/filter_panel' then
                filter_panel_index = index
            elseif name == 'internal/soulsearch/ui/results_panel' then
                results_panel_index = index
            elseif name == 'internal/soulsearch/ui/main_window' then
                main_window_index = index
            elseif name == 'internal/soulsearch/ui/main_screen' then
                main_screen_index = index
            elseif name == 'internal/soulsearch/ui' then
                ui_index = index
            end
        end
        luaunit.assertEvalToTrue(constants_index < race_catalog_index)
        luaunit.assertEvalToTrue(constants_index < settings_index)
        luaunit.assertEvalToTrue(settings_index < #calls)
        luaunit.assertEvalToTrue(race_catalog_index < descriptor_index)
        luaunit.assertEvalToTrue(scope_catalog_index < descriptor_index)
        luaunit.assertEvalToTrue(candidate_index < active_index)
        luaunit.assertEvalToTrue(candidate_index < family_index)
        luaunit.assertEvalToTrue(descriptor_index < family_index)
        luaunit.assertEvalToTrue(family_index < scope_filter_index)
        luaunit.assertEvalToTrue(settings_index < config_index)
        luaunit.assertEvalToTrue(state_index < config_index)
        luaunit.assertEvalToTrue(screen_registry_index < #calls)
        luaunit.assertEvalToTrue(state_index < race_filter_index)
        luaunit.assertEvalToTrue(stats_layout_index < stats_config_index)
        luaunit.assertEvalToTrue(stats_presenter_index < stats_list_index)
        luaunit.assertEvalToTrue(stats_list_index < stats_panel_index)
        luaunit.assertEvalToTrue(stats_config_index < popover_index)
        luaunit.assertEvalToTrue(residents_index < popover_index)
        luaunit.assertEvalToTrue(stats_list_index < popover_index)
        luaunit.assertEvalToTrue(stats_panel_index < popover_index)
        luaunit.assertEvalToTrue(tooltip_index < popover_index)
        luaunit.assertEvalToTrue(screen_registry_index < popover_index)
        luaunit.assertEvalToTrue(layout_index < modal_index)
        luaunit.assertEvalToTrue(layout_index < format_index)
        luaunit.assertEvalToTrue(constants_index < format_index)
        luaunit.assertEvalToTrue(format_index < extensions_index)
        luaunit.assertEvalToTrue(extensions_index < pointer_index)
        luaunit.assertEvalToTrue(pointer_index < tooltip_agent_index)
        luaunit.assertEvalToTrue(tooltip_agent_index < tooltip_index)
        luaunit.assertEvalToTrue(extensions_index < modal_index)
        luaunit.assertEvalToTrue(format_index < filter_panel_index)
        luaunit.assertEvalToTrue(format_index < results_panel_index)
        luaunit.assertEvalToTrue(modal_index < action_list_index)
        luaunit.assertEvalToTrue(action_list_index < filter_panel_index)
        luaunit.assertEvalToTrue(filter_panel_index < results_panel_index)
        luaunit.assertEvalToTrue(filter_panel_index < main_window_index)
        luaunit.assertEvalToTrue(results_panel_index < main_window_index)
        luaunit.assertEvalToTrue(stats_panel_index < main_window_index)
        luaunit.assertEvalToTrue(tooltip_index < main_window_index)
        luaunit.assertEvalToTrue(main_window_index < main_screen_index)
        luaunit.assertEvalToTrue(main_screen_index < ui_index)
        luaunit.assertEvalToTrue(loaded['internal/soulsearch/search'].apply ~= nil)
        luaunit.assertEvalToTrue(
            loaded['internal/soulsearch/candidate_provider'].new ~= nil)
        luaunit.assertEvalToTrue(
            loaded['internal/soulsearch/race_catalog'].get_descriptors ~= nil)
        luaunit.assertEvalToTrue(
            loaded['internal/soulsearch/unit_scope_catalog'].get_descriptors ~= nil)
        luaunit.assertEvalToTrue(
            loaded['internal/soulsearch/active_unit_provider'].new ~= nil)
        luaunit.assertEvalToTrue(
            loaded['internal/soulsearch/candidate_filter_family_provider'].new ~= nil)
        luaunit.assertEvalToTrue(
            loaded['internal/soulsearch/race_filter_provider'].new ~= nil)
        luaunit.assertEvalToTrue(
            loaded['internal/soulsearch/unit_scope_filter_provider'].new ~= nil)
        luaunit.assertEvalToTrue(type(
            loaded['internal/soulsearch/filter_constants'].FILTER_CONSTANTS) ==
            'table')
    end)

    add_test('module registry: missing contracts fail clearly', function()
        local ok, err = pcall(registry.load_all, function() return {} end)
        luaunit.assertEvalToFalse(ok)
        luaunit.assertEvalToTrue(tostring(err):find('missing entries()', 1, true) ~= nil)
    end)

    add_test('module registry: pointer infrastructure has the reload contract', function()
        local contracts = {}
        for _, spec in ipairs(registry.MODULES) do contracts[spec.name] = spec.contract end
        luaunit.assertIs('install_pointer_attributes',
            contracts['internal/soulsearch/ui/widget_extensions'])
        luaunit.assertIs('PointerDispatcher',
            contracts['internal/soulsearch/ui/pointer_dispatcher'])
        luaunit.assertIs('TooltipAgent',
            contracts['internal/soulsearch/ui/tooltip_agent'])
    end)

    add_test('module registry: clear order is reverse dependency order', function()
        local names = registry.get_script_names()
        luaunit.assertIs(#registry.MODULES + 1, #names)
        luaunit.assertIs('internal/soulsearch/module_registry', names[1])
        luaunit.assertIs('internal/soulsearch/ui', names[2])
        luaunit.assertIs('internal/soulsearch/df_enums', names[#names])
    end)

return native_tests
