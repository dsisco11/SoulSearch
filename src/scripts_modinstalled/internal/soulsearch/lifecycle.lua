--@ module=true

local attributes = reqscript('internal/soulsearch/attributes')
local descriptors = reqscript('internal/soulsearch/descriptors')
local residents = reqscript('internal/soulsearch/residents')

local active_world

---Resets caches only at an update boundary, before a UI/search pass begins.
function reset_caches()
    attributes.reset_cache()
    descriptors.reset_cache()
    residents.reset_cache()
end

---Detects a world-generation change and resets caches before work starts.
---@param world any|nil
---@return boolean changed
function prepare_for_world(world)
    world = world or (df.global and df.global.world)
    if world == active_world then
        return false
    end
    reset_caches()
    active_world = world
    return true
end
