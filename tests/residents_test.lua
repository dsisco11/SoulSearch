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

return function(test, repo_root)
    test.case('residents: complete row transformation preserves current rules', function()
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
        test.assert_equal(7, row.unit_id)
        test.assert_equal('Urist "Strongpick"', row.name)
        test.assert_equal('Miner', row.profession)
        test.assert_equal(61, row.traits.PATIENCE)
        test.assert_equal(900, row.mental_attributes.FOCUS)
        test.assert_equal(1250, row.physical_attributes.STRENGTH)
        -- Supported DFHack next-level cost is 500 + 100 * rating: 350/700.
        test.assert_near(3.5, row.skills.MINING)
        test.assert_nil(row.skills[999])
    end)

    test.case('residents: missing soul personality attributes and names fall back', function()
        local residents = soulsearch_env.load_residents(repo_root)
        local row = residents.build_resident_row(make_snapshot{
            unit={id=9}, unit_id=9,
        })
        test.assert_equal('Unit #9', row.name)
        test.assert_equal('', row.profession)
        test.assert_equal(0, #row.skills)
        test.assert_nil(next(row.traits))
        test.assert_nil(next(row.mental_attributes))
        test.assert_nil(next(row.physical_attributes))
    end)

    test.case('residents: one available translation is retained', function()
        local residents = soulsearch_env.load_residents(repo_root)
        local row = residents.build_resident_row(make_snapshot{
            unit={id=10}, unit_id=10, english_name='The Smith',
        })
        test.assert_equal('The Smith', row.name)
    end)

    test.case('residents: skill-name cache reuses and explicitly resets', function()
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
        test.assert_equal(1, calls)
        residents.reset_cache()
        residents.build_resident_row(snapshot)
        test.assert_equal(2, calls)
    end)

    test.case('resident collection: optional data falls back and API errors surface', function()
        local unit = {id=12, status={}}
        local dfhack_stub = {
            isMapLoaded=function() return true end,
            world={isFortressMode=function() return true end},
            units={
                getCitizens=function() return {unit} end,
                getVisibleName=function() return nil end,
                getProfessionName=function() return nil end,
                getMentalAttrValue=function() return nil end,
                getPhysicalAttrValue=function() return nil end,
            },
            translation={translateName=function() error('unexpected translation') end},
        }
        local residents = soulsearch_env.load_residents(repo_root, nil, dfhack_stub)
        local rows = residents.collect_residents()
        test.assert_equal(1, #rows)
        test.assert_equal('Unit #12', rows[1].name)
        test.assert_equal('', rows[1].profession)
        test.assert_nil(next(rows[1].traits))

        dfhack_stub.units.getCitizens = function() error('citizen read failed') end
        local ok, err = pcall(residents.collect_residents)
        test.assert_false(ok)
        test.assert_true(tostring(err):find('citizen read failed', 1, true) ~= nil)
    end)

    test.case('resident collection: uses the citizen source and preserves its order', function()
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
                getProfessionName=function() return nil end,
                getMentalAttrValue=function() return nil end,
                getPhysicalAttrValue=function() return nil end,
            },
            translation={translateName=function() return nil end},
        }
        local residents = soulsearch_env.load_residents(repo_root, nil, dfhack_stub)
        local rows = residents.collect_residents()
        test.assert_sequence({false, true}, citizen_args)
        test.assert_sequence({30, 10}, {rows[1].unit_id, rows[2].unit_id})
    end)

    test.case('resident collection: snapshots only provider candidates and tolerates animals', function()
        local citizen = {id=30, status={}}
        local animal = {id=10, status={}}
        local dfhack_stub = {
            units={
                getVisibleName=function() return nil end,
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
        test.assert_sequence({10, 30}, {rows[1].unit_id, rows[2].unit_id})
        test.assert_equal('Unit #10', rows[1].name)
        test.assert_equal('', rows[1].profession)
        test.assert_nil(next(rows[1].traits))

        local missing, err = residents.collect_from_provider{
            get_units=function() return nil, 'candidate source unavailable' end,
        }
        test.assert_nil(missing)
        test.assert_equal('candidate source unavailable', err)
    end)
end
