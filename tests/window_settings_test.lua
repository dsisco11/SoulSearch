local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local settings = soulsearch_env.load_window_settings(repo_root)

    test.case('window settings: missing and empty identities use default', function()
        settings.clear()
        test.assert_nil(settings.load())
        settings.update('', {unit_scope='citizens'})
        test.assert_equal('citizens', settings.load().unit_scope)
        test.assert_equal('citizens', settings.load('default').unit_scope)
        local ok = pcall(settings.load, 7)
        test.assert_false(ok)
    end)

    test.case('window settings: identities are independent and clearable', function()
        settings.clear()
        settings.update('residents', {unit_scope='fort_residents'})
        settings.update('visitors', {unit_scope='visitors'})
        test.assert_equal('fort_residents', settings.load('residents').unit_scope)
        test.assert_equal('visitors', settings.load('visitors').unit_scope)
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
            unit_scope='citizens',
            frame={l=1, t=2, w=150, h=45},
        })
        settings.update('default', {
            result_sort={key='name', reverse=true, phase=2},
        })
        settings.update('default', {frame={l=7, t=8, w=150, h=45}})
        local loaded = settings.load('default')
        test.assert_equal('skill:MINING', loaded.filters[1].id)
        test.assert_equal('citizens', loaded.unit_scope)
        test.assert_equal('name', loaded.result_sort.key)
        test.assert_true(loaded.result_sort.reverse)
        test.assert_equal(7, loaded.frame.l)
        test.assert_equal(8, loaded.frame.t)
    end)

    test.case('window settings: unknown fields never enter a snapshot', function()
        settings.clear()
        local loaded = settings.update('default', {
            unit_scope='citizens',
            transient_query='miner',
        })
        test.assert_equal('citizens', loaded.unit_scope)
        test.assert_nil(loaded.transient_query)
    end)
end
