local soulsearch_env = require('support.soulsearch_env')

local function ids(filters)
    local result = {}
    for _, filter in ipairs(filters) do table.insert(result, filter.id) end
    return result
end

local function first(count, values)
    local result = {}
    for index = 1, count do table.insert(result, values[index]) end
    return result
end

local function contains(values, expected)
    for _, value in ipairs(values) do
        if value == expected then return true end
    end
    return false
end

local function make_catalog(keys)
    local by_id = {}
    for _, key in ipairs(keys) do by_id['skill:' .. key] = {} end
    for _, key in ipairs({
        'ANALYTICAL_ABILITY', 'SOCIAL_AWARENESS', 'CREATIVITY', 'MEMORY',
        'FOCUS', 'INTUITION', 'EMPATHY', 'LINGUISTIC_ABILITY',
        'KINESTHETIC_SENSE', 'WILLPOWER', 'SPATIAL_SENSE', 'MUSICALITY', 'PATIENCE',
    }) do by_id['mental:' .. key] = {} end
    for _, key in ipairs({'STRENGTH', 'AGILITY', 'TOUGHNESS', 'ENDURANCE'}) do
        by_id['physical:' .. key] = {}
    end
    return {get_catalog=function() return {by_id=by_id} end}
end

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local role_presets = soulsearch_env.load_role_presets(repo_root,
        make_catalog({'ORGANIZATION', 'RECORD_KEEPING', 'APPRAISAL',
            'JUDGING_INTENT', 'NEGOTIATION', 'DIAGNOSIS', 'HAMMER', 'CROSSBOW',
            'ARCHERY', 'SNEAK', 'SWORD', 'MELEE_COMBAT', 'SHIELD', 'ARMOR',
            'SURGERY', 'BONE_SETTING', 'SUTURE', 'DRESS_WOUNDS', 'ANIMALTRAIN',
            'DODGING', 'DISCIPLINE',
            'AXE', 'DAGGER', 'MACE', 'SPEAR', 'PIKE', 'WHIP', 'WRESTLING',
            'LYING', 'LEADERSHIP', 'PERSUASION', 'CONVERSATION', 'INTIMIDATION',
            'MILITARY_TACTICS', 'SNEAK', 'CRITICAL_THINKING', 'LOGIC',
            'READING', 'WRITING', 'TEACHING', 'POETRY', 'DANCE', 'MAKE_MUSIC',
            'SING_MUSIC', 'SPEAKING', 'COMEDY', 'FLATTERY', 'CONSOLING',
            'PACIFICATION'}))

    add_test('role presets: expose the researched roles in a stable order', function()
        local labels = {}
        for _, preset in ipairs(role_presets.get_all()) do
            table.insert(labels, preset.label)
        end
        luaunit.assertEquals({'Manager', 'Bookkeeper', 'Broker',
            'Chief Medical Dwarf', 'Interrogator', 'Doctor', 'Animal Trainer'},
            first(7, labels))
        luaunit.assertIs(true, contains(labels, 'Trader'))
        luaunit.assertIs(true, contains(labels, 'Baron'))
        luaunit.assertIs(true, contains(labels, 'Militia Commander'))
        luaunit.assertIs(true, contains(labels, 'Scholar'))
        luaunit.assertIs(true, contains(labels, 'Messenger'))
    end)

    add_test('role presets: put role skills before wiki-priority attributes', function()
        luaunit.assertEquals({'skill:ORGANIZATION',
            'mental:ANALYTICAL_ABILITY',
            'mental:SOCIAL_AWARENESS',
            'mental:CREATIVITY'},
            first(4, ids(assert(role_presets.get('manager')))))
        luaunit.assertEquals({'skill:CROSSBOW', 'skill:ARCHERY', 'skill:HAMMER',
            'skill:DODGING', 'skill:SHIELD', 'skill:ARMOR',
            'physical:AGILITY', 'mental:SPATIAL_SENSE',
            'mental:KINESTHETIC_SENSE', 'mental:FOCUS'},
            first(10, ids(assert(role_presets.get('marksdwarf')))))
    end)

    add_test('role presets: merge each selected skill preset attributes', function()
        local marksdwarf = ids(assert(role_presets.get('marksdwarf')))
        luaunit.assertIs(true, contains(marksdwarf, 'physical:TOUGHNESS'))
        luaunit.assertIs(true, contains(marksdwarf, 'physical:ENDURANCE'))
        local doctor = ids(assert(role_presets.get('doctor')))
        luaunit.assertIs(true, contains(doctor, 'mental:EMPATHY'))
        local militia_commander = ids(assert(role_presets.get('militia_commander')))
        luaunit.assertIs(true, contains(militia_commander, 'mental:INTUITION'))
        luaunit.assertIs(true, contains(militia_commander, 'mental:SPATIAL_SENSE'))
        luaunit.assertIs(true,
            contains(militia_commander, 'mental:KINESTHETIC_SENSE'))
        luaunit.assertIs(true, contains(militia_commander, 'mental:FOCUS'))
    end)

    add_test('role presets: separate complete combat presets and add dodging', function()
        local combat = role_presets.get_combat_presets()
        luaunit.assertIs('Militia Commander', combat[1].label)
        luaunit.assertIs('Militia Captain', combat[2].label)
        luaunit.assertIs('Soldier', combat[3].label)
        luaunit.assertIs('Hammerer', combat[#combat].label)
        luaunit.assertEquals({'skill:AXE', 'skill:MELEE_COMBAT', 'skill:DODGING',
            'skill:SHIELD', 'skill:ARMOR'},
            first(5, ids(assert(role_presets.get('axedwarf')))))
        luaunit.assertIs('role', role_presets.get_role_presets()[1].category)
        luaunit.assertIs('combat', combat[1].category)
    end)

    add_test('role presets: add the missing leadership, service, and culture roles', function()
        luaunit.assertEquals({'skill:APPRAISAL', 'skill:JUDGING_INTENT',
            'skill:NEGOTIATION'}, first(3, ids(assert(role_presets.get('trader')))))
        luaunit.assertEquals({'skill:LEADERSHIP', 'skill:MILITARY_TACTICS',
            'skill:ORGANIZATION'},
            first(3, ids(assert(role_presets.get('militia_commander')))))
        luaunit.assertIs(true, contains(ids(assert(role_presets.get('performer'))),
            'mental:MUSICALITY'))
        local mayor = ids(assert(role_presets.get('mayor')))
        luaunit.assertIs(true, contains(mayor, 'skill:COMEDY'))
        luaunit.assertIs(true, contains(mayor, 'skill:CONSOLING'))
        luaunit.assertIs(true, contains(mayor, 'skill:PACIFICATION'))
        luaunit.assertIs(true, contains(mayor, 'mental:KINESTHETIC_SENSE'))
    end)

    add_test('role presets: resolve version-specific skill key fallbacks', function()
        local filters = assert(role_presets.get('doctor'))
        luaunit.assertIs('skill:DIAGNOSIS', filters[1].id)
        luaunit.assertIs('skill:BONE_SETTING', filters[3].id)
        filters[1].id = 'skill:OTHER'
        luaunit.assertIs('skill:DIAGNOSIS', assert(role_presets.get('doctor'))[1].id)
        luaunit.assertNil(role_presets.get('unknown'))
    end)

return native_tests
