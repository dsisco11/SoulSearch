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

local module_registry = reqscript('internal/soulsearch/module_registry')

---@return table<string, table>
local function validate_modules()
    return module_registry.load_all(reqscript)
end

---Explicit development reload. Normal invocation validates retained reqscript
---environments; this path clears every internal environment with DFHack's
---supported tool, then reloads dependencies and consumers in one generation.
---@return table<string, table>
local function reload_modules()
    dfhack.run_command(
        'devel/clear-script-env',
        table.unpack(module_registry.get_script_names()))
    module_registry = reqscript('internal/soulsearch/module_registry')
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
