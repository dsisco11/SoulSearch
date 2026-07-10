--@ module=true

---@class SoulSearchEnumEntry
---@field name string
---@field value integer

---Returns canonical enum entries ordered by numeric value.
---@param enum table
---@return SoulSearchEnumEntry[]
function entries(enum)
    local result = {}
    for index, name in ipairs(enum) do
        if name ~= 'NONE' then
            table.insert(result, {name=name, value=enum[name] or index})
        end
    end
    table.sort(result, function(left, right)
        return left.value < right.value
    end)
    return result
end

---Builds a numeric value-to-name index from canonical enum entries.
---@param enum table
---@return table<integer, string>
function names_by_value(enum)
    local result = {}
    for _, entry in ipairs(entries(enum)) do
        result[entry.value] = entry.name
    end
    return result
end
