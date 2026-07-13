--@ module=true

local DEFAULT_SPEC = 'Ctrl-F@dwarfmode/Default'
local SOULSEARCH_GUI_COMMAND = 'gui/soulsearch'

---@param status string
---@param binding_added boolean|nil
---@return table
local function result(status, binding_added)
    return {status=status, binding_added=not not binding_added}
end

---@param command any
---@return boolean
local function is_soulsearch_gui_command(command)
    return command == SOULSEARCH_GUI_COMMAND
end

---@return table|nil
local function get_preferences()
    local preferences = reqscript('internal/soulsearch/keybinding_preferences')
    if type(preferences) ~= 'table' or type(preferences.new) ~= 'function' then
        return nil
    end
    return preferences.new({
        json=require('json'),
        scriptmanager=require('script-manager'),
        filesystem=dfhack.filesystem,
    })
end

---@param preferences SoulSearchKeybindingPreferences
---@return boolean
local function mark_considered(preferences)
    local ok, success = pcall(preferences.mark_considered)
    return ok and success == true
end

---@param preferences SoulSearchKeybindingPreferences|nil
---@param hotkey table|nil
---@return table result
function ensure_default(preferences, hotkey)
    preferences = preferences or get_preferences()
    hotkey = hotkey or dfhack.hotkey
    if type(hotkey) ~= 'table' or
            type(hotkey.listAllKeybinds) ~= 'function' or
            type(hotkey.addKeybind) ~= 'function' then
        return result('unavailable')
    end
    if type(preferences) ~= 'table' or type(preferences.read) ~= 'function' or
            type(preferences.mark_considered) ~= 'function' then
        return result('unavailable')
    end

    local ok, marker_status = pcall(preferences.read)
    if not ok then return result('error') end
    if marker_status ~= 'unset' and marker_status ~= 'considered' then
        return result(marker_status == 'unavailable' and 'unavailable' or 'error')
    end

    ok, bindings = pcall(hotkey.listAllKeybinds)
    if not ok or type(bindings) ~= 'table' then return result('unavailable') end
    local has_binding = false
    for _, binding in ipairs(bindings) do
        if type(binding) == 'table' and
                is_soulsearch_gui_command(binding.command) then
            has_binding = true
            break
        end
    end

    if marker_status == 'considered' then
        return result(has_binding and 'existing' or 'opted_out')
    end

    if has_binding then
        ok = mark_considered(preferences)
        return ok and result('existing') or result('error')
    end

    ok = pcall(hotkey.addKeybind, DEFAULT_SPEC, SOULSEARCH_GUI_COMMAND)
    if not ok then return result('error') end
    ok = mark_considered(preferences)
    return ok and result('added', true) or result('error', true)
end
