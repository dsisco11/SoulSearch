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

local ui

---@param script_name string
---@param required_field string|nil
---@return table
local function load_module(script_name, required_field)
    local module = reqscript(script_name)
    if required_field and module[required_field] == nil then
        _, module = dfhack.run_script_with_env(nil, script_name, {
            module=true,
            module_strict=true,
        })
    end
    return module
end

---Reloads SoulSearch modules so DFHack picks up edited scripts.
local function refresh_scripts()
    load_module('internal/soulsearch/attributes')
    load_module('internal/soulsearch/residents', 'get_unavailable_reason')
    load_module('internal/soulsearch/search', 'search')
    ui = load_module('internal/soulsearch/ui', 'open')
end

refresh_scripts()

---DFHack command entry point.
---@param ... any
function main(...)
    refresh_scripts()
    ui.open(...)
end

if dfhack_flags.module then
    return
end

main(...)
