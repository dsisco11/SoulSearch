local soulsearch_env = require('support.soulsearch_env')
local widget_harness = require('support.widget_harness')

local repo_root = require('support.repo_root')

describe('pointer dispatcher', function()

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

    it('pointer dispatcher: policies, reverse overlap, and local coordinates', function()
        local dispatcher = load_dispatcher()
        local lower = view('target', 2, 2, 5, 5)
        local upper = view('target', 3, 3, 5, 5)
        local panel = view('pass', 0, 0, 12, 12, {lower, upper})
        local root = view('target', 0, 0, 20, 20, {panel})
        local context = dispatcher.PointerContext.new(root)

        local result = dispatcher.PointerDispatcher.sample(context, 4, 4)
        assert.are.equal('target', result.kind)
        assert.are.equal(upper, result.target)
        assert.are.equal(1, result.x)
        assert.are.equal(1, result.y)

        result = dispatcher.PointerDispatcher.sample(context, 1, 1)
        assert.are.equal('miss', result.kind)
        assert.is_nil(context.target)

        panel.pointer_policy = 'target'
        result = dispatcher.PointerDispatcher.sample(context, 1, 1)
        assert.are.equal(panel, result.target)
        panel.pointer_policy = 'block'
        result = dispatcher.PointerDispatcher.sample(context, 1, 1)
        assert.are.equal('blocked', result.kind)
        assert.are.equal(panel, result.blocker)
    end)

    it('pointer dispatcher: target controls retain ownership over implementation children', function()
        local dispatcher = load_dispatcher()
        local implementation_child = view('target', 2, 2, 6, 2)
        local control = view('target', 1, 1, 8, 4, {implementation_child})
        local root = view('target', 0, 0, 12, 8, {control})
        local result = dispatcher.PointerDispatcher.sample(
            dispatcher.PointerContext.new(root), 3, 3)

        assert.are.equal('target', result.kind)
        assert.are.equal(control, result.target)
        assert.are.equal(2, result.x)
        assert.are.equal(2, result.y)
    end)

    it('pointer dispatcher: windows block frames while preserving child targets', function()
        local dispatcher = load_dispatcher()
        local behind = view('target', 0, 0, 20, 20)
        local child = view('target', 4, 4, 3, 3)
        local window = view('block', 2, 2, 10, 10, {child})
        window.frame_body = widget_harness.rect(3, 3, 8, 8)
        local root = view('target', 0, 0, 20, 20, {behind, window})
        local context = dispatcher.PointerContext.new(root)

        local result = dispatcher.PointerDispatcher.sample(context, 4, 4)
        assert.are.equal(child, result.target)
        result = dispatcher.PointerDispatcher.sample(context, 2, 2)
        assert.are.equal('blocked', result.kind)
        assert.are.equal(window, result.blocker)
        result = dispatcher.PointerDispatcher.sample(context, 15, 15)
        assert.are.equal(behind, result.target)
    end)

    it('pointer dispatcher: clipping, eligibility, none, and root isolation', function()
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
        assert.are.equal(behind, result.target)
        clipped.tooltip = 'Visible text must not affect targeting'
        result = dispatcher.PointerDispatcher.sample(context, 6, 2)
        assert.are.equal(behind, result.target)
        clipped.tooltip = nil
        result = dispatcher.PointerDispatcher.sample(context, 11, 2)
        assert.are.equal(behind, result.target)
        clipped.visible = false
        result = dispatcher.PointerDispatcher.sample(context, 2, 2)
        assert.are.equal(behind, result.target)

        local second_target = view('target', 0, 0, 20, 20)
        local second = view('target', 0, 0, 20, 20, {second_target})
        local second_context = dispatcher.PointerContext.new(second)
        result = dispatcher.PointerDispatcher.sample(second_context, 2, 2)
        assert.are.equal(second_target, result.target)
        assert.are.equal(behind, context.target)
    end)

    it('pointer dispatcher: evaluated ancestors and one mouse sample clear targets', function()
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
        assert.are.equal(target, result.target)
        hidden_parent.active = function() return false end
        result = dispatcher.PointerDispatcher.sample(context, 3, 3)
        assert.are.equal('miss', result.kind)
        assert.is_nil(context.target)
        result = dispatcher.PointerDispatcher.sample(context)
        assert.are.equal('miss', result.kind)
        assert.are.equal(1, mouse_samples)
    end)

    it('pointer dispatcher: transitions update terminal widgets and clear removed targets', function()
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
        assert.are.equal('enter', events[1][1])
        assert.are.equal(1, events[1][3])
        assert.are.equal(2, events[1][4])
        assert.are.equal('update', events[2][1])
        assert.are.equal('update', events[3][1])
        assert.are.equal('leave', events[4][1])
        assert.is_nil(context.target)
        assert.are.equal('miss', context.result.kind)
    end)

    it('pointer dispatcher: nested modal blocks only its own frame', function()
        local dispatcher = load_dispatcher()
        local filter = view('block', 1, 1, 16, 16)
        local picker = view('block', 5, 5, 6, 6)
        filter.subviews = {picker}
        local root = view('target', 0, 0, 20, 20, {filter})
        local context = dispatcher.PointerContext.new(root)

        local result = dispatcher.PointerDispatcher.sample(context, 6, 6)
        assert.are.equal('blocked', result.kind)
        assert.are.equal(picker, result.blocker)
        result = dispatcher.PointerDispatcher.sample(context, 3, 3)
        assert.are.equal('blocked', result.kind)
        assert.are.equal(filter, result.blocker)
    end)

end)