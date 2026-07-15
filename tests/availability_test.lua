local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local function load(map_loaded, fortress_mode)
        return soulsearch_env.load_availability(repo_root, {
            isMapLoaded=function() return map_loaded end,
            world={isFortressMode=function() return fortress_mode end},
        })
    end

    test.case('availability: no map, wrong mode, and valid fortress have one policy', function()
        test.assert_equal('SoulSearch requires a loaded fortress map.',
            load(false, true).get_unavailable_reason())
        test.assert_equal('SoulSearch only works in fortress mode.',
            load(true, false).get_unavailable_reason())
        test.assert_nil(load(true, true).get_unavailable_reason())
    end)
end
