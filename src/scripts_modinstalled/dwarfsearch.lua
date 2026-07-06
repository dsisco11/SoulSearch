-- DwarfSearch public DFHack command.
--[====[
dwarfsearch
===========

Tags: fort | units | inspection

Open the DwarfSearch resident search panel.

Usage
-----

    dwarfsearch
]====]

local ui

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

local function refresh_scripts()
    load_module('internal/dwarfsearch/attributes')
    load_module('internal/dwarfsearch/residents', 'get_unavailable_reason')
    load_module('internal/dwarfsearch/search', 'search')
    ui = load_module('internal/dwarfsearch/ui', 'open')
end

refresh_scripts()

function main(...)
    refresh_scripts()
    ui.open(...)
end

if dfhack_flags.module then
    return
end

main(...)
