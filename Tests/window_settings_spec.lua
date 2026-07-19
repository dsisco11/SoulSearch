local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('window settings', function()

    local settings = soulsearch_env.load_window_settings(repo_root)

    it('window settings: missing and empty identities use default', function()
        settings.clear()
        assert.is_nil(settings.load())
        settings.update('', {filters={{id='unit_scope:citizens', direction='high'}}})
        assert.are.equal('unit_scope:citizens', settings.load().filters[1].id)
        assert.are.equal('unit_scope:citizens', settings.load('default').filters[1].id)
        local ok = pcall(settings.load, 7)
        assert.is_falsy(ok)
    end)

    it('window settings: identities are independent and clearable', function()
        settings.clear()
        settings.update('residents', {filters={{id='unit_scope:fort_residents', direction='high'}}})
        settings.update('visitors', {filters={{id='unit_scope:visitors', direction='high'}}})
        assert.are.equal('unit_scope:fort_residents', settings.load('residents').filters[1].id)
        assert.are.equal('unit_scope:visitors', settings.load('visitors').filters[1].id)
        settings.clear()
        assert.is_nil(settings.load('residents'))
        assert.is_nil(settings.load('visitors'))
    end)

    it('window settings: snapshots and changes never alias callers', function()
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
        assert.are.equal('skill:MINING', loaded.filters[1].id)
        assert.are.equal('high', loaded.filters[1].direction)
        assert.are.equal('name', loaded.result_sort.key)
        assert.are.equal(3, loaded.frame.l)
        loaded.filters[1].id = 'skill:SWORD'
        assert.are.equal('skill:MINING', settings.load().filters[1].id)
    end)

    it('window settings: field updates merge the latest snapshot', function()
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
        assert.are.equal('skill:MINING', loaded.filters[1].id)
        assert.are.equal('name', loaded.result_sort.key)
        assert.is_truthy(loaded.result_sort.reverse)
        assert.are.equal(7, loaded.frame.l)
        assert.are.equal(8, loaded.frame.t)
    end)

    it('window settings: unknown fields never enter a snapshot', function()
        settings.clear()
        local loaded = settings.update('default', {
            filters={{id='unit_scope:citizens', direction='high'}},
            transient_query='miner',
        })
        assert.are.equal('unit_scope:citizens', loaded.filters[1].id)
        assert.is_nil(loaded.transient_query)
    end)

end)
