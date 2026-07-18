local module_loader = require('support.module_loader')
local soulsearch_env = require('support.soulsearch_env')
local widget_harness = require('support.widget_harness')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local function load_tooltip(state)
        local widgets = widget_harness.widgets({
            Widget={
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
                    if name == 'gui' then
                        return {FRAME_INTERIOR='interior', paint_frame=function(_, _, style)
                            state.frame_paint_count = (state.frame_paint_count or 0) + 1
                            state.frame_style = style
                        end}
                    end
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

    add_test('Tooltip renderer: renders supplied current text immediately and wraps it', function()
        local state = {mouse_x=1, mouse_y=1, width=22, height=10}
        local Tooltip = load_tooltip(state)
        local text = 'Difference from the attribute average.'
        local tooltip = Tooltip{}
        luaunit.assertIs('Widget', tooltip.widget_kind)
        tooltip.frame_style = 'interior'
        local parent = {invalidate=function(self)
            self.invalidations = (self.invalidations or 0) + 1
        end}
        tooltip.parent_view = parent
        tooltip:set_tooltip(text, state.mouse_x, state.mouse_y)
        luaunit.assertEvalToTrue(tooltip.visible)
        luaunit.assertIs(1, parent.invalidations)
        luaunit.assertIs(1, tooltip.layout_update_count)

        tooltip:render('first')
        luaunit.assertIs('Difference from the\nattribute average.', tooltip.label.text)
        luaunit.assertIs(1, tooltip.frame.l)
        luaunit.assertIs(2, tooltip.frame.t)
        luaunit.assertIs(21, tooltip.frame.w)
        luaunit.assertIs(4, tooltip.frame.h)
        luaunit.assertIs(1, tooltip.render_count)
        luaunit.assertIs(1, tooltip.layout_update_count)
        local dc = {fill=function(self, rect, pen)
            self.fills = (self.fills or 0) + 1
            self.rect, self.pen = rect, pen
        end}
        tooltip:onRenderFrame(dc, 'tooltip-frame')
        luaunit.assertIs(1, state.frame_paint_count)
        luaunit.assertIs('interior', state.frame_style)

        text = 'Updated immediately.'
        tooltip:set_tooltip(text, state.mouse_x, state.mouse_y)
        luaunit.assertIs(2, tooltip.layout_update_count)
        tooltip:render('second')
        luaunit.assertIs('Updated immediately.', tooltip.label.text)
        luaunit.assertIs(2, tooltip.render_count)
        luaunit.assertIs('second', tooltip.last_dc)
    end)

    add_test('Tooltip renderer: clamps placement and stays hidden without text', function()
        local state = {mouse_x=9, mouse_y=4, width=10, height=5}
        local Tooltip = load_tooltip(state)
        local tooltip = Tooltip{}
        local parent = {invalidate=function(self)
            self.invalidations = (self.invalidations or 0) + 1
        end}
        tooltip.parent_view = parent
        tooltip:set_tooltip('Tip', state.mouse_x, state.mouse_y)

        tooltip:render('edge')
        luaunit.assertIs(5, tooltip.frame.l)
        luaunit.assertIs(2, tooltip.frame.t)
        luaunit.assertIs(5, tooltip.frame.w)
        luaunit.assertIs(3, tooltip.frame.h)

        tooltip:set_tooltip('', state.mouse_x, state.mouse_y)
        luaunit.assertEvalToFalse(tooltip.visible)
        luaunit.assertIs('', tooltip.label.text)
        luaunit.assertIs(2, parent.invalidations)
        tooltip:render('empty')
        luaunit.assertIs(1, tooltip.render_count)

        state.mouse_x = nil
        tooltip:set_tooltip('Hidden without a pointer', state.mouse_x, state.mouse_y)
        luaunit.assertEvalToFalse(tooltip.visible)
        luaunit.assertIs(3, parent.invalidations)
        tooltip:render('no-pointer')
        luaunit.assertIs(1, tooltip.render_count)
    end)

return native_tests
