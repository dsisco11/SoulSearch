local module_loader = require('support.module_loader')
local soulsearch_env = require('support.soulsearch_env')
local widget_harness = require('support.widget_harness')

return function(test, repo_root)
    local function load_agent(mouse)
        local dispatcher = soulsearch_env.load_pointer_dispatcher(repo_root, {
            screen={getMousePos=function() return mouse.x, mouse.y end},
        })
        return module_loader.load(repo_root,
            'src/scripts_modinstalled/internal/soulsearch/ui/tooltip_agent.lua', {
                dfhack={screen={getMousePos=function()
                    mouse.samples = mouse.samples + 1
                    return mouse.x, mouse.y
                end}},
                reqscript=function(name)
                    assert(name == 'internal/soulsearch/ui/pointer_dispatcher')
                    return dispatcher
                end,
            })
    end

    local function target(x, y, text)
        local view = {visible=true, active=true, pointer_policy='target', tooltip=text,
            subviews={}}
        widget_harness.set_frame(view, x, y, 4, 4)
        return view
    end

    local function native_widgets()
        local default_nil = widget_harness.default_nil()
        local widgets = widget_harness.widgets(nil, default_nil)
        module_loader.load(repo_root,
            'src/scripts_modinstalled/internal/soulsearch/ui/widget_extensions.lua', {
                DEFAULT_NIL=default_nil,
                require=function(name)
                    assert(name == 'gui.widgets')
                    return widgets
                end,
            })
        return widgets
    end

    local function root(children)
        local view = {visible=true, active=true, pointer_policy='target', subviews=children}
        widget_harness.set_frame(view, 0, 0, 20, 20)
        return view
    end

    test.case('tooltip agent: reads only the selected target and current mutation', function()
        local mouse = {x=2, y=2, samples=0}
        local TooltipAgent = load_agent(mouse).TooltipAgent
        local renderer = {set_tooltip=function(self, text, x, y)
            self.text, self.x, self.y = text, x, y
        end}
        local control = target(1, 1, 'Initial')
        local agent = TooltipAgent.new(root({control}), renderer)

        agent:update()
        test.assert_equal('Initial', renderer.text)
        control.tooltip = 'Updated'
        agent:update()
        test.assert_equal('Updated', renderer.text)
        control.tooltip = ''
        agent:update()
        test.assert_nil(renderer.text)
        test.assert_equal(3, mouse.samples)
    end)

    test.case('tooltip agent: targets a native widget declared with static text', function()
        local mouse = {x=2, y=2, samples=0}
        local TooltipAgent = load_agent(mouse).TooltipAgent
        local widgets = native_widgets()
        local button = widgets.TextButton{tooltip='Native static tooltip', visible=true,
            active=true, subviews={}}
        widget_harness.set_frame(button, 1, 1, 4, 4)
        local renderer = {set_tooltip=function(self, text) self.text = text end}
        local agent = TooltipAgent.new(root({button}), renderer)

        agent:update()
        test.assert_equal('target', agent.pointer_context.result.kind)
        test.assert_equal(button, agent.pointer_context.target)
        test.assert_equal('Native static tooltip', renderer.text)
    end)

    test.case('tooltip agent: presents terminal-owned dynamic text after pointer update', function()
        local mouse = {x=2, y=2, samples=0}
        local TooltipAgent = load_agent(mouse).TooltipAgent
        local renderer = {set_tooltip=function(self, text) self.text = text end}
        local control = target(1, 1, nil)
        control.on_pointer_update=function(target_view, x, y)
            target_view.tooltip = ('Local %d,%d'):format(x, y)
        end
        local agent = TooltipAgent.new(root({control}), renderer)

        agent:update()
        test.assert_equal('Local 1,1', renderer.text)
    end)

    test.case('tooltip agent: hides for blocked and excluded targets without parent fallback', function()
        local mouse = {x=2, y=2, samples=0}
        local TooltipAgent = load_agent(mouse).TooltipAgent
        local renderer = {set_tooltip=function(self, text) self.text = text end}
        local parent = target(1, 1, 'Parent must not be used')
        local child = target(1, 1, nil)
        parent.pointer_policy = 'pass'
        parent.subviews = {child}
        local agent = TooltipAgent.new(root({parent}), renderer)
        agent:update()
        test.assert_nil(renderer.text)

        parent.pointer_policy = 'block'
        parent.subviews = {}
        agent:update()
        test.assert_nil(renderer.text)

        parent.pointer_policy = 'none'
        agent:update()
        test.assert_nil(renderer.text)
    end)

    test.case('tooltip agent: rejects invalid text and keeps root state isolated', function()
        local first_mouse = {x=2, y=2, samples=0}
        local second_mouse = {x=2, y=2, samples=0}
        local First = load_agent(first_mouse).TooltipAgent
        local Second = load_agent(second_mouse).TooltipAgent
        local first_renderer = {set_tooltip=function(self, text) self.text = text end}
        local second_renderer = {set_tooltip=function(self, text) self.text = text end}
        local invalid = target(1, 1, function() return 'never invoke' end)
        local valid = target(1, 1, 'Second root')
        local first = First.new(root({invalid}), first_renderer)
        local second = Second.new(root({valid}), second_renderer)

        local ok, err = pcall(function() first:update() end)
        test.assert_false(ok)
        test.assert_true(tostring(err):find('tooltip must be a string', 1, true) ~= nil)
        second:update()
        test.assert_equal('Second root', second_renderer.text)
        test.assert_nil(first_renderer.text)
    end)
end
