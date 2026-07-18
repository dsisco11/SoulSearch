local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local settings = soulsearch_env.load_window_settings(repo_root)

    add_test('window settings: missing and empty identities use default', function()
        settings.clear()
        luaunit.assertNil(settings.load())
        settings.update('', {filters={{id='unit_scope:citizens', direction='high'}}})
        luaunit.assertIs('unit_scope:citizens', settings.load().filters[1].id)
        luaunit.assertIs('unit_scope:citizens', settings.load('default').filters[1].id)
        local ok = pcall(settings.load, 7)
        luaunit.assertEvalToFalse(ok)
    end)

    add_test('window settings: identities are independent and clearable', function()
        settings.clear()
        settings.update('residents', {filters={{id='unit_scope:fort_residents', direction='high'}}})
        settings.update('visitors', {filters={{id='unit_scope:visitors', direction='high'}}})
        luaunit.assertIs('unit_scope:fort_residents', settings.load('residents').filters[1].id)
        luaunit.assertIs('unit_scope:visitors', settings.load('visitors').filters[1].id)
        settings.clear()
        luaunit.assertNil(settings.load('residents'))
        luaunit.assertNil(settings.load('visitors'))
    end)

    add_test('window settings: snapshots and changes never alias callers', function()
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
        luaunit.assertIs('skill:MINING', loaded.filters[1].id)
        luaunit.assertIs('high', loaded.filters[1].direction)
        luaunit.assertIs('name', loaded.result_sort.key)
        luaunit.assertIs(3, loaded.frame.l)
        loaded.filters[1].id = 'skill:SWORD'
        luaunit.assertIs('skill:MINING', settings.load().filters[1].id)
    end)

    add_test('window settings: field updates merge the latest snapshot', function()
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
        luaunit.assertIs('skill:MINING', loaded.filters[1].id)
        luaunit.assertIs('name', loaded.result_sort.key)
        luaunit.assertEvalToTrue(loaded.result_sort.reverse)
        luaunit.assertIs(7, loaded.frame.l)
        luaunit.assertIs(8, loaded.frame.t)
    end)

    add_test('window settings: unknown fields never enter a snapshot', function()
        settings.clear()
        local loaded = settings.update('default', {
            filters={{id='unit_scope:citizens', direction='high'}},
            transient_query='miner',
        })
        luaunit.assertIs('unit_scope:citizens', loaded.filters[1].id)
        luaunit.assertNil(loaded.transient_query)
    end)

return native_tests
