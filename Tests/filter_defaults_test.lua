local soulsearch_env = require('support.soulsearch_env')

local function ids(filters)
    local result = {}
    for _, filter in ipairs(filters) do table.insert(result, filter.id) end
    return result
end

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local defaults = soulsearch_env.load_filter_defaults(repo_root)

    add_test('built-in presets: expose every explicit wiki skill row', function()
        local labels = {}
        for _, preset in ipairs(defaults.get_all()) do
            table.insert(labels, preset.label)
        end
        luaunit.assertIs(137, #labels)
        luaunit.assertIs('Miner', labels[1])
        luaunit.assertIs('Stone carver', labels[#labels])
        luaunit.assertNil(defaults.get('scholar'))
        luaunit.assertNil(defaults.get('sheriff'))
        luaunit.assertNil(defaults.get('manager'))
    end)

    add_test('built-in presets: preserve wiki A, B, C priority order', function()
        luaunit.assertEquals({
            'physical:AGILITY',
            'mental:SPATIAL_SENSE',
            'mental:KINESTHETIC_SENSE',
            'mental:FOCUS',
        }, ids(assert(defaults.get('crossbowman'))))
        luaunit.assertEquals({
            'mental:ANALYTICAL_ABILITY',
            'mental:SPATIAL_SENSE',
            'mental:MEMORY',
        }, ids(assert(defaults.get('mathematician'))))
    end)

    add_test('built-in presets: reads do not alias the catalog', function()
        local filters = assert(defaults.get('miner'))
        filters[1].id = 'physical:AGILITY'
        luaunit.assertIs('physical:STRENGTH',
            assert(defaults.get('miner'))[1].id)
        luaunit.assertNil(defaults.get('unknown'))
    end)

return native_tests
