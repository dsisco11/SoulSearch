local module_loader = require('support.module_loader')
local soulsearch_env = require('support.soulsearch_env')
local widget_harness = require('support.widget_harness')

return function(test, repo_root)
    local function load_tooltip(state)
        local widgets = widget_harness.widgets({
            Window={
                render=function(self, dc)
                    self.render_count = (self.render_count or 0) + 1
                    self.last_dc = dc
                end,
                updateLayout=function(self)
                    self.layout_update_count = (self.layout_update_count or 0) + 1
                end,
            },
        })
        local environment = module_loader.load(repo_root,
            'src/scripts_modinstalled/internal/soulsearch/ui_tooltip.lua', {
                COLOR_BLACK='black',
                COLOR_WHITE='white',
                DEFAULT_NIL=nil,
                defclass=widget_harness.defclass,
                dfhack={
                    pen={parse=function(value) return value end},
                    screen={
                        getMousePos=function() return state.mouse_x, state.mouse_y end,
                        getWindowSize=function() return state.width, state.height end,
                    },
                },
                require=function(name)
                    if name == 'gui' then return {FRAME_THIN='thin'} end
                    if name == 'gui.widgets' then return widgets end
                    error('unexpected require: ' .. tostring(name))
                end,
                reqscript=function(name)
                    if name == 'internal/soulsearch/ui/widget_extensions' then
                        return {}
                    end
                    assert(name == 'internal/soulsearch/ui_format')
                    return soulsearch_env.load_ui_format(repo_root)
                end,
            })
        return environment.SoulSearchTooltip
    end

    test.case('Tooltip renderer: reads current text immediately and wraps it', function()
        local state = {mouse_x=1, mouse_y=1, width=22, height=10}
        local Tooltip = load_tooltip(state)
        local text = 'Difference from the attribute average.'
        local tooltip = Tooltip{get_text=function() return text end}

        tooltip:render('first')
        test.assert_equal('Difference from the\nattribute average.', tooltip.label.text)
        test.assert_equal(1, tooltip.frame.l)
        test.assert_equal(2, tooltip.frame.t)
        test.assert_equal(21, tooltip.frame.w)
        test.assert_equal(4, tooltip.frame.h)
        test.assert_equal(1, tooltip.render_count)

        text = 'Updated immediately.'
        tooltip:render('second')
        test.assert_equal('Updated immediately.', tooltip.label.text)
        test.assert_equal(2, tooltip.render_count)
        test.assert_equal('second', tooltip.last_dc)
    end)

    test.case('Tooltip renderer: clamps placement and stays hidden without text', function()
        local state = {mouse_x=9, mouse_y=4, width=10, height=5}
        local Tooltip = load_tooltip(state)
        local tooltip = Tooltip{get_text=function() return 'Tip' end}

        tooltip:render('edge')
        test.assert_equal(5, tooltip.frame.l)
        test.assert_equal(2, tooltip.frame.t)
        test.assert_equal(5, tooltip.frame.w)
        test.assert_equal(3, tooltip.frame.h)

        tooltip.get_text=function() return '' end
        tooltip:render('empty')
        test.assert_equal(1, tooltip.render_count)

        state.mouse_x = nil
        tooltip.get_text=function() return 'Hidden without a pointer' end
        tooltip:render('no-pointer')
        test.assert_equal(1, tooltip.render_count)
    end)
end
