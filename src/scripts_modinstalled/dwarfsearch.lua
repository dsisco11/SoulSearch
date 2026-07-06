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

local function refresh_scripts()
    reqscript('internal/dwarfsearch/attributes')
    reqscript('internal/dwarfsearch/residents')
    reqscript('internal/dwarfsearch/search')
    ui = reqscript('internal/dwarfsearch/ui')
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
