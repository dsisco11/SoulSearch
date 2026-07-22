--@ module=true

---@class SoulSearchStatsSubject
---@field unit df.unit
---@field unit_id integer
---@field row SoulSearchResidentRow
---@field name string
---@field profession string
---@field filter_criteria SoulSearchFilterCriterion[]

---@param source table|nil
---@return table[]
local function copy_sequence(source)
    local copy = {}
    for index, value in ipairs(source or {}) do copy[index] = value end
    return copy
end

---Creates the canonical Stats subject from a compatible row snapshot.
---@param row SoulSearchResidentRow|nil
---@param filter_criteria SoulSearchFilterCriterion[]|nil
---@return SoulSearchStatsSubject|nil
function from_row(row, filter_criteria)
    if type(row) ~= 'table' or type(row.unit_id) ~= 'number' or
            row.unit_id < 0 or not row.unit then
        return nil
    end
    return {
        unit=row.unit,
        unit_id=math.floor(row.unit_id),
        row=row,
        name=row.name or 'Unknown unit',
        profession=row.profession or '',
        filter_criteria=copy_sequence(filter_criteria),
    }
end
