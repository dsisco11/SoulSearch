local soulsearch_env = require('support.soulsearch_env')

local function raw(id, name, flags)
    return {
        creature_id=id,
        name={[0]=name},
        caste={[0]={flags=flags or {}}},
    }
end

local function make_df(raws)
    return {global={world={raws={creatures={all=raws}}}}}
end

local function ids(descriptors)
    local result = {}
    for _, descriptor in ipairs(descriptors) do
        table.insert(result, descriptor.id)
    end
    return result
end

local repo_root = require('support.repo_root')

describe('race catalog', function()

    it('race catalog: compounds precede stable sorted individual IDs', function()
        local catalog = soulsearch_env.load_race_catalog(repo_root, make_df({
            raw('ZEBRA', 'zebra'),
            raw('DOG', 'dog'),
            raw('ALPACA', 'alpaca'),
        }))
        assert.are.same({
            'race:group:HUMANOIDS',
            'race:group:TAMEABLE_ANIMALS',
            'race:group:WORK_ANIMALS',
            'race:group:DOMESTIC_ANIMALS',
            'race:group:WILD_ANIMALS',
            'race:group:MEGABEASTS',
            'race:group:VERMIN',
            'race:raw:ALPACA',
            'race:raw:DOG',
            'race:raw:ZEBRA',
        }, ids(catalog.get_descriptors()))
    end)

    it('race catalog: compound predicates use documented caste flags', function()
        local raws = {
            raw('DWARF', 'dwarf', {CAN_LEARN=true, CAN_SPEAK=true}),
            raw('DOG', 'dog', {TRAINABLE_HUNTING=true}),
            raw('CAT', 'cat', {PET=true}),
            raw('COW', 'cow', {COMMON_DOMESTIC=true, PACK_ANIMAL=true}),
            raw('DEER', 'deer', {NATURAL=true}),
            raw('DRAGON', 'dragon', {MEGABEAST=true}),
            raw('RAT', 'rat', {VERMIN_MICRO=true}),
        }
        local catalog = soulsearch_env.load_race_catalog(repo_root, make_df(raws))
        local by_id = {}
        for _, descriptor in ipairs(catalog.get_descriptors()) do
            by_id[descriptor.id] = descriptor
        end
        local cases = {
            {'HUMANOIDS', 1}, {'WORK_ANIMALS', 2},
            {'TAMEABLE_ANIMALS', 3}, {'DOMESTIC_ANIMALS', 4},
            {'WILD_ANIMALS', 5}, {'MEGABEASTS', 6}, {'VERMIN', 7},
        }
        for _, case in ipairs(cases) do
            assert.is_truthy(catalog.matches_unit(
                by_id['race:group:' .. case[1]], {race=case[2], caste=0}))
        end
        assert.is_falsy(catalog.matches_unit(
            by_id['race:group:WILD_ANIMALS'], {race=1, caste=0}))
        assert.is_falsy(catalog.matches_unit(
            by_id['race:group:TAMEABLE_ANIMALS'], {race=2, caste=0}))
        assert.is_falsy(catalog.matches_unit(
            by_id['race:group:WORK_ANIMALS'], {race=3, caste=0}))
        assert.is_truthy(catalog.matches_unit(
            by_id['race:raw:DOG'], {race=2, caste=0}))
    end)

    it('race catalog: raw-vector order does not affect individual IDs', function()
        local first = soulsearch_env.load_race_catalog(repo_root, make_df({
            raw('DOG', 'dog'), raw('DWARF', 'dwarf'),
        }))
        local second = soulsearch_env.load_race_catalog(repo_root, make_df({
            raw('DWARF', 'dwarf'), raw('DOG', 'dog'),
        }))
        assert.are.same(ids(first.get_descriptors()), ids(second.get_descriptors()))
        local dog
        for _, descriptor in ipairs(second.get_descriptors()) do
            if descriptor.id == 'race:raw:DOG' then dog = descriptor end
        end
        assert.is_truthy(second.matches_unit(dog, {race=2, caste=0}))
    end)

    it('race catalog: missing raws and caste data never match', function()
        local catalog = soulsearch_env.load_race_catalog(repo_root, make_df({
            {}, raw('DOG', 'dog', {PET=true}), {creature_id='MISSING_NAME'},
        }))
        local descriptors = catalog.get_descriptors()
        assert.are.equal(9, #descriptors)
        assert.is_falsy(catalog.matches_unit(descriptors[1], {race=2, caste=99}))
        assert.is_falsy(catalog.matches_unit(descriptors[1], {race=99, caste=0}))
    end)

    it('race catalog: duplicate creature IDs fail clearly and cache resets', function()
        local catalog = soulsearch_env.load_race_catalog(repo_root, make_df({
            raw('DOG', 'dog'), raw('DOG', 'other dog'),
        }))
        local ok, err = pcall(catalog.get_descriptors)
        assert.is_falsy(ok)
        assert.is_truthy(tostring(err):find(
            'duplicate SoulSearch creature ID: DOG', 1, true) ~= nil)

        catalog = soulsearch_env.load_race_catalog(repo_root, make_df({raw('DOG', 'dog')}))
        local first = catalog.get_descriptors()
        assert.is_truthy(first == catalog.get_descriptors())
        catalog.reset_cache()
        assert.is_falsy(first == catalog.get_descriptors())
    end)

end)
