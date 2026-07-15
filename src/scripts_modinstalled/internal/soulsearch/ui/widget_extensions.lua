--@ module=true

local widgets = require('gui.widgets')

function install_tooltip_attribute()
    local widget = assert(widgets.Widget,
        'SoulSearch requires gui.widgets.Widget for tooltip attributes.')
    local attrs = assert(widget.ATTRS,
        'SoulSearch requires gui.widgets.Widget.ATTRS for tooltip attributes.')
    local existing = rawget(attrs, 'tooltip')
    if existing == nil then
        attrs{tooltip=DEFAULT_NIL}
        return true
    end
    assert(existing == DEFAULT_NIL,
        'gui.widgets.Widget.ATTRS.tooltip has an incompatible contract; ' ..
        'SoulSearch requires tooltip=DEFAULT_NIL.')
    return false
end

install_tooltip_attribute()

return {install_tooltip_attribute=install_tooltip_attribute}
