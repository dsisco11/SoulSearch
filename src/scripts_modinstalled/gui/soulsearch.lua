-- SoulSearch GUI command.
--[====[
gui/soulsearch
==============

Tags: fort | units | inspection

Open the SoulSearch units search panel.

Usage
-----

    gui/soulsearch
]====]

local command = reqscript('soulsearch')

---DFHack command entry point.
function main(...)
    if select('#', ...) ~= 0 then
        qerror('Usage: gui/soulsearch')
    end
    local modules = command.initialize()
    return modules['internal/soulsearch/ui'].open()
end

main(...)
