local soulsearch_env = require('support.soulsearch_env')

local function ids(filters)
    local result = {}
    for _, filter in ipairs(filters) do table.insert(result, filter.id) end
    return result
end

local function make_catalog(keys)
    local by_id = {}
    for _, key in ipairs(keys) do by_id['skill:' .. key] = {} end
    for _, key in ipairs({
        'ANALYTICAL_ABILITY', 'SOCIAL_AWARENESS', 'CREATIVITY', 'MEMORY',
        'FOCUS', 'INTUITION', 'EMPATHY', 'LINGUISTIC_ABILITY',
        'KINESTHETIC_SENSE', 'WILLPOWER', 'SPATIAL_SENSE', 'PATIENCE',
    }) do by_id['mental_attribute:' .. key] = {} end
    for _, key in ipairs({'STRENGTH', 'AGILITY', 'TOUGHNESS', 'ENDURANCE'}) do
        by_id['physical_attribute:' .. key] = {}
    end
    return {get_catalog=function() return {by_id=by_id} end}
end

return function(test, repo_root)
    local role_presets = soulsearch_env.load_role_presets(repo_root,
        make_catalog({'ORGANIZATION', 'RECORD_KEEPING', 'APPRAISAL',
            'JUDGING_INTENT', 'NEGOTIATION', 'DIAGNOSIS', 'HAMMER', 'CROSSBOW',
            'ARCHERY', 'SNEAK', 'SWORD', 'MELEE_COMBAT', 'SHIELD', 'ARMOR',
            'SURGERY', 'BONE_SETTING', 'ANIMALTRAIN'}))

    test.case('role presets: expose the researched roles in a stable order', function()
        local labels = {}
        for _, preset in ipairs(role_presets.get_all()) do
            table.insert(labels, preset.label)
        end
        test.assert_sequence({'Manager', 'Bookkeeper', 'Broker',
            'Chief Medical Dwarf', 'Interrogator', 'Hammerer', 'Marksdwarf',
            'Hunter', 'Swordsdwarf', 'Doctor', 'Animal Trainer'}, labels)
    end)

    test.case('role presets: put role skills before wiki-priority attributes', function()
        test.assert_sequence({'skill:ORGANIZATION',
            'mental_attribute:ANALYTICAL_ABILITY',
            'mental_attribute:SOCIAL_AWARENESS',
            'mental_attribute:CREATIVITY'}, ids(assert(role_presets.get('manager'))))
        test.assert_sequence({'skill:CROSSBOW', 'skill:ARCHERY', 'skill:HAMMER',
            'physical_attribute:AGILITY', 'mental_attribute:SPATIAL_SENSE',
            'mental_attribute:KINESTHETIC_SENSE', 'mental_attribute:FOCUS'},
            ids(assert(role_presets.get('marksdwarf'))))
    end)

    test.case('role presets: resolve version-specific skill key fallbacks', function()
        local filters = assert(role_presets.get('doctor'))
        test.assert_equal('skill:DIAGNOSIS', filters[1].id)
        test.assert_equal('skill:BONE_SETTING', filters[3].id)
        filters[1].id = 'skill:OTHER'
        test.assert_equal('skill:DIAGNOSIS', assert(role_presets.get('doctor'))[1].id)
        test.assert_nil(role_presets.get('unknown'))
    end)
end
