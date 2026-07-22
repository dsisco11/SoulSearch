--@ module=true

local DEFAULT_SPEC = 'Ctrl-F@dwarfmode/Default'
local SOULSEARCH_GUI_COMMAND = 'gui/soulsearch'

---@param status string
---@param binding_added boolean|nil
---@return table
local function result(status, binding_added)
    return {status=status, binding_added=not not binding_added}
end

---@param binding table
---@return boolean
local function uses_default_hotkey(binding)
    return type(binding) == 'table' and binding.spec == DEFAULT_SPEC
end

---@param hotkey table|nil
---@return table result
function ensure_default(hotkey)
    hotkey = hotkey or dfhack.hotkey
    if type(hotkey) ~= 'table' or
            type(hotkey.listAllKeybinds) ~= 'function' or
            type(hotkey.addKeybind) ~= 'function' then
        return result('unavailable')
    end
    local ok, bindings = pcall(hotkey.listAllKeybinds)
    if not ok or type(bindings) ~= 'table' then return result('unavailable') end
    for _, binding in ipairs(bindings) do
        if uses_default_hotkey(binding) then
            if binding.command == SOULSEARCH_GUI_COMMAND then
                return result('existing')
            end
            return result('occupied')
        end
    end

    ok = pcall(hotkey.addKeybind, DEFAULT_SPEC, SOULSEARCH_GUI_COMMAND)
    if not ok then return result('error') end
    return result('added', true)
end
