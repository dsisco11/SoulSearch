--@ module=true

local residents = reqscript('internal/soulsearch/residents')
local subject_factory = reqscript('internal/soulsearch/stats_subject')

---@param unit any
---@return SoulSearchStatsSubject|nil
---@return string|nil
local function build_subject(unit)
    local unavailable = residents.get_unavailable_reason()
    if unavailable then return nil, unavailable end
    local unit_id, err = residents.validate_unit_reference(unit)
    if not unit_id then return nil, err end
    if not df.unit.find or df.unit.find(unit_id) ~= unit then
        return nil, 'SoulSearch requires a current unit.'
    end
    local row
    row, err = residents.collect_unit(unit)
    if not row then return nil, err end
    return subject_factory.from_row(row, {}), nil
end

---Builds the shared stats subject rendered by the attached unit-card overlay.
function get_subject(unit)
    return build_subject(unit)
end
