local env = require('support.soulsearch_env')

local function deployment(config, button, direction)
    return {button=button, direction=direction}
end

local root = require('support.repo_root')

describe('stats popover', function()

    it('stats popout config: derives native and screen-relative usable frames', function()
        local _, config = env.load_stats_popover(root)
        local minimum = config.get_minimum()
        local outside_left = deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_LEFT, config.DIRECTION.LEFT)
        local resolved = assert(config.resolve(
            120, 40, {x1=60, x2=119, y1=5, y2=35}, {outside_left}))
        assert.are.equal(23, resolved.panel.l)
        assert.are.equal(0, resolved.panel.t)
        assert.are.equal(56, resolved.button.l)
        assert.are.equal(20, resolved.button.t)
        assert.are.equal(resolved.button.l + resolved.button.w,
            resolved.panel.l + resolved.panel.w)
        assert.are.equal(config.DIRECTION.LEFT, resolved.direction)

        local below = assert(config.resolve(
            120, 40, {x1=60, x2=119, y1=0, y2=20}, {outside_left}))
        assert.are.equal(below.button.t + below.button.h, below.panel.t)
        local missing, err = config.resolve(
            minimum.w - 1, minimum.h, nil, {outside_left})
        assert.are.equal(nil, missing)
        assert.is_truthy(err:find('at least', 1, true) ~= nil)

        local outside_right = deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_RIGHT, config.DIRECTION.RIGHT)
        resolved = assert(config.resolve(
            120, 40, {x1=10, x2=70, y1=5, y2=35},
            {outside_right}))
        assert.are.equal(72, resolved.button.l)
        assert.are.equal(72, resolved.panel.l)
        assert.are.equal(0, resolved.panel.t)

        local missing_rect, missing_rect_err = config.resolve(
            120, 40, nil, {outside_left})
        assert.are.equal(nil, missing_rect)
        assert.is_truthy(missing_rect_err:find('outer unit%-card bounds') ~= nil)
    end)

    it('stats popout config: tries placement fallbacks in order', function()
        local _, config = env.load_stats_popover(root)
        local card = {x1=50, x2=119, y1=5, y2=35}
        local outside_right = deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_RIGHT, config.DIRECTION.RIGHT)
        local outside_left = deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_LEFT, config.DIRECTION.LEFT)
        local resolved, _, source = config.resolve(
            120, 40, card, {outside_right, outside_left})
        assert.are.equal(46, resolved.button.l)
        assert.are.equal(13, resolved.panel.l)
        assert.are.equal(0, resolved.panel.t)
        assert.is_truthy(source:find('outside%-left') ~= nil)

        local inside_right_up = deployment(config,
            config.BUTTON_PLACEMENT.INSIDE_RIGHT, config.DIRECTION.UP)
        resolved = assert(config.resolve(
            120, 60, {x1=40, x2=100, y1=25, y2=59}, {inside_right_up}))
        assert.are.equal(98, resolved.button.l)
        assert.are.equal(25, resolved.button.t)
        assert.are.equal(65, resolved.panel.l)
        assert.are.equal(5, resolved.panel.t)

        local inside_left_down = deployment(config,
            config.BUTTON_PLACEMENT.INSIDE_LEFT, config.DIRECTION.DOWN)
        resolved = assert(config.resolve(
            120, 60, {x1=40, x2=100, y1=0, y2=30}, {inside_left_down}))
        assert.are.equal(40, resolved.button.l)
        assert.are.equal(30, resolved.button.t)
        assert.are.equal(40, resolved.panel.l)
        assert.are.equal(31, resolved.panel.t)
    end)

    it('stats popout config: rejects malformed placement lists', function()
        local _, config = env.load_stats_popover(root)
        assert.is_falsy(pcall(config.resolve, 120, 40, nil, {}))
        assert.is_falsy(pcall(config.resolve, 120, 40, nil, {'beside-ish'}))
        assert.is_falsy(pcall(config.resolve, 120, 40, nil, {{
            button='beside-ish', direction=config.DIRECTION.LEFT}}))
        assert.is_falsy(pcall(config.resolve, 120, 40, nil, {{
            button=config.BUTTON_PLACEMENT.OUTSIDE_LEFT, direction=config.DIRECTION.UP}}))
        assert.is_falsy(pcall(config.resolve, 120, 40, nil, {{
            button=config.BUTTON_PLACEMENT.INSIDE_LEFT, direction=config.DIRECTION.LEFT}}))
        assert.is_falsy(pcall(config.resolve, 120, 40, nil,
            {[1]=deployment(config, config.BUTTON_PLACEMENT.OUTSIDE_LEFT,
                config.DIRECTION.LEFT), preferred='anything'}))
    end)

    it('stats popout config: keeps a positioned panel authoritative', function()
        local _, config = env.load_stats_popover(root)
        local placements = {deployment(config,
            config.BUTTON_PLACEMENT.OUTSIDE_LEFT, config.DIRECTION.LEFT)}
        local card = {x1=50, x2=120, y1=30, y2=70}

        local resolved = assert(config.resolve(
            180, 120, card, placements, {l=10, t=20}))
        assert.are.equal(config.DIRECTION.LEFT, resolved.direction)
        assert.are.equal(resolved.button.l + resolved.button.w,
            resolved.panel.l + resolved.panel.w)
        assert.are.equal(10, resolved.panel.l)
        assert.are.equal(20, resolved.panel.t)
        assert.are.equal(19, resolved.button.t)

        resolved = assert(config.resolve(
            180, 120, card, placements, {l=125, t=20}))
        assert.are.equal(config.DIRECTION.RIGHT, resolved.direction)
        assert.are.equal(resolved.button.l, resolved.panel.l)

        resolved = assert(config.resolve(
            180, 120, card, placements, {l=60, t=5}))
        assert.are.equal(config.DIRECTION.UP, resolved.direction)
        assert.are.equal(4, resolved.button.t)

        resolved = assert(config.resolve(
            180, 120, card, placements, {l=60, t=80}))
        assert.are.equal(config.DIRECTION.DOWN, resolved.direction)
        assert.are.equal(79, resolved.button.t)

        resolved = assert(config.resolve(
            180, 120, nil, placements, {l=10, t=20}))
        assert.are.equal(10, resolved.panel.l)
        assert.are.equal(20, resolved.panel.t)
        assert.are.equal(19, resolved.button.t)

        resolved = assert(config.resolve(
            180, 120, card, placements, {l=60, t=0}))
        assert.are.equal(config.DIRECTION.UP, resolved.direction)
        assert.are.equal(resolved.panel.t + resolved.panel.h, resolved.button.t)
    end)

    it('stats popout: resolves a subject for the attached overlay', function()
        local unit={id=10}
        local popover, _, _, state = env.load_stats_popover(root, {units={[10]=unit}})
        local subject = assert(popover.get_subject(unit))
        assert.are.equal(unit, subject.unit)
        assert.are.equal(10, subject.unit_id)
        assert.are.equal(1, state.collects)
    end)

    it('stats popout: validates current units before collection', function()
        local popover, _, _, state = env.load_stats_popover(root)
        local subject, err = popover.get_subject({id=8})
        assert.are.equal(nil, subject)
        assert.are.equal('SoulSearch requires a current unit.', err)
        assert.are.equal(0, state.collects)
    end)

    it('stats popout: unavailable context takes precedence', function()
        local popover, _, _, state = env.load_stats_popover(root,
            {unavailable_reason='SoulSearch only works in fortress mode.'})
        local subject, err = popover.get_subject('not a unit')
        assert.are.equal(nil, subject)
        assert.are.equal('SoulSearch only works in fortress mode.', err)
        assert.are.equal(0, state.collects)
    end)

end)
