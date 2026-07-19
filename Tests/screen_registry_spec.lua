local soulsearch_env = require('support.soulsearch_env')

local function screen(l, t, w, h)
    return {window={frame={l=l, t=t, w=w, h=h}}}
end

local repo_root = require('support.repo_root')

describe('screen registry', function()

    local registry = soulsearch_env.load_screen_registry(repo_root)

    it('screen registry: add is unique and snapshots are isolated', function()
        registry.clear()
        local first, second = screen(1, 2, 20, 10), screen(3, 4, 20, 10)
        assert.is_truthy(registry.add(first))
        assert.is_falsy(registry.add(first))
        assert.is_truthy(registry.add(second))
        assert.are.equal(2, registry.count())
        assert.is_truthy(registry.contains(first))
        local snapshot = registry.snapshot()
        table.remove(snapshot, 1)
        assert.are.equal(2, registry.count())
        local frames = registry.get_frames()
        frames[1].l = 99
        assert.are.equal(1, first.window.frame.l)
    end)

    it('screen registry: removal is idempotent and order independent', function()
        registry.clear()
        local first = screen(1, 1, 20, 10)
        local second = screen(2, 2, 20, 10)
        local third = screen(3, 3, 20, 10)
        registry.add(first)
        registry.add(second)
        registry.add(third)
        assert.is_truthy(registry.remove(second))
        assert.is_falsy(registry.remove(second))
        assert.are.equal(2, registry.count())
        assert.is_truthy(registry.contains(first))
        assert.is_truthy(registry.contains(third))
        assert.is_truthy(registry.remove(first))
        assert.is_truthy(registry.remove(third))
        assert.are.equal(0, registry.count())
    end)

    it('screen registry: snapshot iteration tolerates registry mutation', function()
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

        assert.are.equal(3, #visited)
        assert.is_truthy(visited[1] == first)
        assert.is_truthy(visited[2] == second)
        assert.is_truthy(visited[3] == third)
        assert.are.equal(1, registry.count())
        assert.is_truthy(registry.contains(added_during_iteration))
    end)

    it('screen registry: overlapping frames cascade diagonally', function()
        registry.clear()
        local base = {l=10, t=10, w=60, h=30}
        local first = registry.place_frame(base, 100, 50)
        assert.are.equal(10, first.l)
        assert.are.equal(10, first.t)
        registry.add(screen(first.l, first.t, first.w, first.h))
        local second = registry.place_frame(base, 100, 50)
        assert.are.equal(12, second.l)
        assert.are.equal(12, second.t)
        registry.add(screen(second.l, second.t, second.w, second.h))
        local third = registry.place_frame(base, 100, 50)
        assert.are.equal(14, third.l)
        assert.are.equal(14, third.t)
        assert.are.equal(10, base.l)
        assert.are.equal(10, base.t)
    end)

    it('screen registry: cascade wraps within screen bounds', function()
        registry.clear()
        registry.add(screen(40, 20, 60, 30))
        local placed = registry.place_frame(
            {l=40, t=20, w=60, h=30}, 100, 50)
        assert.are.equal(1, placed.l)
        assert.are.equal(1, placed.t)
        assert.is_truthy(placed.l + placed.w <= 100)
        assert.is_truthy(placed.t + placed.h <= 50)
    end)

    it('screen registry: teardown-only screens do not affect placement', function()
        registry.clear()
        local popover = screen(10, 10, 60, 30)
        popover.exclude_from_placement = true
        registry.add(popover)
        local placed = registry.place_frame({l=10, t=10, w=60, h=30}, 100, 50)
        assert.are.equal(10, placed.l)
        assert.are.equal(10, placed.t)
    end)

end)