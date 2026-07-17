local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local settings = soulsearch_env.load_window_settings(repo_root)

    test.case('window settings: missing and empty identities use default', function()
        settings.clear()
        test.assert_nil(settings.load())
        settings.update('', {filters={{id='unit_scope:citizens', direction='high'}}})
        test.assert_equal('unit_scope:citizens', settings.load().filters[1].id)
        test.assert_equal('unit_scope:citizens', settings.load('default').filters[1].id)
        local ok = pcall(settings.load, 7)
        test.assert_false(ok)
    end)

    test.case('window settings: identities are independent and clearable', function()
        settings.clear()
        settings.update('residents', {filters={{id='unit_scope:fort_residents', direction='high'}}})
        settings.update('visitors', {filters={{id='unit_scope:visitors', direction='high'}}})
        test.assert_equal('unit_scope:fort_residents', settings.load('residents').filters[1].id)
        test.assert_equal('unit_scope:visitors', settings.load('visitors').filters[1].id)
        settings.clear()
        test.assert_nil(settings.load('residents'))
        test.assert_nil(settings.load('visitors'))
    end)

    test.case('window settings: snapshots and changes never alias callers', function()
        settings.clear()
        local changes = {
            filters={{id='skill:MINING', direction='high'}},
            result_sort={key='name', reverse=false, phase=1},
            frame={l=3, t=4, w=150, h=45},
        }
        local updated = settings.update('default', changes)
        changes.filters[1].id = 'skill:SWORD'
        changes.result_sort.key = 'unit_id'
        changes.frame.l = 9
        updated.filters[1].direction = 'low'
        local loaded = settings.load('default')
        test.assert_equal('skill:MINING', loaded.filters[1].id)
        test.assert_equal('high', loaded.filters[1].direction)
        test.assert_equal('name', loaded.result_sort.key)
        test.assert_equal(3, loaded.frame.l)
        loaded.filters[1].id = 'skill:SWORD'
        test.assert_equal('skill:MINING', settings.load().filters[1].id)
    end)

    test.case('window settings: field updates merge the latest snapshot', function()
        settings.clear()
        settings.update('default', {
            filters={{id='skill:MINING', direction='high'}},
            frame={l=1, t=2, w=150, h=45},
        })
        settings.update('default', {
            result_sort={key='name', reverse=true, phase=2},
        })
        settings.update('default', {frame={l=7, t=8, w=150, h=45}})
        local loaded = settings.load('default')
        test.assert_equal('skill:MINING', loaded.filters[1].id)
        test.assert_equal('name', loaded.result_sort.key)
        test.assert_true(loaded.result_sort.reverse)
        test.assert_equal(7, loaded.frame.l)
        test.assert_equal(8, loaded.frame.t)
    end)

    test.case('window settings: unknown fields never enter a snapshot', function()
        settings.clear()
        local loaded = settings.update('default', {
            filters={{id='unit_scope:citizens', direction='high'}},
            transient_query='miner',
        })
        test.assert_equal('unit_scope:citizens', loaded.filters[1].id)
        test.assert_nil(loaded.transient_query)
    end)
end
