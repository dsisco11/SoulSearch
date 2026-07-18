local module_loader = require('support.module_loader')
local widget_harness = require('support.widget_harness')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local function load_extension(widgets, default_nil)
        local environment = module_loader.load(repo_root,
            'src/scripts_modinstalled/internal/soulsearch/ui/widget_extensions.lua', {
                DEFAULT_NIL=default_nil,
                require=function(name)
                    assert(name == 'gui.widgets')
                    return widgets
                end,
            })
        return environment
    end

    add_test('widget extensions: native descendants inherit declarative tooltip', function()
        local default_nil = {}
        local widgets = widget_harness.widgets(nil, default_nil)
        local extension = load_extension(widgets, default_nil)

        luaunit.assertIs(default_nil, widgets.Widget.ATTRS.tooltip)
        for _, widget_class in ipairs({widgets.HotkeyLabel,
                widgets.CycleHotkeyLabel, widgets.Label, widgets.List}) do
            local widget = widget_class{tooltip='Initial tooltip'}
            luaunit.assertIs('Initial tooltip', widget.tooltip)
            widget.tooltip = 'Updated tooltip'
            luaunit.assertIs('Updated tooltip', widget.tooltip)
            widget.tooltip = nil
            luaunit.assertNil(widget.tooltip)
            widget.tooltip = ''
            luaunit.assertIs('', widget.tooltip)
        end
        local reloaded_extension = load_extension(widgets, default_nil)
        luaunit.assertEvalToFalse(reloaded_extension.install_tooltip_attribute())
        luaunit.assertIs(default_nil, widgets.Widget.ATTRS.tooltip)
    end)

    add_test('widget extensions: incompatible tooltip attribute fails clearly', function()
        local default_nil = {}
        local widgets = widget_harness.widgets(nil, default_nil)
        widgets.Widget.ATTRS{tooltip=false}
        local ok, err = pcall(load_extension, widgets, default_nil)
        luaunit.assertEvalToFalse(ok)
        luaunit.assertEvalToTrue(tostring(err):find('incompatible contract', 1, true) ~= nil)
        luaunit.assertIs(false, widgets.Widget.ATTRS.tooltip)
    end)

    add_test('widget extensions: pointer attributes use native class defaults and reload safely', function()
        local default_nil = {}
        local widgets = widget_harness.widgets(nil, default_nil)
        local extension = load_extension(widgets, default_nil)

        luaunit.assertIs('target', widgets.Widget.ATTRS.pointer_policy)
        luaunit.assertIs('pass', widgets.Panel.ATTRS.pointer_policy)
        luaunit.assertIs('block', widgets.Window.ATTRS.pointer_policy)
        luaunit.assertIs('target', widgets.TextButton.ATTRS.pointer_policy)
        luaunit.assertIs(default_nil, widgets.Widget.ATTRS.on_pointer_enter)
        luaunit.assertIs(default_nil, widgets.Widget.ATTRS.on_pointer_update)
        luaunit.assertIs(default_nil, widgets.Widget.ATTRS.on_pointer_leave)
        luaunit.assertIs('target', widgets.Label{}.pointer_policy)
        luaunit.assertIs('pass', widgets.Panel{}.pointer_policy)
        luaunit.assertIs('block', widgets.Window{}.pointer_policy)
        luaunit.assertIs('target', widgets.TextButton{}.pointer_policy)
        luaunit.assertEvalToFalse(extension.install_pointer_attributes())
    end)

    add_test('widget extensions: incompatible pointer attribute fails clearly', function()
        local default_nil = {}
        local widgets = widget_harness.widgets(nil, default_nil)
        widgets.Panel.ATTRS{pointer_policy='target'}
        local ok, err = pcall(load_extension, widgets, default_nil)
        luaunit.assertEvalToFalse(ok)
        luaunit.assertEvalToTrue(tostring(err):find('incompatible contract', 1, true) ~= nil)
        luaunit.assertIs('target', widgets.Panel.ATTRS.pointer_policy)
    end)

    add_test('widget extensions: every native-widget host imports the extension', function()
        local sources = {
            'src/scripts_modinstalled/internal/soulsearch/ui_tooltip.lua',
            'src/scripts_modinstalled/internal/soulsearch/stats_panel.lua',
            'src/scripts_modinstalled/soulsearch-stats-overlay.lua',
            'src/scripts_modinstalled/internal/soulsearch/ui/filter_action_list.lua',
            'src/scripts_modinstalled/internal/soulsearch/ui/filter_panel.lua',
            'src/scripts_modinstalled/internal/soulsearch/ui/main_screen.lua',
            'src/scripts_modinstalled/internal/soulsearch/ui/main_window.lua',
            'src/scripts_modinstalled/internal/soulsearch/ui/modal_panel.lua',
            'src/scripts_modinstalled/internal/soulsearch/ui/preset_picker.lua',
            'src/scripts_modinstalled/internal/soulsearch/ui/results_panel.lua',
            'src/scripts_modinstalled/internal/soulsearch/ui/searchable_picker.lua',
            'src/scripts_modinstalled/internal/soulsearch/ui/sortable_header.lua',
            'src/scripts_modinstalled/internal/soulsearch/ui/unit_stats_list.lua',
        }
        for _, relative_path in ipairs(sources) do
            local file = assert(io.open(repo_root .. '/' .. relative_path, 'r'))
            local text = file:read('*a')
            file:close()
            luaunit.assertEvalToTrue(text:find(
                "reqscript('internal/soulsearch/ui/widget_extensions')", 1, true) ~= nil,
                'missing direct widget extension import: ' .. relative_path)
        end
        local tooltip_file = assert(io.open(repo_root ..
            '/src/scripts_modinstalled/internal/soulsearch/ui_tooltip.lua', 'r'))
        local tooltip_source = tooltip_file:read('*a')
        tooltip_file:close()
        luaunit.assertEvalToTrue(tooltip_source:find("pointer_policy='none'", 1, true) ~= nil,
            'tooltip renderer must exclude its subtree from pointer targeting')
        for _, relative_path in ipairs({
                'src/scripts_modinstalled/internal/soulsearch/ui/main_screen.lua',
                'src/scripts_modinstalled/soulsearch-stats-overlay.lua',
            }) do
            local file = assert(io.open(repo_root .. '/' .. relative_path, 'r'))
            local source = file:read('*a')
            file:close()
            luaunit.assertEvalToTrue(source:find(
                "reqscript('internal/soulsearch/ui/tooltip_agent')", 1, true) ~= nil,
                'missing per-root tooltip agent: ' .. relative_path)
        end
    end)

return native_tests
