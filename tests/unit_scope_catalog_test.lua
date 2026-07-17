local soulsearch_env = require('support.soulsearch_env')

local function ids(descriptors)
    local result = {}
    for _, descriptor in ipairs(descriptors) do table.insert(result, descriptor.id) end
    return result
end

return function(test, repo_root)
    test.case('unit scope catalog: stable candidate descriptors have player-facing labels', function()
        local catalog = soulsearch_env.load_unit_scope_catalog(repo_root, {units={
            isCitizen=function() return false end, isResident=function() return false end,
            isFortControlled=function() return false end, isVisitor=function() return false end,
            isMerchant=function() return false end, isDiplomat=function() return false end,
            isWildlife=function() return false end,
            getCasteRaw=function() return {flags={}} end,
            isPet=function() return false end,
        }})
        local descriptors = catalog.get_descriptors()
        test.assert_sequence({'unit_scope:citizens', 'unit_scope:fort_residents',
            'unit_scope:livestock', 'unit_scope:pets', 'unit_scope:visitors',
            'unit_scope:wildlife'}, ids(descriptors))
        test.assert_sequence({'Citizens', 'Residents', 'Livestock', 'Pets', 'Visitors', 'Wildlife'}, {
            descriptors[1].label, descriptors[2].label, descriptors[3].label,
            descriptors[4].label, descriptors[5].label, descriptors[6].label,
        })
        for _, descriptor in ipairs(descriptors) do
            test.assert_equal('unit_scope', descriptor.kind)
            test.assert_equal('candidate', descriptor.behavior)
        end
    end)

    test.case('unit scope catalog: preserves existing membership predicates', function()
        local calls = {}
        local units = {
            isCitizen=function(unit, include_insane)
                calls.citizen = include_insane
                return unit.citizen
            end,
            isResident=function(unit, include_insane)
                calls.resident = include_insane
                return unit.resident
            end,
            isFortControlled=function(unit) return unit.controlled end,
            isVisitor=function(unit) return unit.visitor end,
            isMerchant=function(unit) return unit.merchant end,
            isDiplomat=function(unit) return unit.diplomat end,
            isWildlife=function(unit) return unit.wildlife end,
            getCasteRaw=function(unit) return unit.caste end,
            isPet=function(unit) return unit.pet end,
        }
        local catalog = soulsearch_env.load_unit_scope_catalog(repo_root, {units=units})
        local descriptors = catalog.get_descriptors()
        local unit = {citizen=true, resident=true, controlled=true, merchant=true, wildlife=true,
            caste={flags={PET=true}}, pet=false}
        for _, descriptor in ipairs(descriptors) do
            if descriptor.id ~= 'unit_scope:pets' then
                test.assert_true(catalog.matches_unit(descriptor, unit))
            end
        end
        local pets
        for _, descriptor in ipairs(descriptors) do
            if descriptor.id == 'unit_scope:pets' then pets = descriptor end
        end
        test.assert_false(catalog.matches_unit(pets, unit))
        test.assert_true(calls.citizen)
        test.assert_true(calls.resident)
        test.assert_false(catalog.matches_unit({id='unit_scope:unknown'}, unit))
    end)

    test.case('unit scope catalog: livestock requires fort control and a livestock caste', function()
        local catalog = soulsearch_env.load_unit_scope_catalog(repo_root, {units={
            isCitizen=function() return false end,
            isResident=function() return false end,
            isFortControlled=function(unit) return unit.controlled end,
            isVisitor=function() return false end,
            isMerchant=function() return false end,
            isDiplomat=function() return false end,
            isWildlife=function() return false end,
            getCasteRaw=function(unit) return unit.caste end,
            isPet=function(unit) return unit.pet end,
        }})
        local livestock
        for _, descriptor in ipairs(catalog.get_descriptors()) do
            if descriptor.id == 'unit_scope:livestock' then livestock = descriptor end
        end
        test.assert_true(catalog.matches_unit(livestock, {controlled=true, caste={flags={PET=true}}}))
        test.assert_true(catalog.matches_unit(livestock, {controlled=true, caste={flags={PET_EXOTIC=true}}}))
        test.assert_false(catalog.matches_unit(livestock,
            {controlled=true, pet=true, caste={flags={PET=true}}}))
        test.assert_false(catalog.matches_unit(livestock, {controlled=false, caste={flags={PET=true}}}))
        test.assert_false(catalog.matches_unit(livestock, {controlled=true, caste={flags={}}}))
    end)

    test.case('unit scope catalog: pets use the DFHack pet predicate', function()
        local catalog = soulsearch_env.load_unit_scope_catalog(repo_root, {units={
            isCitizen=function() return false end,
            isResident=function() return false end,
            isFortControlled=function() return true end,
            isVisitor=function() return false end,
            isMerchant=function() return false end,
            isDiplomat=function() return false end,
            isWildlife=function() return false end,
            getCasteRaw=function() return {flags={}} end,
            isPet=function(unit) return unit.pet end,
        }})
        local pets
        for _, descriptor in ipairs(catalog.get_descriptors()) do
            if descriptor.id == 'unit_scope:pets' then pets = descriptor end
        end
        test.assert_true(catalog.matches_unit(pets, {pet=true}))
        test.assert_false(catalog.matches_unit(pets, {pet=false}))
    end)
end
