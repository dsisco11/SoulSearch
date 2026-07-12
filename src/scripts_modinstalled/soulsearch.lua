-- SoulSearch public DFHack command.
--[====[
soulsearch
===========

Tags: fort | units | inspection

Open the SoulSearch resident search panel.

Usage
-----

    soulsearch
]====]

local MODULE_REGISTRY_SCRIPT = 'internal/soulsearch/module_registry'

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

local module_registry = load_module_registry()

---@return table<string, table>
local function validate_modules()
    return module_registry.load_all(reqscript)
end

---Explicit development reload. Keep the registry environment alive as the
---coordinator while its dependency/consumer modules are cleared and rebuilt.
---@return table<string, table>
local function reload_modules()
    local script_names = module_registry.get_script_names()
    -- The registry is the current command's coordinator. Clearing it here can
    -- leave reqscript() with a partially rebuilt environment before load_all()
    -- runs. Every listed runtime module follows it in dependency-safe order.
    table.remove(script_names, 1)
    dfhack.run_command(
        'devel/clear-script-env',
        table.unpack(script_names))
    for _, spec in ipairs(module_registry.MODULES) do
        dfhack.run_script(spec.name)
    end
    return validate_modules()
end

---DFHack command entry point.
---@param ... any
function main(...)
    local args = {...}
    local modules = args[1] == 'reload' and reload_modules() or validate_modules()
    modules['internal/soulsearch/lifecycle'].prepare_for_world()
    modules['internal/soulsearch/ui'].open(table.unpack(args))
end

if dfhack_flags.module then
    return
end

main(...)
