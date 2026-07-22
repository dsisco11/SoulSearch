--@ module=true

---Returns the player-facing reason SoulSearch cannot safely access fortress data.
---@return string|nil
function get_unavailable_reason()
    if not dfhack.isMapLoaded() then
        return 'SoulSearch requires a loaded fortress map.'
    end
    if not dfhack.world.isFortressMode() then
        return 'SoulSearch only works in fortress mode.'
    end
    return nil
end
