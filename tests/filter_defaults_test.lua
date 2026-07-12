local soulsearch_env = require('support.soulsearch_env')

local function ids(filters)
    local result = {}
    for _, filter in ipairs(filters) do table.insert(result, filter.id) end
    return result
end

return function(test, repo_root)
    local defaults = soulsearch_env.load_filter_defaults(repo_root)

    test.case('built-in presets: expose every wiki skill-table row', function()
        local labels = {}
        for _, preset in ipairs(defaults.get_all()) do
            table.insert(labels, preset.label)
        end
        test.assert_equal(137, #labels)
        test.assert_equal('Miner', labels[1])
        test.assert_equal('Stone carver', labels[#labels])
        test.assert_nil(defaults.get('scholar'))
        test.assert_nil(defaults.get('sheriff'))
        test.assert_nil(defaults.get('manager'))
    end)

    test.case('built-in presets: preserve wiki A, B, C priority order', function()
        test.assert_sequence({
            'physical_attribute:AGILITY',
            'mental_attribute:SPATIAL_SENSE',
            'mental_attribute:KINESTHETIC_SENSE',
            'mental_attribute:FOCUS',
        }, ids(assert(defaults.get('crossbowman'))))
        test.assert_sequence({
            'mental_attribute:ANALYTICAL_ABILITY',
            'mental_attribute:SPATIAL_SENSE',
            'mental_attribute:MEMORY',
        }, ids(assert(defaults.get('mathematician'))))
    end)

    test.case('built-in presets: reads do not alias the catalog', function()
        local filters = assert(defaults.get('miner'))
        filters[1].id = 'physical_attribute:AGILITY'
        test.assert_equal('physical_attribute:STRENGTH',
            assert(defaults.get('miner'))[1].id)
        test.assert_nil(defaults.get('unknown'))
    end)
end
