local soulsearch_env = require('support.soulsearch_env')
local widget_harness = require('support.widget_harness')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local function load_dispatcher(mouse_pos)
        return soulsearch_env.load_pointer_dispatcher(repo_root, {
            screen={getMousePos=mouse_pos or function() return nil end},
        })
    end

    local function view(policy, x, y, width, height, children)
        local result = {
            pointer_policy=policy,
            visible=true,
            active=true,
            subviews=children or {},
        }
        return widget_harness.set_frame(result, x, y, width, height)
    end

    add_test('pointer dispatcher: policies, reverse overlap, and local coordinates', function()
        local dispatcher = load_dispatcher()
        local lower = view('target', 2, 2, 5, 5)
        local upper = view('target', 3, 3, 5, 5)
        local panel = view('pass', 0, 0, 12, 12, {lower, upper})
        local root = view('target', 0, 0, 20, 20, {panel})
        local context = dispatcher.PointerContext.new(root)

        local result = dispatcher.PointerDispatcher.sample(context, 4, 4)
        luaunit.assertIs('target', result.kind)
        luaunit.assertIs(upper, result.target)
        luaunit.assertIs(1, result.x)
        luaunit.assertIs(1, result.y)

        result = dispatcher.PointerDispatcher.sample(context, 1, 1)
        luaunit.assertIs('miss', result.kind)
        luaunit.assertNil(context.target)

        panel.pointer_policy = 'target'
        result = dispatcher.PointerDispatcher.sample(context, 1, 1)
        luaunit.assertIs(panel, result.target)
        panel.pointer_policy = 'block'
        result = dispatcher.PointerDispatcher.sample(context, 1, 1)
        luaunit.assertIs('blocked', result.kind)
        luaunit.assertIs(panel, result.blocker)
    end)

    add_test('pointer dispatcher: target controls retain ownership over implementation children', function()
        local dispatcher = load_dispatcher()
        local implementation_child = view('target', 2, 2, 6, 2)
        local control = view('target', 1, 1, 8, 4, {implementation_child})
        local root = view('target', 0, 0, 12, 8, {control})
        local result = dispatcher.PointerDispatcher.sample(
            dispatcher.PointerContext.new(root), 3, 3)

        luaunit.assertIs('target', result.kind)
        luaunit.assertIs(control, result.target)
        luaunit.assertIs(2, result.x)
        luaunit.assertIs(2, result.y)
    end)

    add_test('pointer dispatcher: windows block frames while preserving child targets', function()
        local dispatcher = load_dispatcher()
        local behind = view('target', 0, 0, 20, 20)
        local child = view('target', 4, 4, 3, 3)
        local window = view('block', 2, 2, 10, 10, {child})
        window.frame_body = widget_harness.rect(3, 3, 8, 8)
        local root = view('target', 0, 0, 20, 20, {behind, window})
        local context = dispatcher.PointerContext.new(root)

        local result = dispatcher.PointerDispatcher.sample(context, 4, 4)
        luaunit.assertIs(child, result.target)
        result = dispatcher.PointerDispatcher.sample(context, 2, 2)
        luaunit.assertIs('blocked', result.kind)
        luaunit.assertIs(window, result.blocker)
        result = dispatcher.PointerDispatcher.sample(context, 15, 15)
        luaunit.assertIs(behind, result.target)
    end)

    add_test('pointer dispatcher: clipping, eligibility, none, and root isolation', function()
        local dispatcher = load_dispatcher()
        local clipped = view('target', 1, 1, 8, 8)
        clipped.frame_body = widget_harness.rect(1, 1, 8, 8,
            {x1=1, y1=1, x2=4, y2=8})
        local excluded_child = view('target', 10, 1, 5, 5)
        local excluded = view('none', 10, 1, 5, 5, {excluded_child})
        local behind = view('target', 0, 0, 20, 20)
        local root = view('target', 0, 0, 20, 20, {behind, clipped, excluded})
        local context = dispatcher.PointerContext.new(root)

        local result = dispatcher.PointerDispatcher.sample(context, 6, 2)
        luaunit.assertIs(behind, result.target)
        clipped.tooltip = 'Visible text must not affect targeting'
        result = dispatcher.PointerDispatcher.sample(context, 6, 2)
        luaunit.assertIs(behind, result.target)
        clipped.tooltip = nil
        result = dispatcher.PointerDispatcher.sample(context, 11, 2)
        luaunit.assertIs(behind, result.target)
        clipped.visible = false
        result = dispatcher.PointerDispatcher.sample(context, 2, 2)
        luaunit.assertIs(behind, result.target)

        local second_target = view('target', 0, 0, 20, 20)
        local second = view('target', 0, 0, 20, 20, {second_target})
        local second_context = dispatcher.PointerContext.new(second)
        result = dispatcher.PointerDispatcher.sample(second_context, 2, 2)
        luaunit.assertIs(second_target, result.target)
        luaunit.assertIs(behind, context.target)
    end)

    add_test('pointer dispatcher: evaluated ancestors and one mouse sample clear targets', function()
        local mouse_samples = 0
        local dispatcher = load_dispatcher(function()
            mouse_samples = mouse_samples + 1
            return nil, nil
        end)
        local target = view('target', 2, 2, 4, 4)
        local hidden_parent = view('pass', 1, 1, 8, 8, {target})
        local root = view('target', 0, 0, 12, 12, {hidden_parent})
        local context = dispatcher.PointerContext.new(root)

        local result = dispatcher.PointerDispatcher.sample(context, 3, 3)
        luaunit.assertIs(target, result.target)
        hidden_parent.active = function() return false end
        result = dispatcher.PointerDispatcher.sample(context, 3, 3)
        luaunit.assertIs('miss', result.kind)
        luaunit.assertNil(context.target)
        result = dispatcher.PointerDispatcher.sample(context)
        luaunit.assertIs('miss', result.kind)
        luaunit.assertIs(1, mouse_samples)
    end)

    add_test('pointer dispatcher: transitions update terminal widgets and clear removed targets', function()
        local dispatcher = load_dispatcher()
        local events = {}
        local first = view('target', 1, 1, 4, 4)
        first.on_pointer_enter=function(target, x, y)
            table.insert(events, {'enter', target, x, y})
        end
        first.on_pointer_update=function(target, x, y)
            table.insert(events, {'update', target, x, y})
        end
        first.on_pointer_leave=function(target) table.insert(events, {'leave', target}) end
        local root = view('target', 0, 0, 10, 10, {first})
        local context = dispatcher.PointerContext.new(root)

        dispatcher.PointerDispatcher.sample(context, 2, 3)
        dispatcher.PointerDispatcher.sample(context, 3, 3)
        root.subviews = {}
        dispatcher.PointerDispatcher.sample(context, 2, 3)
        luaunit.assertIs('enter', events[1][1])
        luaunit.assertIs(1, events[1][3])
        luaunit.assertIs(2, events[1][4])
        luaunit.assertIs('update', events[2][1])
        luaunit.assertIs('update', events[3][1])
        luaunit.assertIs('leave', events[4][1])
        luaunit.assertNil(context.target)
        luaunit.assertIs('miss', context.result.kind)
    end)

    add_test('pointer dispatcher: nested modal blocks only its own frame', function()
        local dispatcher = load_dispatcher()
        local filter = view('block', 1, 1, 16, 16)
        local picker = view('block', 5, 5, 6, 6)
        filter.subviews = {picker}
        local root = view('target', 0, 0, 20, 20, {filter})
        local context = dispatcher.PointerContext.new(root)

        local result = dispatcher.PointerDispatcher.sample(context, 6, 6)
        luaunit.assertIs('blocked', result.kind)
        luaunit.assertIs(picker, result.blocker)
        result = dispatcher.PointerDispatcher.sample(context, 3, 3)
        luaunit.assertIs('blocked', result.kind)
        luaunit.assertIs(filter, result.blocker)
    end)

return native_tests
