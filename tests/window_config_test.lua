local soulsearch_env = require('support.soulsearch_env')

local function ids(filters)
    local result = {}
    for _, filter in ipairs(filters) do table.insert(result, filter.id) end
    return result
end

return function(test, repo_root)
    test.case('window config: primary defaults retain only Humanoids', function()
        local config, settings = soulsearch_env.load_window_config(repo_root)
        settings.clear()
        local resolved = config.resolve(nil, 200, 100)
        test.assert_sequence({'race:group:HUMANOIDS'}, ids(resolved.filters))
        test.assert_nil(resolved.unit_scope)
        test.assert_nil(next(resolved.explicit))
    end)

    test.case('window config: legacy scalar options become canonical scope filters without aliasing inputs', function()
        local config, settings = soulsearch_env.load_window_config(repo_root)
        settings.clear()
        local options = {settings_id='scoped', filters={{id='skill:MINING', direction='high'}},
            unit_scope='fort_residents'}
        local resolved = config.resolve(options, 200, 100)
        test.assert_sequence({'skill:MINING', 'unit_scope:fort_residents'}, ids(resolved.filters))
        test.assert_sequence({'skill:MINING', 'unit_scope:fort_residents'}, ids(resolved.explicit.filters))
        test.assert_nil(resolved.unit_scope)
        options.filters[1].id = 'skill:SWORD'
        test.assert_equal('skill:MINING', resolved.filters[1].id)
    end)

    test.case('window config: explicit filter scopes take precedence over a simultaneous legacy scalar', function()
        local config, settings = soulsearch_env.load_window_config(repo_root)
        settings.clear()
        local resolved = config.resolve({filters={{id='unit_scope:visitors', direction='low'}},
            unit_scope='citizens'}, 200, 100)
        test.assert_sequence({'unit_scope:visitors'}, ids(resolved.filters))
    end)

    test.case('window config: all_active removes inherited unit scopes and malformed scalars do nothing', function()
        local config, settings = soulsearch_env.load_window_config(repo_root)
        settings.clear()
        settings.update('saved', {filters={{id='unit_scope:citizens', direction='high'},
            {id='skill:MINING', direction='high'}}})
        local all = config.resolve({settings_id='saved', unit_scope='all_active'}, 200, 100)
        test.assert_sequence({'skill:MINING'}, ids(all.filters))
        local malformed = config.resolve({settings_id='saved', unit_scope='bad'}, 200, 100)
        test.assert_sequence({'unit_scope:citizens', 'skill:MINING'}, ids(malformed.filters))
    end)
end
