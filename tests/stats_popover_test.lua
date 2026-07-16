local env = require('support.soulsearch_env')

local function deployment(config, button, direction)
    return {button=button, direction=direction}
end

return function(test, root)
    test.case('stats popout config: derives native and screen-relative usable frames', function()
        local _, config = env.load_stats_popover(root)
        local minimum = config.get_minimum()
        local outside_left = deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_LEFT, config.DIRECTION.LEFT)
        local resolved = assert(config.resolve(
            120, 40, {x1=60, x2=119, y1=5, y2=35}, {outside_left}))
        test.assert_equal(23, resolved.panel.l)
        test.assert_equal(0, resolved.panel.t)
        test.assert_equal(56, resolved.button.l)
        test.assert_equal(20, resolved.button.t)
        test.assert_equal(resolved.button.l + resolved.button.w,
            resolved.panel.l + resolved.panel.w)
        test.assert_equal(config.DIRECTION.LEFT, resolved.direction)

        local below = assert(config.resolve(
            120, 40, {x1=60, x2=119, y1=0, y2=20}, {outside_left}))
        test.assert_equal(below.button.t + below.button.h, below.panel.t)
        local missing, err = config.resolve(
            minimum.w - 1, minimum.h, nil, {outside_left})
        test.assert_equal(nil, missing)
        test.assert_true(err:find('at least', 1, true) ~= nil)

        local outside_right = deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_RIGHT, config.DIRECTION.RIGHT)
        resolved = assert(config.resolve(
            120, 40, {x1=10, x2=70, y1=5, y2=35},
            {outside_right}))
        test.assert_equal(72, resolved.button.l)
        test.assert_equal(72, resolved.panel.l)
        test.assert_equal(0, resolved.panel.t)

        local missing_rect, missing_rect_err = config.resolve(
            120, 40, nil, {outside_left})
        test.assert_equal(nil, missing_rect)
        test.assert_true(missing_rect_err:find('outer unit%-card bounds') ~= nil)
    end)

    test.case('stats popout config: tries placement fallbacks in order', function()
        local _, config = env.load_stats_popover(root)
        local card = {x1=50, x2=119, y1=5, y2=35}
        local outside_right = deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_RIGHT, config.DIRECTION.RIGHT)
        local outside_left = deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_LEFT, config.DIRECTION.LEFT)
        local resolved, _, source = config.resolve(
            120, 40, card, {outside_right, outside_left})
        test.assert_equal(46, resolved.button.l)
        test.assert_equal(13, resolved.panel.l)
        test.assert_equal(0, resolved.panel.t)
        test.assert_true(source:find('outside%-left') ~= nil)

        local inside_right_up = deployment(config,
            config.BUTTON_PLACEMENT.INSIDE_RIGHT, config.DIRECTION.UP)
        resolved = assert(config.resolve(
            120, 60, {x1=40, x2=100, y1=25, y2=59}, {inside_right_up}))
        test.assert_equal(98, resolved.button.l)
        test.assert_equal(25, resolved.button.t)
        test.assert_equal(65, resolved.panel.l)
        test.assert_equal(5, resolved.panel.t)

        local inside_left_down = deployment(config,
            config.BUTTON_PLACEMENT.INSIDE_LEFT, config.DIRECTION.DOWN)
        resolved = assert(config.resolve(
            120, 60, {x1=40, x2=100, y1=0, y2=30}, {inside_left_down}))
        test.assert_equal(40, resolved.button.l)
        test.assert_equal(30, resolved.button.t)
        test.assert_equal(40, resolved.panel.l)
        test.assert_equal(31, resolved.panel.t)
    end)

    test.case('stats popout config: rejects malformed placement lists', function()
        local _, config = env.load_stats_popover(root)
        test.assert_false(pcall(config.resolve, 120, 40, nil, {}))
        test.assert_false(pcall(config.resolve, 120, 40, nil, {'beside-ish'}))
        test.assert_false(pcall(config.resolve, 120, 40, nil, {{
            button='beside-ish', direction=config.DIRECTION.LEFT}}))
        test.assert_false(pcall(config.resolve, 120, 40, nil, {{
            button=config.BUTTON_PLACEMENT.OUTSIDE_LEFT, direction=config.DIRECTION.UP}}))
        test.assert_false(pcall(config.resolve, 120, 40, nil, {{
            button=config.BUTTON_PLACEMENT.INSIDE_LEFT, direction=config.DIRECTION.LEFT}}))
        test.assert_false(pcall(config.resolve, 120, 40, nil,
            {[1]=deployment(config, config.BUTTON_PLACEMENT.OUTSIDE_LEFT,
                config.DIRECTION.LEFT), preferred='anything'}))
    end)

    test.case('stats popout config: reverse-computes a button from a positioned panel', function()
        local _, config = env.load_stats_popover(root)
        local placements = {deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_LEFT, config.DIRECTION.LEFT)}
        local card = {x1=50, x2=120, y1=30, y2=70}

        local resolved = assert(config.resolve(
            180, 120, card, placements, {l=10, t=20}))
        test.assert_equal(config.DIRECTION.DOWN, resolved.direction)
        test.assert_equal(resolved.button.l + resolved.button.w,
            resolved.panel.l + resolved.panel.w)
        test.assert_equal(resolved.button.t + resolved.button.h, resolved.panel.t)
        test.assert_equal(10, resolved.panel.l)
        test.assert_equal(20, resolved.panel.t)

        resolved = assert(config.resolve(
            180, 120, card, placements, {l=125, t=20}))
        test.assert_equal(config.DIRECTION.DOWN, resolved.direction)
        test.assert_equal(resolved.button.l, resolved.panel.l)

        resolved = assert(config.resolve(
            180, 120, card, placements, {l=60, t=0}))
        test.assert_equal(config.DIRECTION.UP, resolved.direction)
        test.assert_equal(resolved.button.t, resolved.panel.t + resolved.panel.h)
    end)

    test.case('stats popout: resolves a subject for the attached overlay', function()
        local unit={id=10}
        local popover, _, _, state = env.load_stats_popover(root, {units={[10]=unit}})
        local subject = assert(popover.get_subject(unit))
        test.assert_equal(unit, subject.unit)
        test.assert_equal(10, subject.unit_id)
        test.assert_equal(1, state.collects)
    end)

    test.case('stats popout: validates current units before collection', function()
        local popover, _, _, state = env.load_stats_popover(root)
        local subject, err = popover.get_subject({id=8})
        test.assert_equal(nil, subject)
        test.assert_equal('SoulSearch requires a current unit.', err)
        test.assert_equal(0, state.collects)
    end)

    test.case('stats popout: unavailable context takes precedence', function()
        local popover, _, _, state = env.load_stats_popover(root,
            {unavailable_reason='SoulSearch only works in fortress mode.'})
        local subject, err = popover.get_subject('not a unit')
        test.assert_equal(nil, subject)
        test.assert_equal('SoulSearch only works in fortress mode.', err)
        test.assert_equal(0, state.collects)
    end)
end
