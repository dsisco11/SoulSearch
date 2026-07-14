local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local registry = soulsearch_env.load_module_registry(repo_root)

    test.case('module registry: validates real contracts in dependency order', function()
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
        test.assert_equal(#registry.MODULES, #calls)
        test.assert_equal('internal/soulsearch/df_enums', calls[1])
        test.assert_equal('internal/soulsearch/ui', calls[#calls])
        local constants_index, settings_index, race_catalog_index, descriptor_index
        local candidate_index, scope_index, state_index, config_index
        local screen_registry_index, stats_layout_index, stats_config_index
        local residents_index, stats_panel_index, tooltip_index, popover_index
        local race_filter_index, layout_index, modal_index, action_list_index
        local components_index
        for index, name in ipairs(calls) do
            if name == 'internal/soulsearch/filter_constants' then
                constants_index = index
            elseif name == 'internal/soulsearch/window_settings' then
                settings_index = index
            elseif name == 'internal/soulsearch/race_catalog' then
                race_catalog_index = index
            elseif name == 'internal/soulsearch/descriptors' then
                descriptor_index = index
            elseif name == 'internal/soulsearch/candidate_provider' then
                candidate_index = index
            elseif name == 'internal/soulsearch/unit_scope_provider' then
                scope_index = index
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
            elseif name == 'internal/soulsearch/ui_tooltip' then
                tooltip_index = index
            elseif name == 'internal/soulsearch/stats_popover' then
                popover_index = index
            elseif name == 'internal/soulsearch/race_filter_provider' then
                race_filter_index = index
            elseif name == 'internal/soulsearch/ui_layout' then
                layout_index = index
            elseif name == 'internal/soulsearch/ui/modal_panel' then
                modal_index = index
            elseif name == 'internal/soulsearch/ui/filter_action_list' then
                action_list_index = index
            elseif name == 'internal/soulsearch/ui_components' then
                components_index = index
            end
        end
        test.assert_true(constants_index < race_catalog_index)
        test.assert_true(constants_index < settings_index)
        test.assert_true(settings_index < #calls)
        test.assert_true(race_catalog_index < descriptor_index)
        test.assert_true(candidate_index < scope_index)
        test.assert_true(scope_index < state_index)
        test.assert_true(settings_index < config_index)
        test.assert_true(scope_index < config_index)
        test.assert_true(state_index < config_index)
        test.assert_true(screen_registry_index < #calls)
        test.assert_true(state_index < race_filter_index)
        test.assert_true(stats_layout_index < stats_config_index)
        test.assert_true(stats_config_index < popover_index)
        test.assert_true(residents_index < popover_index)
        test.assert_true(stats_panel_index < popover_index)
        test.assert_true(tooltip_index < popover_index)
        test.assert_true(screen_registry_index < popover_index)
        test.assert_true(layout_index < modal_index)
        test.assert_true(modal_index < action_list_index)
        test.assert_true(action_list_index < components_index)
        test.assert_true(loaded['internal/soulsearch/search'].apply ~= nil)
        test.assert_true(
            loaded['internal/soulsearch/candidate_provider'].new ~= nil)
        test.assert_true(
            loaded['internal/soulsearch/race_catalog'].get_descriptors ~= nil)
        test.assert_true(
            loaded['internal/soulsearch/unit_scope_provider'].new ~= nil)
        test.assert_true(
            loaded['internal/soulsearch/race_filter_provider'].new ~= nil)
        test.assert_true(type(
            loaded['internal/soulsearch/filter_constants'].FILTER_CONSTANTS) ==
            'table')
    end)

    test.case('module registry: missing contracts fail clearly', function()
        local ok, err = pcall(registry.load_all, function() return {} end)
        test.assert_false(ok)
        test.assert_true(tostring(err):find('missing entries()', 1, true) ~= nil)
    end)

    test.case('module registry: clear order is reverse dependency order', function()
        local names = registry.get_script_names()
        test.assert_equal(#registry.MODULES + 1, #names)
        test.assert_equal('internal/soulsearch/module_registry', names[1])
        test.assert_equal('internal/soulsearch/ui', names[2])
        test.assert_equal('internal/soulsearch/df_enums', names[#names])
    end)
end
