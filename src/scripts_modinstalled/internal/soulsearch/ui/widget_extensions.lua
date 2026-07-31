--@ module=true

local widgets = require('gui.widgets')
local reqscript_fn = rawget(_G, 'reqscript')

local POINTER_POLICY = {
    TARGET='target',
    PASS='pass',
    BLOCK='block',
    NONE='none',
}

if type(reqscript_fn) == 'function' then
    local ok, pointer = pcall(reqscript_fn, 'dwarfui/pointer')
    if ok and type(pointer) == 'table' and type(pointer.PointerPolicy) == 'table' then
        POINTER_POLICY.TARGET = pointer.PointerPolicy.TARGET
        POINTER_POLICY.PASS = pointer.PointerPolicy.PASS
        POINTER_POLICY.BLOCK = pointer.PointerPolicy.BLOCK
        POINTER_POLICY.NONE = pointer.PointerPolicy.NONE
    end
end

local function install_attribute(class, name, default, description)
    local attrs = assert(class and class.ATTRS,
        'SoulSearch requires ' .. description .. '.ATTRS.')
    local existing = rawget(attrs, name)
    if existing == nil then
        attrs{[name]=default}
        return true
    end
    assert(existing == default,
        description .. '.ATTRS.' .. name .. ' has an incompatible contract; ' ..
        'SoulSearch requires ' .. name .. '=' .. tostring(default) .. '.')
    return false
end

function install_tooltip_attribute()
    local widget = assert(widgets.Widget,
        'SoulSearch requires gui.widgets.Widget for tooltip attributes.')
    return install_attribute(widget, 'tooltip', DEFAULT_NIL,
        'gui.widgets.Widget')
end

function install_pointer_attributes()
    local changed = false
    local widget = assert(widgets.Widget,
        'SoulSearch requires gui.widgets.Widget for pointer attributes.')
    local panel = assert(widgets.Panel,
        'SoulSearch requires gui.widgets.Panel for pointer attributes.')
    local window = assert(widgets.Window,
        'SoulSearch requires gui.widgets.Window for pointer attributes.')
    local text_button = assert(widgets.TextButton,
        'SoulSearch requires gui.widgets.TextButton for pointer attributes.')

    changed = install_attribute(widget, 'pointer_policy', POINTER_POLICY.TARGET,
        'gui.widgets.Widget') or changed
    changed = install_attribute(widget, 'on_pointer_enter', DEFAULT_NIL,
        'gui.widgets.Widget') or changed
    changed = install_attribute(widget, 'on_pointer_update', DEFAULT_NIL,
        'gui.widgets.Widget') or changed
    changed = install_attribute(widget, 'on_pointer_leave', DEFAULT_NIL,
        'gui.widgets.Widget') or changed
    changed = install_attribute(panel, 'pointer_policy', POINTER_POLICY.PASS,
        'gui.widgets.Panel') or changed
    changed = install_attribute(window, 'pointer_policy', POINTER_POLICY.BLOCK,
        'gui.widgets.Window') or changed
    -- TextButton is a Panel that delegates input to an internal HotkeyLabel.
    -- It is nevertheless the public control that declares the tooltip, so it
    -- must remain the terminal pointer target rather than its implementation
    -- child.
    changed = install_attribute(text_button, 'pointer_policy', POINTER_POLICY.TARGET,
        'gui.widgets.TextButton') or changed
    return changed
end

install_tooltip_attribute()
install_pointer_attributes()

return {
    install_tooltip_attribute=install_tooltip_attribute,
    install_pointer_attributes=install_pointer_attributes,
}
