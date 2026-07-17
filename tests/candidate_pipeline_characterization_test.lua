local soulsearch_env = require('support.soulsearch_env')

local function raw(id, flags)
    return {creature_id=id, name={[0]=id:lower()}, caste={[0]={flags=flags}}}
end

return function(test, repo_root)
    test.case('candidate pipeline: unit scope and race families intersect before row collection', function()
        local citizen_dwarf = {id=1, race=1, caste=0, status={}}
        local citizen_dog = {id=2, race=2, caste=0, status={}}
        local visitor_dwarf = {id=3, race=1, caste=0, status={}}
        local inactive_dwarf = {id=4, race=1, caste=0, status={}}
        local active = {[1]=true, [2]=true, [3]=true}
        local df = soulsearch_env.make_df_stub()
        df.global.world.units = {active={
            citizen_dwarf, citizen_dog, visitor_dwarf, inactive_dwarf, citizen_dwarf,
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
                isCitizen=function(unit) return unit == citizen_dwarf or unit == citizen_dog end,
                isResident=function() return false end,
                isFortControlled=function() return false end,
                isVisitor=function(unit) return unit == visitor_dwarf end,
                isMerchant=function() return false end,
                isDiplomat=function() return false end,
                getVisibleName=function() return nil end,
                getReadableName=function(unit) return 'Unit ' .. unit.id end,
                getProfessionName=function() return nil end,
                getMentalAttrValue=function() return nil end,
                getPhysicalAttrValue=function() return nil end,
            },
            translation={translateName=function() return nil end},
        }

        local active_provider = soulsearch_env.load_active_unit_provider(repo_root, df, dfhack)
            .new()
        local scoped = soulsearch_env.load_unit_scope_filter_provider(repo_root, dfhack).new(
            active_provider, {{id='unit_scope:citizens', direction='high'}})
        local filtered = soulsearch_env.load_race_filter_provider(repo_root, df).new(
            scoped, {{id='race:group:HUMANOIDS', direction='high'}})
        local residents = soulsearch_env.load_residents(repo_root, nil, dfhack)
        local rows, err = residents.collect_from_provider(filtered)

        test.assert_nil(err)
        test.assert_equal(1, #rows)
        test.assert_equal(citizen_dwarf, rows[1].unit)
        test.assert_equal(1, rows[1].unit_id)
        test.assert_equal('Unit 1', rows[1].name)

        local ranked = soulsearch_env.load_search(repo_root,
            soulsearch_env.load_attributes(repo_root)).apply(rows, {
            selected_filters={{id='skill:MINING', direction='high'}},
        })
        test.assert_equal(1, #ranked)
        test.assert_equal(1, ranked[1].unit_id)
    end)
end
