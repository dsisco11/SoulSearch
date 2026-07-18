local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local files = {}
    local json = {
        open=function(path)
            files[path] = files[path] or {}
            local config = files[path]
            function config:write() self.written = true end
            return config
        end,
    }
    local scriptmanager = {getModStatePath=function(id)
        luaunit.assertIs('soulsearch', id)
        return 'dfhack-config/mods/soulsearch/'
    end}
    local dfhack = {filesystem={
        listdir=function() return {'Miner.json', 'Read Me.txt', 'broken.json', 'Sheriff.json'} end,
        mkdir_recursive=function() return true end,
    }}
    local presets = soulsearch_env.load_filter_presets(
        repo_root, json, scriptmanager, dfhack)

    add_test('filter presets: save writes versioned JSON data', function()
        local ok = presets.save('Miner', {{id='skill:MINING', direction='high'}})
        luaunit.assertEvalToTrue(ok)
        local data = files['dfhack-config/mods/soulsearch/presets/Miner.json'].data
        luaunit.assertIs(1, data.version)
        luaunit.assertIs('skill:MINING', data.filters[1].id)
        luaunit.assertIs('high', data.filters[1].direction)
    end)

    add_test('filter presets: load returns an isolated filter copy', function()
        presets.save('Sheriff', {{id='skill:SWORD', direction='low'}})
        local filters = assert(presets.load('Sheriff'))
        filters[1].direction = 'high'
        local reread = assert(presets.load('Sheriff'))
        luaunit.assertIs('low', reread[1].direction)
    end)

    add_test('filter presets: preserve mixed candidate and ranking entries', function()
        local original = {
            {id='unit_scope:fort_residents', direction='high'},
            {id='race:group:HUMANOIDS', direction='high'},
            {id='race:raw:DWARF', direction='low'},
            {id='skill:MINING', direction='high'},
        }
        luaunit.assertEvalToTrue(presets.save('Dwarf Miners', original))
        local loaded = assert(presets.load('Dwarf Miners'))
        for index, filter in ipairs(original) do
            luaunit.assertIs(filter.id, loaded[index].id)
            luaunit.assertIs(filter.direction, loaded[index].direction)
        end
    end)

    add_test('filter presets: names are listed alphabetically and safely', function()
        luaunit.assertEquals({'broken', 'Miner', 'Sheriff'}, presets.list())
        luaunit.assertEvalToFalse(presets.save('../escape', {}))
        luaunit.assertNil(presets.load('../escape'))
    end)

    add_test('filter presets: missing preset directory is an empty list', function()
        local missing_directory = {filesystem={
            listdir=function() return nil end,
            mkdir_recursive=function() return true end,
        }}
        local empty_presets = soulsearch_env.load_filter_presets(
            repo_root, json, scriptmanager, missing_directory)
        luaunit.assertEquals({}, empty_presets.list())
    end)

return native_tests
