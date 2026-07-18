local env = require('support.soulsearch_env')

local function deployment(config, button, direction)
    return {button=button, direction=direction}
end

local luaunit = require('luaunit')
local root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('stats popout config: derives native and screen-relative usable frames', function()
        local _, config = env.load_stats_popover(root)
        local minimum = config.get_minimum()
        local outside_left = deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_LEFT, config.DIRECTION.LEFT)
        local resolved = assert(config.resolve(
            120, 40, {x1=60, x2=119, y1=5, y2=35}, {outside_left}))
        luaunit.assertIs(23, resolved.panel.l)
        luaunit.assertIs(0, resolved.panel.t)
        luaunit.assertIs(56, resolved.button.l)
        luaunit.assertIs(20, resolved.button.t)
        luaunit.assertIs(resolved.button.l + resolved.button.w,
            resolved.panel.l + resolved.panel.w)
        luaunit.assertIs(config.DIRECTION.LEFT, resolved.direction)

        local below = assert(config.resolve(
            120, 40, {x1=60, x2=119, y1=0, y2=20}, {outside_left}))
        luaunit.assertIs(below.button.t + below.button.h, below.panel.t)
        local missing, err = config.resolve(
            minimum.w - 1, minimum.h, nil, {outside_left})
        luaunit.assertIs(nil, missing)
        luaunit.assertEvalToTrue(err:find('at least', 1, true) ~= nil)

        local outside_right = deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_RIGHT, config.DIRECTION.RIGHT)
        resolved = assert(config.resolve(
            120, 40, {x1=10, x2=70, y1=5, y2=35},
            {outside_right}))
        luaunit.assertIs(72, resolved.button.l)
        luaunit.assertIs(72, resolved.panel.l)
        luaunit.assertIs(0, resolved.panel.t)

        local missing_rect, missing_rect_err = config.resolve(
            120, 40, nil, {outside_left})
        luaunit.assertIs(nil, missing_rect)
        luaunit.assertEvalToTrue(missing_rect_err:find('outer unit%-card bounds') ~= nil)
    end)

    add_test('stats popout config: tries placement fallbacks in order', function()
        local _, config = env.load_stats_popover(root)
        local card = {x1=50, x2=119, y1=5, y2=35}
        local outside_right = deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_RIGHT, config.DIRECTION.RIGHT)
        local outside_left = deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_LEFT, config.DIRECTION.LEFT)
        local resolved, _, source = config.resolve(
            120, 40, card, {outside_right, outside_left})
        luaunit.assertIs(46, resolved.button.l)
        luaunit.assertIs(13, resolved.panel.l)
        luaunit.assertIs(0, resolved.panel.t)
        luaunit.assertEvalToTrue(source:find('outside%-left') ~= nil)

        local inside_right_up = deployment(config,
            config.BUTTON_PLACEMENT.INSIDE_RIGHT, config.DIRECTION.UP)
        resolved = assert(config.resolve(
            120, 60, {x1=40, x2=100, y1=25, y2=59}, {inside_right_up}))
        luaunit.assertIs(98, resolved.button.l)
        luaunit.assertIs(25, resolved.button.t)
        luaunit.assertIs(65, resolved.panel.l)
        luaunit.assertIs(5, resolved.panel.t)

        local inside_left_down = deployment(config,
            config.BUTTON_PLACEMENT.INSIDE_LEFT, config.DIRECTION.DOWN)
        resolved = assert(config.resolve(
            120, 60, {x1=40, x2=100, y1=0, y2=30}, {inside_left_down}))
        luaunit.assertIs(40, resolved.button.l)
        luaunit.assertIs(30, resolved.button.t)
        luaunit.assertIs(40, resolved.panel.l)
        luaunit.assertIs(31, resolved.panel.t)
    end)

    add_test('stats popout config: rejects malformed placement lists', function()
        local _, config = env.load_stats_popover(root)
        luaunit.assertEvalToFalse(pcall(config.resolve, 120, 40, nil, {}))
        luaunit.assertEvalToFalse(pcall(config.resolve, 120, 40, nil, {'beside-ish'}))
        luaunit.assertEvalToFalse(pcall(config.resolve, 120, 40, nil, {{
            button='beside-ish', direction=config.DIRECTION.LEFT}}))
        luaunit.assertEvalToFalse(pcall(config.resolve, 120, 40, nil, {{
            button=config.BUTTON_PLACEMENT.OUTSIDE_LEFT, direction=config.DIRECTION.UP}}))
        luaunit.assertEvalToFalse(pcall(config.resolve, 120, 40, nil, {{
            button=config.BUTTON_PLACEMENT.INSIDE_LEFT, direction=config.DIRECTION.LEFT}}))
        luaunit.assertEvalToFalse(pcall(config.resolve, 120, 40, nil,
            {[1]=deployment(config, config.BUTTON_PLACEMENT.OUTSIDE_LEFT,
                config.DIRECTION.LEFT), preferred='anything'}))
    end)

    add_test('stats popout config: keeps a positioned panel authoritative', function()
        local _, config = env.load_stats_popover(root)
        local placements = {deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_LEFT, config.DIRECTION.LEFT)}
        local card = {x1=50, x2=120, y1=30, y2=70}

        local resolved = assert(config.resolve(
            180, 120, card, placements, {l=10, t=20}))
        luaunit.assertIs(config.DIRECTION.LEFT, resolved.direction)
        luaunit.assertIs(resolved.button.l + resolved.button.w,
            resolved.panel.l + resolved.panel.w)
        luaunit.assertIs(10, resolved.panel.l)
        luaunit.assertIs(20, resolved.panel.t)
        luaunit.assertIs(19, resolved.button.t)

        resolved = assert(config.resolve(
            180, 120, card, placements, {l=125, t=20}))
        luaunit.assertIs(config.DIRECTION.RIGHT, resolved.direction)
        luaunit.assertIs(resolved.button.l, resolved.panel.l)

        resolved = assert(config.resolve(
            180, 120, card, placements, {l=60, t=5}))
        luaunit.assertIs(config.DIRECTION.UP, resolved.direction)
        luaunit.assertIs(4, resolved.button.t)

        resolved = assert(config.resolve(
            180, 120, card, placements, {l=60, t=80}))
        luaunit.assertIs(config.DIRECTION.DOWN, resolved.direction)
        luaunit.assertIs(79, resolved.button.t)

        resolved = assert(config.resolve(
            180, 120, nil, placements, {l=10, t=20}))
        luaunit.assertIs(10, resolved.panel.l)
        luaunit.assertIs(20, resolved.panel.t)
        luaunit.assertIs(19, resolved.button.t)

        resolved = assert(config.resolve(
            180, 120, card, placements, {l=60, t=0}))
        luaunit.assertIs(config.DIRECTION.UP, resolved.direction)
        luaunit.assertIs(resolved.panel.t + resolved.panel.h, resolved.button.t)
    end)

    add_test('stats popout: resolves a subject for the attached overlay', function()
        local unit={id=10}
        local popover, _, _, state = env.load_stats_popover(root, {units={[10]=unit}})
        local subject = assert(popover.get_subject(unit))
        luaunit.assertIs(unit, subject.unit)
        luaunit.assertIs(10, subject.unit_id)
        luaunit.assertIs(1, state.collects)
    end)

    add_test('stats popout: validates current units before collection', function()
        local popover, _, _, state = env.load_stats_popover(root)
        local subject, err = popover.get_subject({id=8})
        luaunit.assertIs(nil, subject)
        luaunit.assertIs('SoulSearch requires a current unit.', err)
        luaunit.assertIs(0, state.collects)
    end)

    add_test('stats popout: unavailable context takes precedence', function()
        local popover, _, _, state = env.load_stats_popover(root,
            {unavailable_reason='SoulSearch only works in fortress mode.'})
        local subject, err = popover.get_subject('not a unit')
        luaunit.assertIs(nil, subject)
        luaunit.assertIs('SoulSearch only works in fortress mode.', err)
        luaunit.assertIs(0, state.collects)
    end)

return native_tests
