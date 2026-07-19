local soulsearch_env = require('support.soulsearch_env')

local function ids(units)
    local result = {}
    for _, unit in ipairs(units or {}) do table.insert(result, unit.id) end
    return result
end

local repo_root = require('support.repo_root')

describe('active unit provider', function()

    it('active unit provider: preserves source order and removes duplicates and inactive units', function()
        local first, second, inactive = {id=2}, {id=1}, {id=3}
        local df = {global={world={units={active={first, second, first, inactive}}}}}
        local dfhack = {isMapLoaded=function() return true end,
            world={isFortressMode=function() return true end},
            units={isActive=function(unit) return unit ~= inactive end}}
        local units, err = soulsearch_env.load_active_unit_provider(repo_root, df, dfhack)
            .new().get_units()
        assert.is_nil(err)
        assert.are.same({2, 1}, ids(units))
    end)

    it('active unit provider: returns no partial candidates when unavailable', function()
        local df = {global={world={units={active={}}}}}
        local dfhack = {isMapLoaded=function() return false end,
            world={isFortressMode=function() return true end},
            units={isActive=function() error('unexpected active check') end}}
        local units, err = soulsearch_env.load_active_unit_provider(repo_root, df, dfhack)
            .new().get_units()
        assert.is_nil(units)
        assert.are.equal('SoulSearch requires a loaded fortress map.', err)
    end)

end)