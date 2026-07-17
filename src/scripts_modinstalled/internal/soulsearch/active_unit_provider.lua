--@ module=true

local candidate_provider =
    reqscript('internal/soulsearch/candidate_provider')
local availability = reqscript('internal/soulsearch/availability')

---@param unit df.unit
---@return integer|df.unit
local function get_unit_key(unit)
    return unit.id ~= nil and unit.id or unit
end

---Provides each active unit once, in the game's active-list order.
---@return SoulSearchCandidateProvider
function new()
    return candidate_provider.new(function()
        local reason = availability.get_unavailable_reason()
        if reason then return nil, reason end

        local units, seen = {}, {}
        for _, unit in ipairs(df.global.world.units.active) do
            local key = get_unit_key(unit)
            if not seen[key] and dfhack.units.isActive(unit) then
                seen[key] = true
                table.insert(units, unit)
            end
        end
        return units
    end)
end
