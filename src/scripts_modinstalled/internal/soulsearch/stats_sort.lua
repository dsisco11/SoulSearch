--@ module=true

local VALID_KEYS = {label=true, value=true}

---@param sort any
---@return SoulSearchStatsSort
function normalize(sort)
    if type(sort) ~= 'table' or not VALID_KEYS[sort.key] or
            sort.phase ~= 1 and sort.phase ~= 2 then
        return {key=nil, reverse=false, phase=0}
    end
    local reverse = sort.phase == 1 and sort.key == 'value' or
        sort.phase == 2 and sort.key ~= 'value'
    return {key=sort.key, reverse=reverse, phase=sort.phase}
end

---@return SoulSearchStatsSort
function get_default()
    return {key=nil, reverse=false, phase=0}
end

---@param sort any
---@param column string
---@return SoulSearchStatsSort
function next(sort, column)
    local current = normalize(sort)
    if not VALID_KEYS[column] then return current end
    local phase = current.key == column and current.phase + 1 or 1
    if phase > 2 then return get_default() end
    return normalize({key=column, phase=phase})
end
