local soulsearch_env = require('support.soulsearch_env')

local function descriptor_ids(descriptor_list)
    local result = {}
    for _, descriptor in ipairs(descriptor_list) do
        table.insert(result, descriptor.id)
    end
    return result
end

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local df_enums = soulsearch_env.load_df_enums(repo_root)
    local skill_categories = soulsearch_env.load_skill_categories(repo_root)

    add_test('df enums: excludes NONE and orders sparse numeric values', function()
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
        luaunit.assertIs(2, #entries)
        luaunit.assertIs('BETA', entries[1].name)
        luaunit.assertIs(3, entries[1].value)
        luaunit.assertIs('ALPHA', entries[2].name)
        luaunit.assertIs(10, entries[2].value)

        local names = df_enums.names_by_value(enum)
        luaunit.assertIs('BETA', names[3])
        luaunit.assertIs('ALPHA', names[10])
        luaunit.assertNil(names[-1])
    end)

    add_test('skill taxonomy: preserves category order and aliases', function()
        luaunit.assertEquals(
            {'Labor', 'Combat', 'Social', 'Other Skills', 'Knowledge'},
            skill_categories.get_order())
        luaunit.assertIs('Labor', skill_categories.get_category('WOODCUTTING'))
        luaunit.assertIs('Labor', skill_categories.get_category('WOOD_CUTTING'))
        luaunit.assertIs('Combat', skill_categories.get_category('SWORD'))
        luaunit.assertIs('Social', skill_categories.get_category('PERSUASION'))
        luaunit.assertIs('Knowledge', skill_categories.get_category('WRITING'))
        luaunit.assertIs('Other Skills', skill_categories.get_category('SWIMMING'))
        luaunit.assertIs(186, #skill_categories.get_known_keys())
    end)

    add_test('skill taxonomy: reports fallback keys without printing', function()
        luaunit.assertIs('Other Skills', skill_categories.get_category('FUTURE_SKILL'))
        luaunit.assertEvalToFalse(skill_categories.is_known('FUTURE_SKILL'))
        luaunit.assertEquals(
            {'ANOTHER_FUTURE_SKILL', 'FUTURE_SKILL'},
            skill_categories.get_uncategorized({
                'MINING',
                'FUTURE_SKILL',
                'ANOTHER_FUTURE_SKILL',
            }))
    end)

    add_test('skill taxonomy: every fixture skill is explicit or fallback', function()
        local keys = {}
        for _, entry in ipairs(df_enums.entries(
                soulsearch_env.make_df_stub().job_skill)) do
            table.insert(keys, entry.name)
            luaunit.assertEvalToTrue(type(skill_categories.get_category(entry.name)) == 'string')
        end
        luaunit.assertEquals(
            {'UNLISTED_SKILL'},
            skill_categories.get_uncategorized(keys))
    end)

    add_test('descriptor catalog: caches one catalog with indexed IDs', function()
        local descriptors = soulsearch_env.load_descriptors(repo_root)
        local first = descriptors.get_catalog()
        local second = descriptors.get_catalog()
        luaunit.assertEvalToTrue(first == second)
        luaunit.assertIs(25, #first.flat)

        local seen = {}
        for _, descriptor in ipairs(first.flat) do
            luaunit.assertEvalToFalse(seen[descriptor.id], 'duplicate id: ' .. descriptor.id)
            seen[descriptor.id] = true
            luaunit.assertEvalToTrue(first.by_id[descriptor.id] == descriptor)
        end
    end)

    add_test('descriptor catalog: preserves group and flat ordering', function()
        local descriptors = soulsearch_env.load_descriptors(repo_root)
        local catalog = descriptors.get_catalog()
        luaunit.assertEquals({
            'unit_scope:citizens',
            'unit_scope:fort_residents',
            'unit_scope:livestock',
            'unit_scope:pets',
            'unit_scope:visitors',
            'unit_scope:wildlife',
        }, descriptor_ids(catalog.groups.unit_scopes))
        luaunit.assertEquals({
            'skill:MINING',
            'skill:PERSUASION',
            'skill:SWIMMING',
            'skill:SWORD',
            'skill:UNLISTED_SKILL',
            'skill:WRITING',
        }, descriptor_ids(catalog.groups.skills))
        luaunit.assertEquals({
            'physical:AGILITY',
            'physical:STRENGTH',
        }, descriptor_ids(catalog.groups.physical_attributes))
        luaunit.assertEquals({
            'mental:FOCUS',
            'mental:WILLPOWER',
        }, descriptor_ids(catalog.groups.mental_attributes))
        luaunit.assertEquals({
            'trait:BRAVERY',
            'trait:PATIENCE',
        }, descriptor_ids(catalog.groups.traits))
        luaunit.assertEquals({
            'race:group:HUMANOIDS',
            'race:group:TAMEABLE_ANIMALS',
            'race:group:WORK_ANIMALS',
            'race:group:DOMESTIC_ANIMALS',
            'race:group:WILD_ANIMALS',
            'race:group:MEGABEASTS',
            'race:group:VERMIN',
        }, descriptor_ids(catalog.groups.races))
        luaunit.assertEquals({
            'skill:MINING',
            'skill:PERSUASION',
            'skill:SWIMMING',
            'skill:SWORD',
            'skill:UNLISTED_SKILL',
            'skill:WRITING',
            'physical:AGILITY',
            'physical:STRENGTH',
            'mental:FOCUS',
            'mental:WILLPOWER',
            'trait:BRAVERY',
            'trait:PATIENCE',
            'unit_scope:citizens',
            'unit_scope:fort_residents',
            'unit_scope:livestock',
            'unit_scope:pets',
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
        luaunit.assertIs('Mining', catalog.by_id['skill:MINING'].label)
        luaunit.assertIs('Labor', catalog.by_id['skill:MINING'].category)
        luaunit.assertIs('Other Skills',
            catalog.by_id['skill:UNLISTED_SKILL'].category)
    end)

    add_test('descriptor catalog: scopes and races are candidates and stats are ranking descriptors', function()
        local descriptors = soulsearch_env.load_descriptors(repo_root)
        for _, descriptor in ipairs(descriptors.get_catalog().flat) do
            local expected = (descriptor.kind == 'race' or
                descriptor.kind == 'unit_scope') and 'candidate' or 'ranking'
            luaunit.assertIs(expected, descriptor.behavior)
        end
    end)

    add_test('descriptor catalog: rejects duplicate descriptor IDs', function()
        local duplicate_df = soulsearch_env.make_df_stub()
        duplicate_df.personality_facet_type = {
            [1]='PATIENCE',
            [2]='PATIENCE',
            PATIENCE=2,
        }
        local descriptors = soulsearch_env.load_descriptors(repo_root, duplicate_df)
        local ok, err = pcall(descriptors.get_catalog)
        luaunit.assertEvalToFalse(ok)
        luaunit.assertEvalToTrue(tostring(err):find(
            'duplicate SoulSearch filter descriptor id: trait:PATIENCE',
            1,
            true) ~= nil)
    end)

    add_test('descriptor catalog: selected-filter search does not traverse enums', function()
        local attributes = soulsearch_env.load_attributes(repo_root)
        local search, descriptors, descriptor_df =
            soulsearch_env.load_search(repo_root, attributes)
        local catalog = descriptors.get_catalog()
        luaunit.assertEvalToTrue(catalog.by_id['skill:MINING'] ~= nil)

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
        luaunit.assertIs(1, #results)
        luaunit.assertIs(1, results[1].matched_count)
    end)

return native_tests
