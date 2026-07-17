local soulsearch_env = require('support.soulsearch_env')

local function descriptor_ids(descriptor_list)
    local result = {}
    for _, descriptor in ipairs(descriptor_list) do
        table.insert(result, descriptor.id)
    end
    return result
end

return function(test, repo_root)
    local df_enums = soulsearch_env.load_df_enums(repo_root)
    local skill_categories = soulsearch_env.load_skill_categories(repo_root)

    test.case('df enums: excludes NONE and orders sparse numeric values', function()
        local enum = {
            [1]='NONE',
            [2]='ALPHA',
            [3]='BETA',
            NONE=-1,
            ALPHA=10,
            BETA=3,
            ALPHA_ALIAS=10,
        }
        local entries = df_enums.entries(enum)
        test.assert_equal(2, #entries)
        test.assert_equal('BETA', entries[1].name)
        test.assert_equal(3, entries[1].value)
        test.assert_equal('ALPHA', entries[2].name)
        test.assert_equal(10, entries[2].value)

        local names = df_enums.names_by_value(enum)
        test.assert_equal('BETA', names[3])
        test.assert_equal('ALPHA', names[10])
        test.assert_nil(names[-1])
    end)

    test.case('skill taxonomy: preserves category order and aliases', function()
        test.assert_sequence(
            {'Labor', 'Combat', 'Social', 'Other Skills', 'Knowledge'},
            skill_categories.get_order())
        test.assert_equal('Labor', skill_categories.get_category('WOODCUTTING'))
        test.assert_equal('Labor', skill_categories.get_category('WOOD_CUTTING'))
        test.assert_equal('Combat', skill_categories.get_category('SWORD'))
        test.assert_equal('Social', skill_categories.get_category('PERSUASION'))
        test.assert_equal('Knowledge', skill_categories.get_category('WRITING'))
        test.assert_equal('Other Skills', skill_categories.get_category('SWIMMING'))
        test.assert_equal(186, #skill_categories.get_known_keys())
    end)

    test.case('skill taxonomy: reports fallback keys without printing', function()
        test.assert_equal('Other Skills', skill_categories.get_category('FUTURE_SKILL'))
        test.assert_false(skill_categories.is_known('FUTURE_SKILL'))
        test.assert_sequence(
            {'ANOTHER_FUTURE_SKILL', 'FUTURE_SKILL'},
            skill_categories.get_uncategorized({
                'MINING',
                'FUTURE_SKILL',
                'ANOTHER_FUTURE_SKILL',
            }))
    end)

    test.case('skill taxonomy: every fixture skill is explicit or fallback', function()
        local keys = {}
        for _, entry in ipairs(df_enums.entries(
                soulsearch_env.make_df_stub().job_skill)) do
            table.insert(keys, entry.name)
            test.assert_true(type(skill_categories.get_category(entry.name)) == 'string')
        end
        test.assert_sequence(
            {'UNLISTED_SKILL'},
            skill_categories.get_uncategorized(keys))
    end)

    test.case('descriptor catalog: caches one catalog with indexed IDs', function()
        local descriptors = soulsearch_env.load_descriptors(repo_root)
        local first = descriptors.get_catalog()
        local second = descriptors.get_catalog()
        test.assert_true(first == second)
        test.assert_equal(25, #first.flat)

        local seen = {}
        for _, descriptor in ipairs(first.flat) do
            test.assert_false(seen[descriptor.id], 'duplicate id: ' .. descriptor.id)
            seen[descriptor.id] = true
            test.assert_true(first.by_id[descriptor.id] == descriptor)
        end
    end)

    test.case('descriptor catalog: preserves group and flat ordering', function()
        local descriptors = soulsearch_env.load_descriptors(repo_root)
        local catalog = descriptors.get_catalog()
        test.assert_sequence({
            'unit_scope:citizens',
            'unit_scope:fort_residents',
            'unit_scope:citizens_and_pets',
            'unit_scope:livestock',
            'unit_scope:visitors',
            'unit_scope:wildlife',
        }, descriptor_ids(catalog.groups.unit_scopes))
        test.assert_sequence({
            'skill:MINING',
            'skill:PERSUASION',
            'skill:SWIMMING',
            'skill:SWORD',
            'skill:UNLISTED_SKILL',
            'skill:WRITING',
        }, descriptor_ids(catalog.groups.skills))
        test.assert_sequence({
            'physical_attribute:AGILITY',
            'physical_attribute:STRENGTH',
        }, descriptor_ids(catalog.groups.physical_attributes))
        test.assert_sequence({
            'mental_attribute:FOCUS',
            'mental_attribute:WILLPOWER',
        }, descriptor_ids(catalog.groups.mental_attributes))
        test.assert_sequence({
            'trait:BRAVERY',
            'trait:PATIENCE',
        }, descriptor_ids(catalog.groups.traits))
        test.assert_sequence({
            'race:group:HUMANOIDS',
            'race:group:TAMEABLE_ANIMALS',
            'race:group:WORK_ANIMALS',
            'race:group:DOMESTIC_ANIMALS',
            'race:group:WILD_ANIMALS',
            'race:group:MEGABEASTS',
            'race:group:VERMIN',
        }, descriptor_ids(catalog.groups.races))
        test.assert_sequence({
            'skill:MINING',
            'skill:PERSUASION',
            'skill:SWIMMING',
            'skill:SWORD',
            'skill:UNLISTED_SKILL',
            'skill:WRITING',
            'physical_attribute:AGILITY',
            'physical_attribute:STRENGTH',
            'mental_attribute:FOCUS',
            'mental_attribute:WILLPOWER',
            'trait:BRAVERY',
            'trait:PATIENCE',
            'unit_scope:citizens',
            'unit_scope:fort_residents',
            'unit_scope:citizens_and_pets',
            'unit_scope:livestock',
            'unit_scope:visitors',
            'unit_scope:wildlife',
            'race:group:HUMANOIDS',
            'race:group:TAMEABLE_ANIMALS',
            'race:group:WORK_ANIMALS',
            'race:group:DOMESTIC_ANIMALS',
            'race:group:WILD_ANIMALS',
            'race:group:MEGABEASTS',
            'race:group:VERMIN',
        }, descriptor_ids(catalog.flat))
        test.assert_equal('Mining', catalog.by_id['skill:MINING'].label)
        test.assert_equal('Labor', catalog.by_id['skill:MINING'].category)
        test.assert_equal('Other Skills',
            catalog.by_id['skill:UNLISTED_SKILL'].category)
    end)

    test.case('descriptor catalog: scopes and races are candidates and stats are ranking descriptors', function()
        local descriptors = soulsearch_env.load_descriptors(repo_root)
        for _, descriptor in ipairs(descriptors.get_catalog().flat) do
            local expected = (descriptor.kind == 'race' or
                descriptor.kind == 'unit_scope') and 'candidate' or 'ranking'
            test.assert_equal(expected, descriptor.behavior)
        end
    end)

    test.case('descriptor catalog: rejects duplicate descriptor IDs', function()
        local duplicate_df = soulsearch_env.make_df_stub()
        duplicate_df.personality_facet_type = {
            [1]='PATIENCE',
            [2]='PATIENCE',
            PATIENCE=2,
        }
        local descriptors = soulsearch_env.load_descriptors(repo_root, duplicate_df)
        local ok, err = pcall(descriptors.get_catalog)
        test.assert_false(ok)
        test.assert_true(tostring(err):find(
            'duplicate SoulSearch filter descriptor id: trait:PATIENCE',
            1,
            true) ~= nil)
    end)

    test.case('descriptor catalog: selected-filter search does not traverse enums', function()
        local attributes = soulsearch_env.load_attributes(repo_root)
        local search, descriptors, descriptor_df =
            soulsearch_env.load_search(repo_root, attributes)
        local catalog = descriptors.get_catalog()
        test.assert_true(catalog.by_id['skill:MINING'] ~= nil)

        local forbidden_enum = setmetatable({}, {
            __index=function()
                error('unexpected enum traversal after catalog construction')
            end,
        })
        descriptor_df.job_skill = forbidden_enum
        descriptor_df.physical_attribute_type = forbidden_enum
        descriptor_df.mental_attribute_type = forbidden_enum
        descriptor_df.personality_facet_type = forbidden_enum

        local results = search.apply({{
            unit={},
            unit_id=1,
            name='Miner',
            profession='Miner',
            traits={},
            mental_attributes={},
            physical_attributes={},
            skills={MINING=2},
        }}, {
            selected_filters={{id='skill:MINING', direction='high'}},
        })
        test.assert_equal(1, #results)
        test.assert_equal(1, results[1].matched_count)
    end)
end
