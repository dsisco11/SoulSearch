local soulsearch_env = require('support.soulsearch_env')

local function ids(filters)
    local result = {}
    for _, filter in ipairs(filters) do table.insert(result, filter.id) end
    return result
end

return function(test, repo_root)
    test.case('window config: defaults are valid concrete instance settings', function()
        local config, settings = soulsearch_env.load_window_config(repo_root)
        settings.clear()
        local resolved = config.resolve(nil, 200, 100)
        test.assert_equal('default', resolved.settings_id)
        test.assert_sequence({'race:group:HUMANOIDS'}, ids(resolved.filters))
        test.assert_equal('citizens', resolved.unit_scope)
        test.assert_nil(resolved.result_sort.key)
        test.assert_equal(0, resolved.result_sort.phase)
        test.assert_nil(resolved.stats_sort.key)
        test.assert_equal(45, resolved.frame.l)
        test.assert_equal(27, resolved.frame.t)
        test.assert_equal(110, resolved.frame.w)
        test.assert_equal(45, resolved.frame.h)
        test.assert_nil(next(resolved.explicit))
    end)

    test.case('window config: options override saved fields independently', function()
        local config, settings = soulsearch_env.load_window_config(repo_root)
        settings.clear()
        settings.update('animals', {
            filters={{id='skill:SWORD', direction='low'}},
            unit_scope='visitors',
            result_sort={key='profession', reverse=true, phase=2},
            stats_sort={key='label', reverse=false, phase=1},
            frame={l=2, t=3, w=100, h=35},
        })
        local options = {
            settings_id='animals',
            filters={{id='skill:MINING', direction='high'}},
            unit_scope='unknown',
            stats_sort={key='value', reverse=true, phase=2},
        }
        local resolved = config.resolve(options, 200, 100)
        test.assert_sequence(
            {'race:group:HUMANOIDS', 'skill:MINING'}, ids(resolved.filters))
        test.assert_equal('citizens', resolved.unit_scope)
        test.assert_equal('profession', resolved.result_sort.key)
        test.assert_true(resolved.result_sort.reverse)
        test.assert_equal('value', resolved.stats_sort.key)
        test.assert_false(resolved.stats_sort.reverse)
        test.assert_equal(2, resolved.frame.l)
        test.assert_true(resolved.explicit.filters ~= nil)
        test.assert_equal('citizens', resolved.explicit.unit_scope)
        test.assert_nil(resolved.explicit.result_sort)
        test.assert_true(resolved.explicit.stats_sort ~= nil)
        options.filters[1].id = 'skill:SWORD'
        test.assert_equal('skill:MINING', resolved.filters[2].id)
        settings.update(resolved.settings_id, resolved.explicit)
        local persisted = settings.load('animals')
        test.assert_equal('skill:MINING', persisted.filters[2].id)
        test.assert_equal('profession', persisted.result_sort.key)
        test.assert_equal(2, persisted.frame.l)
    end)

    test.case('window config: malformed sorts fall back to unsorted', function()
        local config, settings = soulsearch_env.load_window_config(repo_root)
        settings.clear()
        local resolved = config.resolve({
            result_sort={key='future', reverse=true, phase=2},
            stats_sort={key='label', reverse=true, phase=7},
        }, 200, 100)
        test.assert_nil(resolved.result_sort.key)
        test.assert_false(resolved.result_sort.reverse)
        test.assert_equal(0, resolved.result_sort.phase)
        test.assert_nil(resolved.stats_sort.key)
        test.assert_false(resolved.stats_sort.reverse)
        test.assert_equal(0, resolved.stats_sort.phase)
    end)

    test.case('window config: frames clamp to screen and resize minimum', function()
        local config, settings = soulsearch_env.load_window_config(repo_root)
        settings.clear()
        local resolved = config.resolve({
            frame={l=-50, t=999, w=500, h=2},
        }, 100, 40)
        test.assert_equal(0, resolved.frame.l)
        test.assert_equal(10, resolved.frame.t)
        test.assert_equal(100, resolved.frame.w)
        test.assert_equal(30, resolved.frame.h)
        test.assert_equal(0, resolved.explicit.frame.l)
    end)

    test.case('window config: filter validation removes stale entries', function()
        local config, settings = soulsearch_env.load_window_config(repo_root)
        settings.clear()
        local resolved = config.resolve({
            filters={{id='skill:UNKNOWN', direction='sideways'}},
        }, 200, 100)
        test.assert_sequence({'race:group:HUMANOIDS'}, ids(resolved.filters))
    end)

    test.case('window config: instance settings are isolated and reopen latest identity', function()
        local config, settings = soulsearch_env.load_window_config(repo_root)
        settings.clear()
        settings.update('miners', {
            filters={{id='skill:MINING', direction='high'}},
            unit_scope='citizens',
        })
        settings.update('soldiers', {
            filters={{id='skill:SWORD', direction='high'}},
            unit_scope='fort_residents',
        })
        local miners = config.resolve({settings_id='miners'}, 200, 100)
        local soldiers = config.resolve({settings_id='soldiers'}, 200, 100)
        miners.filters[2].direction = 'low'
        miners.unit_scope = 'visitors'
        test.assert_equal('high', soldiers.filters[2].direction)
        test.assert_equal('fort_residents', soldiers.unit_scope)
        test.assert_equal('high',
            settings.load('miners').filters[1].direction)

        settings.update('miners', {
            filters={{id='trait:PATIENCE', direction='low'}},
        })
        local reopened = config.resolve({settings_id='miners'}, 200, 100)
        test.assert_sequence(
            {'race:group:HUMANOIDS', 'trait:PATIENCE'}, ids(reopened.filters))
        test.assert_equal('low', reopened.filters[2].direction)
    end)
end
