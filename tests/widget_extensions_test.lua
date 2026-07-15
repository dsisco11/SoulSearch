local module_loader = require('support.module_loader')
local widget_harness = require('support.widget_harness')

return function(test, repo_root)
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

    test.case('widget extensions: native descendants inherit declarative tooltip', function()
        local default_nil = {}
        local widgets = widget_harness.widgets(nil, default_nil)
        local extension = load_extension(widgets, default_nil)

        test.assert_equal(default_nil, widgets.Widget.ATTRS.tooltip)
        for _, widget_class in ipairs({widgets.HotkeyLabel,
                widgets.CycleHotkeyLabel, widgets.Label, widgets.List}) do
            local widget = widget_class{tooltip='Initial tooltip'}
            test.assert_equal('Initial tooltip', widget.tooltip)
            widget.tooltip = 'Updated tooltip'
            test.assert_equal('Updated tooltip', widget.tooltip)
            widget.tooltip = nil
            test.assert_nil(widget.tooltip)
            widget.tooltip = ''
            test.assert_equal('', widget.tooltip)
        end
        local reloaded_extension = load_extension(widgets, default_nil)
        test.assert_false(reloaded_extension.install_tooltip_attribute())
        test.assert_equal(default_nil, widgets.Widget.ATTRS.tooltip)
    end)

    test.case('widget extensions: incompatible tooltip attribute fails clearly', function()
        local default_nil = {}
        local widgets = widget_harness.widgets(nil, default_nil)
        widgets.Widget.ATTRS{tooltip=false}
        local ok, err = pcall(load_extension, widgets, default_nil)
        test.assert_false(ok)
        test.assert_true(tostring(err):find('incompatible contract', 1, true) ~= nil)
        test.assert_equal(false, widgets.Widget.ATTRS.tooltip)
    end)

    test.case('widget extensions: pointer attributes use native class defaults and reload safely', function()
        local default_nil = {}
        local widgets = widget_harness.widgets(nil, default_nil)
        local extension = load_extension(widgets, default_nil)

        test.assert_equal('target', widgets.Widget.ATTRS.pointer_policy)
        test.assert_equal('pass', widgets.Panel.ATTRS.pointer_policy)
        test.assert_equal('block', widgets.Window.ATTRS.pointer_policy)
        test.assert_equal(default_nil, widgets.Widget.ATTRS.on_pointer_enter)
        test.assert_equal(default_nil, widgets.Widget.ATTRS.on_pointer_update)
        test.assert_equal(default_nil, widgets.Widget.ATTRS.on_pointer_leave)
        test.assert_equal('target', widgets.Label{}.pointer_policy)
        test.assert_equal('pass', widgets.Panel{}.pointer_policy)
        test.assert_equal('block', widgets.Window{}.pointer_policy)
        test.assert_false(extension.install_pointer_attributes())
    end)

    test.case('widget extensions: incompatible pointer attribute fails clearly', function()
        local default_nil = {}
        local widgets = widget_harness.widgets(nil, default_nil)
        widgets.Panel.ATTRS{pointer_policy='target'}
        local ok, err = pcall(load_extension, widgets, default_nil)
        test.assert_false(ok)
        test.assert_true(tostring(err):find('incompatible contract', 1, true) ~= nil)
        test.assert_equal('target', widgets.Panel.ATTRS.pointer_policy)
    end)

    test.case('widget extensions: every native-widget host imports the extension', function()
        local sources = {
            'src/scripts_modinstalled/internal/soulsearch/ui_tooltip.lua',
            'src/scripts_modinstalled/internal/soulsearch/stats_panel.lua',
            'src/scripts_modinstalled/internal/soulsearch/stats_popover.lua',
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
            'src/scripts_modinstalled/internal/soulsearch/ui/unit_scope_picker.lua',
            'src/scripts_modinstalled/internal/soulsearch/ui/unit_stats_list.lua',
        }
        for _, relative_path in ipairs(sources) do
            local file = assert(io.open(repo_root .. '/' .. relative_path, 'r'))
            local text = file:read('*a')
            file:close()
            test.assert_true(text:find(
                "reqscript('internal/soulsearch/ui/widget_extensions')", 1, true) ~= nil,
                'missing direct widget extension import: ' .. relative_path)
        end
        local tooltip_file = assert(io.open(repo_root ..
            '/src/scripts_modinstalled/internal/soulsearch/ui_tooltip.lua', 'r'))
        local tooltip_source = tooltip_file:read('*a')
        tooltip_file:close()
        test.assert_true(tooltip_source:find("pointer_policy='none'", 1, true) ~= nil,
            'tooltip renderer must exclude its subtree from pointer targeting')
        for _, relative_path in ipairs({
                'src/scripts_modinstalled/internal/soulsearch/ui/main_screen.lua',
                'src/scripts_modinstalled/internal/soulsearch/stats_popover.lua',
                'src/scripts_modinstalled/soulsearch-stats-overlay.lua',
            }) do
            local file = assert(io.open(repo_root .. '/' .. relative_path, 'r'))
            local source = file:read('*a')
            file:close()
            test.assert_true(source:find(
                "reqscript('internal/soulsearch/ui/tooltip_agent')", 1, true) ~= nil,
                'missing per-root tooltip agent: ' .. relative_path)
        end
    end)
end
