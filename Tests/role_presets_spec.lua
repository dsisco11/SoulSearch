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

local repo_root = require('support.repo_root')

describe('role presets', function()

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

    it('role presets: expose the researched roles in a stable order', function()
        local labels = {}
        for _, preset in ipairs(role_presets.get_all()) do
            table.insert(labels, preset.label)
        end
        assert.are.same({'Manager', 'Bookkeeper', 'Broker',
            'Chief Medical Dwarf', 'Interrogator', 'Doctor', 'Animal Trainer'},
            first(7, labels))
        assert.are.equal(true, contains(labels, 'Trader'))
        assert.are.equal(true, contains(labels, 'Baron'))
        assert.are.equal(true, contains(labels, 'Militia Commander'))
        assert.are.equal(true, contains(labels, 'Scholar'))
        assert.are.equal(true, contains(labels, 'Messenger'))
    end)

    it('role presets: put role skills before wiki-priority attributes', function()
        assert.are.same({'skill:ORGANIZATION',
            'mental:ANALYTICAL_ABILITY',
            'mental:SOCIAL_AWARENESS',
            'mental:CREATIVITY'},
            first(4, ids(assert(role_presets.get('manager')))))
        assert.are.same({'skill:CROSSBOW', 'skill:ARCHERY', 'skill:HAMMER',
            'skill:DODGING', 'skill:SHIELD', 'skill:ARMOR',
            'physical:AGILITY', 'mental:SPATIAL_SENSE',
            'mental:KINESTHETIC_SENSE', 'mental:FOCUS'},
            first(10, ids(assert(role_presets.get('marksdwarf')))))
    end)

    it('role presets: merge each selected skill preset attributes', function()
        local marksdwarf = ids(assert(role_presets.get('marksdwarf')))
        assert.are.equal(true, contains(marksdwarf, 'physical:TOUGHNESS'))
        assert.are.equal(true, contains(marksdwarf, 'physical:ENDURANCE'))
        local doctor = ids(assert(role_presets.get('doctor')))
        assert.are.equal(true, contains(doctor, 'mental:EMPATHY'))
        local militia_commander = ids(assert(role_presets.get('militia_commander')))
        assert.are.equal(true, contains(militia_commander, 'mental:INTUITION'))
        assert.are.equal(true, contains(militia_commander, 'mental:SPATIAL_SENSE'))
        assert.are.equal(true,
            contains(militia_commander, 'mental:KINESTHETIC_SENSE'))
        assert.are.equal(true, contains(militia_commander, 'mental:FOCUS'))
    end)

    it('role presets: separate complete combat presets and add dodging', function()
        local combat = role_presets.get_combat_presets()
        assert.are.equal('Militia Commander', combat[1].label)
        assert.are.equal('Militia Captain', combat[2].label)
        assert.are.equal('Soldier', combat[3].label)
        assert.are.equal('Hammerer', combat[#combat].label)
        assert.are.same({'skill:AXE', 'skill:MELEE_COMBAT', 'skill:DODGING',
            'skill:SHIELD', 'skill:ARMOR'},
            first(5, ids(assert(role_presets.get('axedwarf')))))
        assert.are.equal('role', role_presets.get_role_presets()[1].category)
        assert.are.equal('combat', combat[1].category)
    end)

    it('role presets: add the missing leadership, service, and culture roles', function()
        assert.are.same({'skill:APPRAISAL', 'skill:JUDGING_INTENT',
            'skill:NEGOTIATION'}, first(3, ids(assert(role_presets.get('trader')))))
        assert.are.same({'skill:LEADERSHIP', 'skill:MILITARY_TACTICS',
            'skill:ORGANIZATION'},
            first(3, ids(assert(role_presets.get('militia_commander')))))
        assert.are.equal(true, contains(ids(assert(role_presets.get('performer'))),
            'mental:MUSICALITY'))
        local mayor = ids(assert(role_presets.get('mayor')))
        assert.are.equal(true, contains(mayor, 'skill:COMEDY'))
        assert.are.equal(true, contains(mayor, 'skill:CONSOLING'))
        assert.are.equal(true, contains(mayor, 'skill:PACIFICATION'))
        assert.are.equal(true, contains(mayor, 'mental:KINESTHETIC_SENSE'))
    end)

    it('role presets: resolve version-specific skill key fallbacks', function()
        local filters = assert(role_presets.get('doctor'))
        assert.are.equal('skill:DIAGNOSIS', filters[1].id)
        assert.are.equal('skill:BONE_SETTING', filters[3].id)
        filters[1].id = 'skill:OTHER'
        assert.are.equal('skill:DIAGNOSIS', assert(role_presets.get('doctor'))[1].id)
        assert.is_nil(role_presets.get('unknown'))
    end)

end)
