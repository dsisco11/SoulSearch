--@module=true
--@enable=true

-- SoulSearch bootstrap, initialization, and reload command.
--[====[
soulsearch
===========

Tags: fort | gameplay | units | inspection

Automatically seed the default keybinding after installation when `Ctrl-F` is
unclaimed. Running the command manually performs full runtime setup without
opening the UI.

Usage
-----

    soulsearch
    soulsearch reload
    enable soulsearch
    disable soulsearch

Use `gui/soulsearch` to open the SoulSearch units search panel. Manual setup
also attempts default-keybinding setup, but never replaces another command's
`Ctrl-F` binding.
]====]

local MODULE_REGISTRY_SCRIPT = 'internal/soulsearch/module_registry'
local KEYBINDINGS_SCRIPT = 'internal/soulsearch/keybindings'
local OVERLAY_SCRIPT = 'soulsearch-stats-overlay'

---@return boolean
function isEnabled()
    return bootstrap_enabled == true
end

---@return table
local function bootstrap()
    local ok, keybindings = pcall(reqscript, KEYBINDINGS_SCRIPT)
    if not ok or type(keybindings) ~= 'table' or
            type(keybindings.ensure_default) ~= 'function' then
        return {status='error'}
    end
    local result
    ok, result = pcall(keybindings.ensure_default)
    if not ok then return {status='error'} end
    if type(result) ~= 'table' then return {status='error'} end
    return result
end

---@return table
function enable_bootstrap()
    bootstrap_enabled = true
    return bootstrap()
end

---@return table
function disable_bootstrap()
    bootstrap_enabled = false
    return {status='disabled'}
end

---@param registry any
---@return boolean
local function is_valid_registry(registry)
    return type(registry) == 'table' and
        type(registry.load_all) == 'function' and
        type(registry.get_script_names) == 'function'
end

---Loads the reload coordinator and repairs a partial environment left by an
---interrupted development reload.
---@return table
local function load_module_registry()
    local registry = reqscript(MODULE_REGISTRY_SCRIPT)
    if not is_valid_registry(registry) then
        dfhack.run_command('devel/clear-script-env', MODULE_REGISTRY_SCRIPT)
        dfhack.run_script(MODULE_REGISTRY_SCRIPT)
        registry = reqscript(MODULE_REGISTRY_SCRIPT)
    end
    assert(is_valid_registry(registry),
        'SoulSearch could not load its module registry.')
    return registry
end

---@return table<string, table>
local function validate_modules()
    return load_module_registry().load_all(reqscript)
end

---@param script_names string[]
local function clear_script_environments(script_names)
    local loaded_names = {}
    for _, name in ipairs(script_names) do
        local path = dfhack.findScript(name)
        if path and dfhack.internal.scripts[path] then
            table.insert(loaded_names, name)
        end
    end
    if #loaded_names > 0 then
        dfhack.run_command('devel/clear-script-env', table.unpack(loaded_names))
    end
end

---Explicit development reload. Rebuild the registry itself between clearing
---the old generation and constructing the fresh dependency sequence.
---@return table<string, table>
local function reload_modules()
    local old_registry = load_module_registry()
    local old_ui = reqscript('internal/soulsearch/ui')
    assert(type(old_ui.dismiss_all) == 'function',
        'SoulSearch UI module cannot safely dismiss windows for reload.')
    old_ui.dismiss_all()

    local old_script_names = old_registry.get_script_names()
    local old_modules = {}
    for _, name in ipairs(old_script_names) do
        if name ~= MODULE_REGISTRY_SCRIPT then
            table.insert(old_modules, name)
        end
    end
    clear_script_environments(old_modules)

    dfhack.run_command('devel/clear-script-env', MODULE_REGISTRY_SCRIPT)
    dfhack.run_script(MODULE_REGISTRY_SCRIPT)
    local fresh_registry = load_module_registry()

    local fresh_modules = {}
    for _, spec in ipairs(fresh_registry.MODULES) do
        table.insert(fresh_modules, spec.name)
    end
    clear_script_environments(fresh_modules)
    for _, spec in ipairs(fresh_registry.MODULES) do
        dfhack.run_script(spec.name)
    end

    -- clear-script-env only empties the cached module table. Remove the
    -- cache entry instead, so overlay.rescan() re-executes the script and can
    -- discover its fresh OVERLAY_WIDGETS table.
    local overlay_path = assert(dfhack.findScript(OVERLAY_SCRIPT),
        'SoulSearch stats overlay script could not be found.')
    dfhack.internal.scripts[overlay_path] = nil
    require('plugins.overlay').rescan()
    return fresh_registry.load_all(reqscript)
end

---@param modules table<string, table>
---@return table<string, table>
local function prepare_modules(modules)
    modules['internal/soulsearch/keybindings'].ensure_default()
    modules['internal/soulsearch/lifecycle'].prepare_for_world()
    return modules
end

---Initializes the current SoulSearch runtime generation without opening a UI.
---@return table<string, table>
function initialize()
    return prepare_modules(validate_modules())
end

---Reloads SoulSearch runtime modules without opening a UI.
---@return table<string, table>
function reload()
    return prepare_modules(reload_modules())
end

---DFHack command entry point.
---@param ... string
function main(...)
    local args = {...}
    if #args == 0 then
        initialize()
    elseif #args == 1 and args[1] == 'reload' then
        reload()
    else
        qerror('Usage: soulsearch [reload]')
    end
end

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        enable_bootstrap()
    else
        disable_bootstrap()
    end
    return
end

if dfhack_flags.module then
    if bootstrap_enabled == nil then bootstrap_enabled = true end
    if bootstrap_enabled then bootstrap() end
    return
end

main(...)
