--@ module=true

---@class SoulSearchSortSpec
---@field columns table<string, boolean>
---@field first_reverse table<string, boolean>

---@param columns string[]
---@param first_reverse table<string, boolean>|nil
---@return SoulSearchSortSpec
function new_spec(columns, first_reverse)
    local valid, direction = {}, {}
    for _, key in ipairs(columns or {}) do
        valid[key] = true
        direction[key] = first_reverse and first_reverse[key] or false
    end
    return {columns=valid, first_reverse=direction}
end

---@param spec SoulSearchSortSpec
---@return table
function get_default(spec)
    return {key=nil, reverse=false, phase=0}
end

---@param value any
---@param spec SoulSearchSortSpec
---@return table
function normalize(value, spec)
    if type(value) ~= 'table' or type(spec) ~= 'table' or
            not spec.columns[value.key] or
            value.phase ~= 1 and value.phase ~= 2 then
        return get_default(spec)
    end
    local reverse = value.phase == 1 and spec.first_reverse[value.key] or
        value.phase == 2 and not spec.first_reverse[value.key]
    return {key=value.key, reverse=reverse, phase=value.phase}
end

---@param value any
---@param column string
---@param spec SoulSearchSortSpec
---@return table
function next(value, column, spec)
    local current = normalize(value, spec)
    if not spec.columns[column] then return current end
    local phase = current.key == column and current.phase + 1 or 1
    if phase > 2 then return get_default(spec) end
    return normalize({key=column, phase=phase}, spec)
end
