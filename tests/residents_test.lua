local soulsearch_env = require('support.soulsearch_env')

local function make_snapshot(overrides)
    local snapshot = {
        unit={id=1},
        unit_id=1,
        traits={},
        mental_attributes={},
        physical_attributes={},
    }
    for key, value in pairs(overrides or {}) do snapshot[key] = value end
    return snapshot
end

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('residents: complete row transformation preserves current rules', function()
        local residents = soulsearch_env.load_residents(repo_root)
        local snapshot = make_snapshot{
            unit={id=7},
            unit_id=7,
            native_name='Urist',
            english_name='Strongpick',
            profession='Miner',
            traits={PATIENCE=61},
            mental_attributes={FOCUS=900},
            physical_attributes={STRENGTH=1250},
            skills={{id=0, rating=2, experience=350}, {id=999, rating=20}},
        }
        local row = residents.build_resident_row(snapshot)
        luaunit.assertIs(7, row.unit_id)
        luaunit.assertIs('Urist "Strongpick"', row.name)
        luaunit.assertIs('Miner', row.profession)
        luaunit.assertIs(61, row.traits.PATIENCE)
        luaunit.assertIs(900, row.mental_attributes.FOCUS)
        luaunit.assertIs(1250, row.physical_attributes.STRENGTH)
        -- Supported DFHack next-level cost is 500 + 100 * rating: 350/700.
        luaunit.assertAlmostEquals(3.5, row.skills.MINING)
        luaunit.assertNil(row.skills[999])
    end)

    add_test('residents: missing soul personality attributes and names fall back', function()
        local residents = soulsearch_env.load_residents(repo_root)
        local row = residents.build_resident_row(make_snapshot{
            unit={id=9}, unit_id=9,
        })
        luaunit.assertIs('Unit #9', row.name)
        luaunit.assertIs('', row.profession)
        luaunit.assertIs(0, #row.skills)
        luaunit.assertNil(next(row.traits))
        luaunit.assertNil(next(row.mental_attributes))
        luaunit.assertNil(next(row.physical_attributes))
    end)

    add_test('residents: one available translation is retained', function()
        local residents = soulsearch_env.load_residents(repo_root)
        local row = residents.build_resident_row(make_snapshot{
            unit={id=10}, unit_id=10, english_name='The Smith',
        })
        luaunit.assertIs('The Smith', row.name)
    end)

    add_test('residents: skill-name cache reuses and explicitly resets', function()
        local real_enums = soulsearch_env.load_df_enums(repo_root)
        local calls = 0
        local counted_enums = {
            entries=real_enums.entries,
            names_by_value=function(enum)
                calls = calls + 1
                return real_enums.names_by_value(enum)
            end,
        }
        local residents = soulsearch_env.load_residents(repo_root, counted_enums)
        local snapshot = make_snapshot{
            skills={{id=0, rating=0, experience=0}},
        }
        residents.build_resident_row(snapshot)
        residents.build_resident_row(snapshot)
        luaunit.assertIs(1, calls)
        residents.reset_cache()
        residents.build_resident_row(snapshot)
        luaunit.assertIs(2, calls)
    end)

    add_test('resident collection: unnamed units use the game-readable name', function()
        local unit = {id=12, status={}}
        local dfhack_stub = {
            isMapLoaded=function() return true end,
            world={isFortressMode=function() return true end},
            units={
                getCitizens=function() return {unit} end,
                getVisibleName=function() return nil end,
                getReadableName=function() return 'Stray horse (Tame)' end,
                getProfessionName=function() return nil end,
                getMentalAttrValue=function() return nil end,
                getPhysicalAttrValue=function() return nil end,
            },
            translation={translateName=function() error('unexpected translation') end},
        }
        local residents = soulsearch_env.load_residents(repo_root, nil, dfhack_stub)
        local rows = residents.collect_residents()
        luaunit.assertIs(1, #rows)
        luaunit.assertIs('Stray horse (Tame)', rows[1].name)
        luaunit.assertIs('', rows[1].profession)
        luaunit.assertNil(next(rows[1].traits))

        dfhack_stub.units.getCitizens = function() error('citizen read failed') end
        local ok, err = pcall(residents.collect_residents)
        luaunit.assertEvalToFalse(ok)
        luaunit.assertEvalToTrue(tostring(err):find('citizen read failed', 1, true) ~= nil)
    end)

    add_test('resident collection: uses the citizen source and preserves its order', function()
        local citizen_args
        local first = {id=30, status={}}
        local second = {id=10, status={}}
        local dfhack_stub = {
            isMapLoaded=function() return true end,
            world={isFortressMode=function() return true end},
            units={
                getCitizens=function(...)
                    citizen_args = {...}
                    return {first, second}
                end,
                getVisibleName=function() return nil end,
                getReadableName=function(unit) return unit.id == 10 and 'Stray dog (Tame)' or 'Stray cat (Tame)' end,
                getProfessionName=function() return nil end,
                getMentalAttrValue=function() return nil end,
                getPhysicalAttrValue=function() return nil end,
            },
            translation={translateName=function() return nil end},
        }
        local residents = soulsearch_env.load_residents(repo_root, nil, dfhack_stub)
        local rows = residents.collect_residents()
        luaunit.assertEquals({false, true}, citizen_args)
        luaunit.assertEquals({30, 10}, {rows[1].unit_id, rows[2].unit_id})
        luaunit.assertEquals({'Stray cat (Tame)', 'Stray dog (Tame)'},
            {rows[1].name, rows[2].name})
    end)

    add_test('resident collection: snapshots only provider candidates and tolerates animals', function()
        local citizen = {id=30, status={}}
        local animal = {id=10, status={}}
        local dfhack_stub = {
            units={
                getVisibleName=function() return nil end,
                getReadableName=function(unit)
                    return unit.id == 10 and 'War dog' or 'Stray cat (Tame)'
                end,
                getProfessionName=function() return nil end,
                getMentalAttrValue=function() return nil end,
                getPhysicalAttrValue=function() return nil end,
            },
            translation={translateName=function() return nil end},
        }
        local residents = soulsearch_env.load_residents(repo_root, nil, dfhack_stub)
        local rows = residents.collect_from_provider{
            get_units=function() return {animal, citizen} end,
        }
        luaunit.assertEquals({10, 30}, {rows[1].unit_id, rows[2].unit_id})
        luaunit.assertIs('War dog', rows[1].name)
        luaunit.assertIs('', rows[1].profession)
        luaunit.assertNil(next(rows[1].traits))

        local missing, err = residents.collect_from_provider{
            get_units=function() return nil, 'candidate source unavailable' end,
        }
        luaunit.assertNil(missing)
        luaunit.assertIs('candidate source unavailable', err)
    end)

    add_test('resident collection: one-unit path preserves row semantics', function()
        local unit = {id=42, status={}}
        local dfhack_stub = {
            units={
                getVisibleName=function() return nil end,
                getReadableName=function() return 'Stray yak (Tame)' end,
                getProfessionName=function() return nil end,
                getMentalAttrValue=function() return nil end,
                getPhysicalAttrValue=function() return nil end,
            },
            translation={translateName=function() return nil end},
        }
        local residents = soulsearch_env.load_residents(repo_root, nil, dfhack_stub)
        local row = residents.collect_units({unit})[1]
        luaunit.assertIs(unit, row.unit)
        luaunit.assertIs(42, row.unit_id)
        luaunit.assertIs('Stray yak (Tame)', row.name)
        luaunit.assertIs('', row.profession)
        luaunit.assertNil(next(row.traits))
        luaunit.assertNil(next(row.mental_attributes))
        luaunit.assertNil(next(row.physical_attributes))
    end)

    add_test('resident collection: collect_unit validates safely and preserves parity', function()
        local unit = {id=42, status={}}
        local printed = 0
        local dfhack_stub = {
            isMapLoaded=function() return true end,
            world={isFortressMode=function() return true end},
            printerr=function() printed = printed + 1 end,
            units={
                getVisibleName=function() return nil end,
                getReadableName=function() return 'Stray yak (Tame)' end,
                getProfessionName=function() return nil end,
                getMentalAttrValue=function() return nil end,
                getPhysicalAttrValue=function() return nil end,
            },
            translation={translateName=function() return nil end},
        }
        local residents = soulsearch_env.load_residents(repo_root, nil, dfhack_stub)
        local expected = residents.collect_units({unit})[1]
        local row, err = residents.collect_unit(unit)
        luaunit.assertNil(err)
        luaunit.assertIs(expected.unit_id, row.unit_id)
        luaunit.assertIs(expected.name, row.name)
        local invalid, invalid_err = residents.collect_unit({id=-1})
        luaunit.assertNil(invalid)
        luaunit.assertIs('SoulSearch requires a valid unit.', invalid_err)
        local missing, missing_err = residents.collect_unit(nil)
        luaunit.assertNil(missing)
        luaunit.assertIs('SoulSearch requires a valid unit.', missing_err)
        local raised, raised_err = residents.collect_unit(setmetatable({}, {
            __index=function() error('stale') end,
        }))
        luaunit.assertNil(raised)
        luaunit.assertIs('SoulSearch requires a valid unit.', raised_err)
        luaunit.assertIs(0, printed)

        dfhack_stub.isMapLoaded=function() return false end
        local unavailable, unavailable_err = residents.collect_unit(nil)
        luaunit.assertNil(unavailable)
        luaunit.assertIs('SoulSearch requires a loaded fortress map.', unavailable_err)
    end)

return native_tests
