--@ module=true

local DEFAULT_SPEC = 'Ctrl-F@dwarfmode/Default'
local SOULSEARCH_COMMAND = 'soulsearch'

---@param command any
---@return boolean
local function is_soulsearch_command(command)
    return type(command) == 'string' and
        (command == SOULSEARCH_COMMAND or command:match('^soulsearch%s') ~= nil)
end

---@return boolean added
function ensure_default()
    local hotkey = dfhack.hotkey
    if type(hotkey) ~= 'table' or
            type(hotkey.listAllKeybinds) ~= 'function' or
            type(hotkey.addKeybind) ~= 'function' then
        return false
    end

    for _, binding in ipairs(hotkey.listAllKeybinds() or {}) do
        if is_soulsearch_command(binding.command) then
            return false
        end
    end

    hotkey.addKeybind(DEFAULT_SPEC, SOULSEARCH_COMMAND)
    return true
end
