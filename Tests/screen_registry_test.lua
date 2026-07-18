local soulsearch_env = require('support.soulsearch_env')

local function screen(l, t, w, h)
    return {window={frame={l=l, t=t, w=w, h=h}}}
end

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local registry = soulsearch_env.load_screen_registry(repo_root)

    add_test('screen registry: add is unique and snapshots are isolated', function()
        registry.clear()
        local first, second = screen(1, 2, 20, 10), screen(3, 4, 20, 10)
        luaunit.assertEvalToTrue(registry.add(first))
        luaunit.assertEvalToFalse(registry.add(first))
        luaunit.assertEvalToTrue(registry.add(second))
        luaunit.assertIs(2, registry.count())
        luaunit.assertEvalToTrue(registry.contains(first))
        local snapshot = registry.snapshot()
        table.remove(snapshot, 1)
        luaunit.assertIs(2, registry.count())
        local frames = registry.get_frames()
        frames[1].l = 99
        luaunit.assertIs(1, first.window.frame.l)
    end)

    add_test('screen registry: removal is idempotent and order independent', function()
        registry.clear()
        local first = screen(1, 1, 20, 10)
        local second = screen(2, 2, 20, 10)
        local third = screen(3, 3, 20, 10)
        registry.add(first)
        registry.add(second)
        registry.add(third)
        luaunit.assertEvalToTrue(registry.remove(second))
        luaunit.assertEvalToFalse(registry.remove(second))
        luaunit.assertIs(2, registry.count())
        luaunit.assertEvalToTrue(registry.contains(first))
        luaunit.assertEvalToTrue(registry.contains(third))
        luaunit.assertEvalToTrue(registry.remove(first))
        luaunit.assertEvalToTrue(registry.remove(third))
        luaunit.assertIs(0, registry.count())
    end)

    add_test('screen registry: snapshot iteration tolerates registry mutation', function()
        registry.clear()
        local first = screen(1, 1, 20, 10)
        local second = screen(2, 2, 20, 10)
        local third = screen(3, 3, 20, 10)
        local added_during_iteration = screen(4, 4, 20, 10)
        registry.add(first)
        registry.add(second)
        registry.add(third)

        local visited = {}
        registry.for_each_snapshot(function(active)
            table.insert(visited, active)
            registry.remove(active)
            if active == first then
                registry.remove(third)
                registry.add(added_during_iteration)
            end
        end)

        luaunit.assertIs(3, #visited)
        luaunit.assertEvalToTrue(visited[1] == first)
        luaunit.assertEvalToTrue(visited[2] == second)
        luaunit.assertEvalToTrue(visited[3] == third)
        luaunit.assertIs(1, registry.count())
        luaunit.assertEvalToTrue(registry.contains(added_during_iteration))
    end)

    add_test('screen registry: overlapping frames cascade diagonally', function()
        registry.clear()
        local base = {l=10, t=10, w=60, h=30}
        local first = registry.place_frame(base, 100, 50)
        luaunit.assertIs(10, first.l)
        luaunit.assertIs(10, first.t)
        registry.add(screen(first.l, first.t, first.w, first.h))
        local second = registry.place_frame(base, 100, 50)
        luaunit.assertIs(12, second.l)
        luaunit.assertIs(12, second.t)
        registry.add(screen(second.l, second.t, second.w, second.h))
        local third = registry.place_frame(base, 100, 50)
        luaunit.assertIs(14, third.l)
        luaunit.assertIs(14, third.t)
        luaunit.assertIs(10, base.l)
        luaunit.assertIs(10, base.t)
    end)

    add_test('screen registry: cascade wraps within screen bounds', function()
        registry.clear()
        registry.add(screen(40, 20, 60, 30))
        local placed = registry.place_frame(
            {l=40, t=20, w=60, h=30}, 100, 50)
        luaunit.assertIs(1, placed.l)
        luaunit.assertIs(1, placed.t)
        luaunit.assertEvalToTrue(placed.l + placed.w <= 100)
        luaunit.assertEvalToTrue(placed.t + placed.h <= 50)
    end)

    add_test('screen registry: teardown-only screens do not affect placement', function()
        registry.clear()
        local popover = screen(10, 10, 60, 30)
        popover.exclude_from_placement = true
        registry.add(popover)
        local placed = registry.place_frame({l=10, t=10, w=60, h=30}, 100, 50)
        luaunit.assertIs(10, placed.l)
        luaunit.assertIs(10, placed.t)
    end)

return native_tests
