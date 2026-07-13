--@ module=true

local DEFAULT_SPEC = 'Ctrl-F@dwarfmode/Default'
local SOULSEARCH_GUI_COMMAND = 'gui/soulsearch'

---@param command any
---@return boolean
local function is_soulsearch_gui_command(command)
    return command == SOULSEARCH_GUI_COMMAND
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
        if is_soulsearch_gui_command(binding.command) then
            return false
        end
    end

    hotkey.addKeybind(DEFAULT_SPEC, SOULSEARCH_GUI_COMMAND)
    return true
end
