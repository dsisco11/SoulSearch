local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('filter presets', function()

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
        assert.are.equal('soulsearch', id)
        return 'dfhack-config/mods/soulsearch/'
    end}
    local dfhack = {filesystem={
        listdir=function() return {'Miner.json', 'Read Me.txt', 'broken.json', 'Sheriff.json'} end,
        mkdir_recursive=function() return true end,
    }}
    local presets = soulsearch_env.load_filter_presets(
        repo_root, json, scriptmanager, dfhack)

    it('filter presets: save writes versioned JSON data', function()
        local ok = presets.save('Miner', {{id='skill:MINING', direction='high'}})
        assert.is_truthy(ok)
        local data = files['dfhack-config/mods/soulsearch/presets/Miner.json'].data
        assert.are.equal(1, data.version)
        assert.are.equal('skill:MINING', data.filters[1].id)
        assert.are.equal('high', data.filters[1].direction)
    end)

    it('filter presets: load returns an isolated filter copy', function()
        presets.save('Sheriff', {{id='skill:SWORD', direction='low'}})
        local filters = assert(presets.load('Sheriff'))
        filters[1].direction = 'high'
        local reread = assert(presets.load('Sheriff'))
        assert.are.equal('low', reread[1].direction)
    end)

    it('filter presets: preserve mixed candidate and ranking entries', function()
        local original = {
            {id='unit_scope:fort_residents', direction='high'},
            {id='race:group:HUMANOIDS', direction='high'},
            {id='race:raw:DWARF', direction='low'},
            {id='skill:MINING', direction='high'},
        }
        assert.is_truthy(presets.save('Dwarf Miners', original))
        local loaded = assert(presets.load('Dwarf Miners'))
        for index, filter in ipairs(original) do
            assert.are.equal(filter.id, loaded[index].id)
            assert.are.equal(filter.direction, loaded[index].direction)
        end
    end)

    it('filter presets: names are listed alphabetically and safely', function()
        assert.are.same({'broken', 'Miner', 'Sheriff'}, presets.list())
        assert.is_falsy(presets.save('../escape', {}))
        assert.is_nil(presets.load('../escape'))
    end)

    it('filter presets: missing preset directory is an empty list', function()
        local missing_directory = {filesystem={
            listdir=function() return nil end,
            mkdir_recursive=function() return true end,
        }}
        local empty_presets = soulsearch_env.load_filter_presets(
            repo_root, json, scriptmanager, missing_directory)
        assert.are.same({}, empty_presets.list())
    end)

end)
