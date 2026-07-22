local soulsearch_env = require('support.soulsearch_env')

local function ids(filters)
    local result = {}
    for _, filter in ipairs(filters) do table.insert(result, filter.id) end
    return result
end

local repo_root = require('support.repo_root')

describe('filter defaults', function()

    local defaults = soulsearch_env.load_filter_defaults(repo_root)

    it('built-in presets: expose every explicit wiki skill row', function()
        local labels = {}
        for _, preset in ipairs(defaults.get_all()) do
            table.insert(labels, preset.label)
        end
        assert.are.equal(137, #labels)
        assert.are.equal('Miner', labels[1])
        assert.are.equal('Stone carver', labels[#labels])
        assert.is_nil(defaults.get('scholar'))
        assert.is_nil(defaults.get('sheriff'))
        assert.is_nil(defaults.get('manager'))
    end)

    it('built-in presets: preserve wiki A, B, C priority order', function()
        assert.are.same({
            'physical:AGILITY',
            'mental:SPATIAL_SENSE',
            'mental:KINESTHETIC_SENSE',
            'mental:FOCUS',
        }, ids(assert(defaults.get('crossbowman'))))
        assert.are.same({
            'mental:ANALYTICAL_ABILITY',
            'mental:SPATIAL_SENSE',
            'mental:MEMORY',
        }, ids(assert(defaults.get('mathematician'))))
    end)

    it('built-in presets: cover every wiki soul attribute', function()
        local actual = {}
        for _, preset in ipairs(defaults.get_all()) do
            for _, filter in ipairs(preset.filters) do
                local attribute = filter.id:match('^mental:(.+)$')
                if attribute then actual[attribute] = true end
            end
        end
        assert.are.same({
            ANALYTICAL_ABILITY=true,
            CREATIVITY=true,
            EMPATHY=true,
            FOCUS=true,
            INTUITION=true,
            KINESTHETIC_SENSE=true,
            LINGUISTIC_ABILITY=true,
            MEMORY=true,
            MUSICALITY=true,
            PATIENCE=true,
            SOCIAL_AWARENESS=true,
            SPATIAL_SENSE=true,
            WILLPOWER=true,
        }, actual)
    end)

    it('built-in presets: reads do not alias the catalog', function()
        local filters = assert(defaults.get('miner'))
        filters[1].id = 'physical:AGILITY'
        assert.are.equal('physical:STRENGTH',
            assert(defaults.get('miner'))[1].id)
        assert.is_nil(defaults.get('unknown'))
    end)

end)
