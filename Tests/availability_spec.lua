local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('availability', function()

    local function load(map_loaded, fortress_mode)
        return soulsearch_env.load_availability(repo_root, {
            isMapLoaded=function() return map_loaded end,
            world={isFortressMode=function() return fortress_mode end},
        })
    end

    it('availability: no map, wrong mode, and valid fortress have one policy', function()
        assert.are.equal('SoulSearch requires a loaded fortress map.',
            load(false, true).get_unavailable_reason())
        assert.are.equal('SoulSearch only works in fortress mode.',
            load(true, false).get_unavailable_reason())
        assert.is_nil(load(true, true).get_unavailable_reason())
    end)

end)
