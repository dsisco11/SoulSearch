--@ module=true

---Matches a case-insensitive literal substring. Nil and false haystacks coerce
---to an empty string; nil or empty needles match every value.
---@param haystack any
---@param needle string|nil
---@return boolean
function contains(haystack, needle)
    if not needle or needle == '' then
        return true
    end
    return tostring(haystack or ''):lower():find(needle:lower(), 1, true) ~= nil
end
