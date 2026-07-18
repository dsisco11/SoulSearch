local soulsearch_env = require('support.soulsearch_env')

local function raw(id, flags)
    return {creature_id=id, name={[0]=id:lower()}, caste={[0]={flags=flags}}}
end

local function ids(rows)
    local result = {}
    for _, row in ipairs(rows) do table.insert(result, row.unit_id) end
    return result
end

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local constants = soulsearch_env.load_filter_constants(repo_root).FILTER_CONSTANTS
    local direction = constants.direction
    local scope = constants.unit_scope
    local race = constants.race

    local citizen_dwarf = {id=1, race=1, caste=0, status={}}
    local resident_dwarf = {id=2, race=1, caste=0, status={}}
    local pet_dog = {id=3, race=2, caste=0, status={}}
    local visitor_dwarf = {id=4, race=1, caste=0, status={}}
    local visitor_dog = {id=5, race=2, caste=0, status={}}
    local inactive_dwarf = {id=6, race=1, caste=0, status={}}
    local wild_dog = {id=7, race=2, caste=0, status={}}
    local livestock_dog = {id=8, race=2, caste=0, status={}}
    local active = {[1]=true, [2]=true, [3]=true, [4]=true, [5]=true, [7]=true, [8]=true}
    local df = soulsearch_env.make_df_stub()
    df.global.world.units = {active={
        citizen_dwarf, resident_dwarf, pet_dog, visitor_dwarf,
        visitor_dog, inactive_dwarf, wild_dog, livestock_dog, citizen_dwarf,
    }}
    df.global.world.raws.creatures.all = {
        raw('DWARF', {CAN_LEARN=true, CAN_SPEAK=true}),
        raw('DOG', {PET=true}),
    }
    local dfhack = {
        isMapLoaded=function() return true end,
        world={isFortressMode=function() return true end},
        units={
            isActive=function(unit) return active[unit.id] or false end,
            isCitizen=function(unit) return unit == citizen_dwarf end,
            isResident=function(unit) return unit == resident_dwarf end,
            isFortControlled=function(unit)
                return unit == citizen_dwarf or unit == pet_dog or unit == livestock_dog
            end,
            getCasteRaw=function(unit)
                return {flags=(unit == pet_dog or unit == livestock_dog) and {PET=true} or {}}
            end,
            isPet=function(unit) return unit == pet_dog end,
            isVisitor=function(unit) return unit == visitor_dwarf or unit == visitor_dog end,
            isMerchant=function() return false end,
            isDiplomat=function() return false end,
            isWildlife=function(unit) return unit == wild_dog end,
            getVisibleName=function() return nil end,
            getReadableName=function(unit) return 'Unit ' .. unit.id end,
            getProfessionName=function() return nil end,
            getMentalAttrValue=function() return nil end,
            getPhysicalAttrValue=function() return nil end,
        },
        translation={translateName=function() return nil end},
    }

    local function filter(id, value)
        return {id=id, direction=value or direction.HIGH}
    end
    local function scope_id(key) return scope.id_prefix .. key end
    local function race_group_id(key) return race.group_id_prefix .. key end
    local function collect(selected_filters)
        local provider = soulsearch_env.load_active_unit_provider(repo_root, df, dfhack).new()
        provider = soulsearch_env.load_unit_scope_filter_provider(repo_root, dfhack).new(
            provider, selected_filters)
        provider = soulsearch_env.load_race_filter_provider(repo_root, df).new(
            provider, selected_filters)
        return assert(soulsearch_env.load_residents(repo_root, nil, dfhack)
            .collect_from_provider(provider))
    end

    add_test('candidate pipeline: end-to-end scope and race matrix', function()
        local cases = {
            {
                name='no scope or race filters returns every active unit',
                filters={}, expected={1, 2, 3, 4, 5, 7, 8},
            },
            {
                name='Humanoids returns every active humanoid',
                filters={filter(race_group_id(race.group.HUMANOIDS))}, expected={1, 2, 4},
            },
            {
                name='Residents plus Humanoids intersects both families',
                filters={filter(scope_id(scope.FORT_RESIDENTS)),
                    filter(race_group_id(race.group.HUMANOIDS))}, expected={2},
            },
            {
                name='Residents or Visitors plus Humanoids broadens only scopes',
                filters={filter(scope_id(scope.FORT_RESIDENTS)), filter(scope_id(scope.VISITORS)),
                    filter(race_group_id(race.group.HUMANOIDS))}, expected={2, 4},
            },
            {
                name='Residents except Citizens excludes the matching scope',
                filters={filter(scope_id(scope.FORT_RESIDENTS)),
                    filter(scope_id(scope.CITIZENS), direction.LOW)}, expected={2},
            },
            {
                name='Wildlife selects active wild animals',
                filters={filter(scope_id(scope.WILDLIFE))}, expected={7},
            },
            {
                name='Livestock selects fort-controlled pet castes',
                filters={filter(scope_id(scope.LIVESTOCK))}, expected={8},
            },
            {
                name='Pets select units marked as pets',
                filters={filter(scope_id(scope.PETS))}, expected={3},
            },
            {
                name='negative-only Visitors returns every active non-visitor',
                filters={filter(scope_id(scope.VISITORS), direction.LOW)}, expected={1, 2, 3, 7, 8},
            },
        }
        for _, case in ipairs(cases) do
            luaunit.assertEquals(case.expected, ids(collect(case.filters)), case.name)
        end
    end)

    add_test('candidate pipeline: ranking receives only the candidate-filtered rows', function()
        local rows = collect({filter(scope_id(scope.CITIZENS)),
            filter(race_group_id(race.group.HUMANOIDS))})
        local ranked = soulsearch_env.load_search(repo_root,
            soulsearch_env.load_attributes(repo_root)).apply(rows, {
            selected_filters={{id='skill:MINING', direction=direction.HIGH}},
        })
        luaunit.assertEquals({1}, ids(ranked))
    end)

return native_tests
