--@ module=true

local widgets = require('gui.widgets')

local OPTIONS = {{label='', value=0}, {label=' ' .. string.char(24), value=1},
    {label=' ' .. string.char(25), value=2}}

function new(info)
    local on_cycle = info.on_cycle
    info.options, info.initial_option, info.option_gap = OPTIONS, 0, 0
    info.on_change = function() on_cycle() end
    info.on_cycle = nil
    return widgets.CycleHotkeyLabel(info)
end

function set_sort(control, active, reverse)
    control:setOption(not active and 0 or reverse and 2 or 1, false)
end
