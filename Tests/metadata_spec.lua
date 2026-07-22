local soulsearch_env = require('support.soulsearch_env')

local function descriptor_ids(descriptor_list)
    local result = {}
    for _, descriptor in ipairs(descriptor_list) do
        table.insert(result, descriptor.id)
    end
    return result
end

local repo_root = require('support.repo_root')

describe('metadata', function()

    local df_enums = soulsearch_env.load_df_enums(repo_root)
    local skill_categories = soulsearch_env.load_skill_categories(repo_root)

    it('df enums: excludes NONE and orders sparse numeric values', function()
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
        assert.are.equal(2, #entries)
        assert.are.equal('BETA', entries[1].name)
        assert.are.equal(3, entries[1].value)
        assert.are.equal('ALPHA', entries[2].name)
        assert.are.equal(10, entries[2].value)

        local names = df_enums.names_by_value(enum)
        assert.are.equal('BETA', names[3])
        assert.are.equal('ALPHA', names[10])
        assert.is_nil(names[-1])
    end)

    it('skill taxonomy: preserves category order and aliases', function()
        assert.are.same(
            {'Labor', 'Combat', 'Social', 'Other Skills', 'Knowledge'},
            skill_categories.get_order())
        assert.are.equal('Labor', skill_categories.get_category('WOODCUTTING'))
        assert.are.equal('Labor', skill_categories.get_category('WOOD_CUTTING'))
        assert.are.equal('Combat', skill_categories.get_category('SWORD'))
        assert.are.equal('Social', skill_categories.get_category('PERSUASION'))
        assert.are.equal('Knowledge', skill_categories.get_category('WRITING'))
        assert.are.equal('Other Skills', skill_categories.get_category('SWIMMING'))
        assert.are.equal(186, #skill_categories.get_known_keys())
    end)

    it('skill taxonomy: reports fallback keys without printing', function()
        assert.are.equal('Other Skills', skill_categories.get_category('FUTURE_SKILL'))
        assert.is_falsy(skill_categories.is_known('FUTURE_SKILL'))
        assert.are.same(
            {'ANOTHER_FUTURE_SKILL', 'FUTURE_SKILL'},
            skill_categories.get_uncategorized({
                'MINING',
                'FUTURE_SKILL',
                'ANOTHER_FUTURE_SKILL',
            }))
    end)

    it('skill taxonomy: every fixture skill is explicit or fallback', function()
        local keys = {}
        for _, entry in ipairs(df_enums.entries(
                soulsearch_env.make_df_stub().job_skill)) do
            table.insert(keys, entry.name)
            assert.is_truthy(type(skill_categories.get_category(entry.name)) == 'string')
        end
        assert.are.same(
            {'UNLISTED_SKILL'},
            skill_categories.get_uncategorized(keys))
    end)

    it('descriptor catalog: caches one catalog with indexed IDs', function()
        local descriptors = soulsearch_env.load_descriptors(repo_root)
        local first = descriptors.get_catalog()
        local second = descriptors.get_catalog()
        assert.is_truthy(first == second)
        assert.are.equal(25, #first.flat)

        local seen = {}
        for _, descriptor in ipairs(first.flat) do
            assert.is_falsy(seen[descriptor.id], 'duplicate id: ' .. descriptor.id)
            seen[descriptor.id] = true
            assert.is_truthy(first.by_id[descriptor.id] == descriptor)
        end
    end)

    it('descriptor catalog: preserves group and flat ordering', function()
        local descriptors = soulsearch_env.load_descriptors(repo_root)
        local catalog = descriptors.get_catalog()
        assert.are.same({
            'unit_scope:citizens',
            'unit_scope:fort_residents',
            'unit_scope:livestock',
            'unit_scope:pets',
            'unit_scope:visitors',
            'unit_scope:wildlife',
        }, descriptor_ids(catalog.groups.unit_scopes))
        assert.are.same({
            'skill:MINING',
            'skill:PERSUASION',
            'skill:SWIMMING',
            'skill:SWORD',
            'skill:UNLISTED_SKILL',
            'skill:WRITING',
        }, descriptor_ids(catalog.groups.skills))
        assert.are.same({
            'physical:AGILITY',
            'physical:STRENGTH',
        }, descriptor_ids(catalog.groups.physical_attributes))
        assert.are.same({
            'mental:FOCUS',
            'mental:WILLPOWER',
        }, descriptor_ids(catalog.groups.mental_attributes))
        assert.are.same({
            'trait:BRAVERY',
            'trait:PATIENCE',
        }, descriptor_ids(catalog.groups.traits))
        assert.are.same({
            'race:group:HUMANOIDS',
            'race:group:TAMEABLE_ANIMALS',
            'race:group:WORK_ANIMALS',
            'race:group:DOMESTIC_ANIMALS',
            'race:group:WILD_ANIMALS',
            'race:group:MEGABEASTS',
            'race:group:VERMIN',
        }, descriptor_ids(catalog.groups.races))
        assert.are.same({
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
        assert.are.equal('Mining', catalog.by_id['skill:MINING'].label)
        assert.are.equal('Labor', catalog.by_id['skill:MINING'].category)
        assert.are.equal('Other Skills',
            catalog.by_id['skill:UNLISTED_SKILL'].category)
    end)

    it('descriptor catalog: scopes and races are candidates and stats are ranking descriptors', function()
        local descriptors = soulsearch_env.load_descriptors(repo_root)
        for _, descriptor in ipairs(descriptors.get_catalog().flat) do
            local expected = (descriptor.kind == 'race' or
                descriptor.kind == 'unit_scope') and 'candidate' or 'ranking'
            assert.are.equal(expected, descriptor.behavior)
        end
    end)

    it('descriptor catalog: rejects duplicate descriptor IDs', function()
        local duplicate_df = soulsearch_env.make_df_stub()
        duplicate_df.personality_facet_type = {
            [1]='PATIENCE',
            [2]='PATIENCE',
            PATIENCE=2,
        }
        local descriptors = soulsearch_env.load_descriptors(repo_root, duplicate_df)
        local ok, err = pcall(descriptors.get_catalog)
        assert.is_falsy(ok)
        assert.is_truthy(tostring(err):find(
            'duplicate SoulSearch filter descriptor id: trait:PATIENCE',
            1,
            true) ~= nil)
    end)

    it('descriptor catalog: selected-filter search does not traverse enums', function()
        local attributes = soulsearch_env.load_attributes(repo_root)
        local search, descriptors, descriptor_df =
            soulsearch_env.load_search(repo_root, attributes)
        local catalog = descriptors.get_catalog()
        assert.is_truthy(catalog.by_id['skill:MINING'] ~= nil)

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
        assert.are.equal(1, #results)
        assert.are.equal(1, results[1].matched_count)
    end)

end)
