local env = require('support.soulsearch_env')

return function(test, root)
    test.case('stats popover: config derives native and screen-relative usable frames', function()
        local _, config = env.load_stats_popover(root)
        local minimum = config.get_minimum()
        local frame = assert(config.resolve(minimum.w, minimum.h))
        test.assert_equal(0, frame.l)
        test.assert_equal(0, frame.t)
        local missing, err = config.resolve(minimum.w - 1, minimum.h)
        test.assert_equal(nil, missing)
        test.assert_true(err:find('at least', 1, true) ~= nil)
        local native = assert(config.resolve(120, 40, {x1=10, x2=70, y1=5, y2=35}))
        test.assert_equal(71, native.l)
        test.assert_equal(5 + math.floor((31 - config.DEFAULT_HEIGHT) / 2), native.t)
        local fallback = assert(config.resolve(120, 40, {x1=10, x2=115, y1=5, y2=35}))
        test.assert_equal(78, fallback.l)
        test.assert_equal(math.floor((40 - config.DEFAULT_HEIGHT) / 2), fallback.t)
    end)

    test.case('stats popover: uses the native unit-card bounds before fallback', function()
        local unit={id=10}
        local popover, config, _, state = env.load_stats_popover(root, {
            units={[10]=unit}, width=120, height=40,
            unit_card_rect={x1=10, x2=70, y1=5, y2=35},
        })
        local screen = assert(popover.open(unit))
        test.assert_equal(71, screen.window.frame.l)
        test.assert_equal(5 + math.floor((31 - config.DEFAULT_HEIGHT) / 2),
            screen.window.frame.t)
        test.assert_true(state.widget_lookups > 0)
        screen:onResize(120, 40)
        test.assert_equal(71, screen.window.frame.l)
        test.assert_equal(config.DEFAULT_HEIGHT, screen.window.frame.h)
    end)

    test.case('stats popover: validates before collecting or changing singleton', function()
        local unit={id=7}
        local popover, _, registry, state = env.load_stats_popover(root, {units={[7]=unit}})
        local screen = assert(popover.open(unit))
        test.assert_equal(1, state.collects)
        local missing, err = popover.open({id=8})
        test.assert_equal(nil, missing)
        test.assert_equal('SoulSearch requires a current unit.', err)
        test.assert_equal(screen, popover.get_singleton())
        test.assert_equal(1, registry.count())
    end)

    test.case('stats popover: modal singleton resets only for a different unit', function()
        local first, second={id=1}, {id=2}
        local popover, config, registry, state = env.load_stats_popover(root,
            {units={[1]=first, [2]=second}})
        local screen = assert(popover.open(first))
        local panel = screen.window.subviews.stats_panel
        test.assert_equal('bold', screen.window.frame_style)
        test.assert_true(screen.window.subviews.close_button ~= nil)
        test.assert_equal(nil, screen.onInput)
        panel.sort={key='value', reverse=true, phase=1}
        panel.subviews.body.start_line_num=4
        test.assert_equal(screen, assert(popover.open(first)))
        test.assert_equal(0, state.resets)
        test.assert_equal(screen, assert(popover.open(second)))
        test.assert_equal(1, state.resets)
        test.assert_equal(1, panel.subviews.body.start_line_num)
        test.assert_equal(config.DEFAULT_SORT.key, panel.sort.key)
        test.assert_equal(second, screen:onGetSelectedUnit())
        test.assert_true(screen.exclude_from_placement)
        test.assert_equal(0, #registry.get_frames())
        screen:onDismiss()
        test.assert_equal(nil, popover.get_singleton())
        local replacement = assert(popover.open(first))
        screen:onDestroy()
        test.assert_equal(replacement, popover.get_singleton())
    end)

    test.case('stats popover: a too-small resize reports once and dismisses', function()
        local unit={id=9}
        local popover, config, _, state = env.load_stats_popover(root, {units={[9]=unit}})
        local screen = assert(popover.open(unit))
        local minimum = config.get_minimum()
        screen:onResize(minimum.w - 1, minimum.h)
        screen:onResize(minimum.w - 1, minimum.h)
        test.assert_true(screen.dismissed)
        test.assert_equal(1, #state.printed)
        test.assert_equal(nil, popover.get_singleton())
    end)

    test.case('stats popover: unavailable context takes precedence', function()
        local popover, _, registry, state = env.load_stats_popover(root,
            {unavailable_reason='SoulSearch only works in fortress mode.'})
        local screen, err = popover.open('not a unit')
        test.assert_equal(nil, screen)
        test.assert_equal('SoulSearch only works in fortress mode.', err)
        test.assert_equal(0, state.collects)
        test.assert_equal(0, registry.count())
    end)
end
