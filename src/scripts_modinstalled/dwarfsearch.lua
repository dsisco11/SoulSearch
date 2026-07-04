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

local ui = reqscript('internal/dwarfsearch/ui')

function main(...)
    ui.open(...)
end

if dfhack_flags.module then
    return
end

main(...)
