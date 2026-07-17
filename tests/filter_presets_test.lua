local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
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
        test.assert_equal('soulsearch', id)
        return 'dfhack-config/mods/soulsearch/'
    end}
    local dfhack = {filesystem={
        listdir=function() return {'Miner.json', 'Read Me.txt', 'broken.json', 'Sheriff.json'} end,
        mkdir_recursive=function() return true end,
    }}
    local presets = soulsearch_env.load_filter_presets(
        repo_root, json, scriptmanager, dfhack)

    test.case('filter presets: save writes versioned JSON data', function()
        local ok = presets.save('Miner', {{id='skill:MINING', direction='high'}})
        test.assert_true(ok)
        local data = files['dfhack-config/mods/soulsearch/presets/Miner.json'].data
        test.assert_equal(1, data.version)
        test.assert_equal('skill:MINING', data.filters[1].id)
        test.assert_equal('high', data.filters[1].direction)
    end)

    test.case('filter presets: load returns an isolated filter copy', function()
        presets.save('Sheriff', {{id='skill:SWORD', direction='low'}})
        local filters = assert(presets.load('Sheriff'))
        filters[1].direction = 'high'
        local reread = assert(presets.load('Sheriff'))
        test.assert_equal('low', reread[1].direction)
    end)

    test.case('filter presets: preserve mixed candidate and ranking entries', function()
        local original = {
            {id='unit_scope:fort_residents', direction='high'},
            {id='race:group:HUMANOIDS', direction='high'},
            {id='race:raw:DWARF', direction='low'},
            {id='skill:MINING', direction='high'},
        }
        test.assert_true(presets.save('Dwarf Miners', original))
        local loaded = assert(presets.load('Dwarf Miners'))
        for index, filter in ipairs(original) do
            test.assert_equal(filter.id, loaded[index].id)
            test.assert_equal(filter.direction, loaded[index].direction)
        end
    end)

    test.case('filter presets: names are listed alphabetically and safely', function()
        test.assert_sequence({'broken', 'Miner', 'Sheriff'}, presets.list())
        test.assert_false(presets.save('../escape', {}))
        test.assert_nil(presets.load('../escape'))
    end)

    test.case('filter presets: missing preset directory is an empty list', function()
        local missing_directory = {filesystem={
            listdir=function() return nil end,
            mkdir_recursive=function() return true end,
        }}
        local empty_presets = soulsearch_env.load_filter_presets(
            repo_root, json, scriptmanager, missing_directory)
        test.assert_sequence({}, empty_presets.list())
    end)
end
