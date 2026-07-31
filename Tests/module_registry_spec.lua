local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('module registry', function()

    local registry = soulsearch_env.load_module_registry(repo_root)

    it('module registry: validates real contracts in dependency order', function()
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
        assert.are.equal(#registry.MODULES, #calls)
        assert.are.equal('internal/soulsearch/df_enums', calls[1])
        assert.are.equal('internal/soulsearch/ui', calls[#calls])
        local constants_index, settings_index, race_catalog_index, scope_catalog_index, descriptor_index
        local candidate_index, active_index, family_index, scope_filter_index, state_index, config_index
        local screen_registry_index, stats_layout_index, stats_config_index
        local residents_index, stats_presenter_index, stats_list_index
        local stats_panel_index, popover_index
        local race_filter_index, layout_index, modal_index, action_list_index
        local format_index, filter_panel_index, results_panel_index
        local extensions_index
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
        assert.is_truthy(constants_index < race_catalog_index)
        assert.is_truthy(constants_index < settings_index)
        assert.is_truthy(settings_index < #calls)
        assert.is_truthy(race_catalog_index < descriptor_index)
        assert.is_truthy(scope_catalog_index < descriptor_index)
        assert.is_truthy(candidate_index < active_index)
        assert.is_truthy(candidate_index < family_index)
        assert.is_truthy(descriptor_index < family_index)
        assert.is_truthy(family_index < scope_filter_index)
        assert.is_truthy(settings_index < config_index)
        assert.is_truthy(state_index < config_index)
        assert.is_truthy(screen_registry_index < #calls)
        assert.is_truthy(state_index < race_filter_index)
        assert.is_truthy(stats_layout_index < stats_config_index)
        assert.is_truthy(stats_presenter_index < stats_list_index)
        assert.is_truthy(stats_list_index < stats_panel_index)
        assert.is_truthy(stats_config_index < popover_index)
        assert.is_truthy(residents_index < popover_index)
        assert.is_truthy(stats_list_index < popover_index)
        assert.is_truthy(stats_panel_index < popover_index)
        assert.is_truthy(screen_registry_index < popover_index)
        assert.is_truthy(layout_index < modal_index)
        assert.is_truthy(layout_index < format_index)
        assert.is_truthy(constants_index < format_index)
        assert.is_truthy(format_index < extensions_index)
        assert.is_truthy(extensions_index < modal_index)
        assert.is_truthy(format_index < filter_panel_index)
        assert.is_truthy(format_index < results_panel_index)
        assert.is_truthy(modal_index < action_list_index)
        assert.is_truthy(action_list_index < filter_panel_index)
        assert.is_truthy(filter_panel_index < results_panel_index)
        assert.is_truthy(filter_panel_index < main_window_index)
        assert.is_truthy(results_panel_index < main_window_index)
        assert.is_truthy(stats_panel_index < main_window_index)
        assert.is_truthy(main_window_index < main_screen_index)
        assert.is_truthy(main_screen_index < ui_index)
        assert.is_truthy(loaded['internal/soulsearch/search'].apply ~= nil)
        assert.is_truthy(
            loaded['internal/soulsearch/candidate_provider'].new ~= nil)
        assert.is_truthy(
            loaded['internal/soulsearch/race_catalog'].get_descriptors ~= nil)
        assert.is_truthy(
            loaded['internal/soulsearch/unit_scope_catalog'].get_descriptors ~= nil)
        assert.is_truthy(
            loaded['internal/soulsearch/active_unit_provider'].new ~= nil)
        assert.is_truthy(
            loaded['internal/soulsearch/candidate_filter_family_provider'].new ~= nil)
        assert.is_truthy(
            loaded['internal/soulsearch/race_filter_provider'].new ~= nil)
        assert.is_truthy(
            loaded['internal/soulsearch/unit_scope_filter_provider'].new ~= nil)
        assert.is_truthy(type(
            loaded['internal/soulsearch/filter_constants'].FILTER_CONSTANTS) ==
            'table')
    end)

    it('module registry: missing contracts fail clearly', function()
        local ok, err = pcall(registry.load_all, function() return {} end)
        assert.is_falsy(ok)
        assert.is_truthy(tostring(err):find('missing entries()', 1, true) ~= nil)
    end)

    it('module registry: widget extensions keep the reload contract', function()
        local contracts = {}
        for _, spec in ipairs(registry.MODULES) do contracts[spec.name] = spec.contract end
        assert.are.equal('install_pointer_attributes',
            contracts['internal/soulsearch/ui/widget_extensions'])
        assert.is_nil(contracts['internal/soulsearch/ui/pointer_dispatcher'])
        assert.is_nil(contracts['internal/soulsearch/ui/tooltip_agent'])
        assert.is_nil(contracts['internal/soulsearch/ui_tooltip'])
    end)

    it('module registry: clear order is reverse dependency order', function()
        local names = registry.get_script_names()
        assert.are.equal(#registry.MODULES + 1, #names)
        assert.are.equal('internal/soulsearch/module_registry', names[1])
        assert.are.equal('internal/soulsearch/ui', names[2])
        assert.are.equal('internal/soulsearch/df_enums', names[#names])
    end)

end)
