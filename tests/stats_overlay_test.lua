local env = require('support.soulsearch_env')

return function(test, root)
    test.case('stats overlay: registration has stable static identity', function()
        local overlay, state = env.load_stats_overlay(root)
        test.assert_equal(0, state.lookups)
        test.assert_true(overlay.OVERLAY_WIDGETS.soulsearch_stats ~= nil)
        test.assert_equal('Stats', overlay.BUTTON_LABEL)
        test.assert_equal(5, overlay.BUTTON_WIDTH)
        local attrs = overlay.SoulSearchStatsOverlay.attrs
        test.assert_equal('dwarfmode/ViewSheets/UNIT', attrs.viewscreens)
        test.assert_true(attrs.default_enabled)
        test.assert_equal(-2, attrs.default_pos.x)
        test.assert_equal(-2, attrs.default_pos.y)
        test.assert_equal(1, attrs.version)
    end)

    test.case('stats overlay: accepts only exact left-click bounds', function()
        local unit={id=4}
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}, unit=unit})
        local widget = overlay.SoulSearchStatsOverlay{}
        function widget:getMousePos() return self.mouse_x, self.mouse_y end
        for x=0, overlay.BUTTON_WIDTH - 1 do
            widget.mouse_x, widget.mouse_y=x, 0
            test.assert_true(widget:onInput({_MOUSE_L=true}))
        end
        test.assert_equal(overlay.BUTTON_WIDTH, state.opens)
        for _, point in ipairs({{-1,0},{overlay.BUTTON_WIDTH,0},{0,-1},{0,1}}) do
            widget.mouse_x, widget.mouse_y=point[1], point[2]
            test.assert_false(widget:onInput({_MOUSE_L=true}))
        end
        test.assert_false(widget:onInput({_MOUSE_R=true}))
        test.assert_false(widget:onInput({_MOUSE_SCROLL_DOWN=true}))
        test.assert_equal(overlay.BUTTON_WIDTH, state.opens)
    end)

    test.case('stats overlay: focus, unit, and popover failures report once', function()
        local overlay, state = env.load_stats_overlay(root, {unit={id=1}})
        test.assert_equal(nil, overlay.activate())
        test.assert_equal('SoulSearch Stats is only available from a unit card.', state.errors[1])
        overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        test.assert_equal(nil, overlay.activate())
        test.assert_equal('SoulSearch Stats requires a selected unit.', state.errors[1])
        overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}, unit={id=2}, popover_error='bad unit'})
        test.assert_equal(nil, overlay.activate())
        test.assert_equal('bad unit', state.errors[1])
        test.assert_equal(1, state.lookups)
    end)

    test.case('stats overlay: CLI trigger shares the activation boundary', function()
        local unit={id=8}
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}, unit=unit})
        local widget = overlay.SoulSearchStatsOverlay{}
        local screen = widget:overlay_trigger()
        test.assert_equal('shown', screen.id)
        test.assert_equal(unit, state.last_unit)
        test.assert_equal(1, state.lookups)
    end)
end
