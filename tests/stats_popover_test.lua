local env = require('support.soulsearch_env')

return function(test, root)
    test.case('stats popout config: derives native and screen-relative usable frames', function()
        local _, config = env.load_stats_popover(root)
        local minimum = config.get_minimum()
        local minimum_card = {x1=minimum.w + config.UNIT_CARD_GAP,
            x2=minimum.w + config.UNIT_CARD_GAP, y1=0, y2=minimum.h - 1}
        local frame = assert(config.resolve(
            minimum.w, minimum.h, minimum_card, {config.PLACEMENT.OUTSIDE_LEFT}))
        test.assert_equal(0, frame.l)
        test.assert_equal(0, frame.t)
        local missing, err = config.resolve(
            minimum.w - 1, minimum.h, nil, {config.PLACEMENT.OUTSIDE_LEFT})
        test.assert_equal(nil, missing)
        test.assert_true(err:find('at least', 1, true) ~= nil)
        local native = assert(config.resolve(
            120, 40, {x1=10, x2=70, y1=5, y2=35},
            {config.PLACEMENT.OUTSIDE_RIGHT}))
        test.assert_equal(72, native.l)
        local left = assert(config.resolve(
            120, 40, {x1=50, x2=90, y1=5, y2=35},
            {config.PLACEMENT.OUTSIDE_LEFT}))
        test.assert_equal(50 - config.DEFAULT_WIDTH - config.UNIT_CARD_GAP, left.l)
        local missing_rect, missing_rect_err = config.resolve(
            120, 40, nil, {config.PLACEMENT.OUTSIDE_LEFT})
        test.assert_equal(nil, missing_rect)
        test.assert_true(missing_rect_err:find('outer unit%-card bounds') ~= nil)
    end)

    test.case('stats popout config: tries placement fallbacks in order', function()
        local _, config = env.load_stats_popover(root)
        local card = {x1=50, x2=119, y1=5, y2=35}
        local frame, _, source = config.resolve(
            120, 40, card,
            {config.PLACEMENT.OUTSIDE_RIGHT, config.PLACEMENT.OUTSIDE_LEFT})
        test.assert_equal(50 - config.DEFAULT_WIDTH - config.UNIT_CARD_GAP, frame.l)
        test.assert_true(source:find('outside%-left') ~= nil)

        frame = assert(config.resolve(
            120, 40, card, {config.PLACEMENT.INSIDE_RIGHT}))
        test.assert_equal(119 - config.DEFAULT_WIDTH - config.UNIT_CARD_GAP + 1, frame.l)
    end)

    test.case('stats popout config: rejects malformed placement lists', function()
        local _, config = env.load_stats_popover(root)
        test.assert_false(pcall(config.resolve, 120, 40, nil, {}))
        test.assert_false(pcall(config.resolve, 120, 40, nil, {'beside-ish'}))
        test.assert_false(pcall(config.resolve, 120, 40, nil,
            {[1]=config.PLACEMENT.OUTSIDE_LEFT,
                preferred=config.PLACEMENT.INSIDE_RIGHT}))
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
