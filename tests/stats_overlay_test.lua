local env = require('support.soulsearch_env')

return function(test, root)
    test.case('stats overlay: registration has stable static identity', function()
        local overlay, state = env.load_stats_overlay(root)
        test.assert_equal(0, state.lookups)
        test.assert_true(overlay.OVERLAY_WIDGETS.soulsearch_stats ~= nil)
        local attrs = overlay.SoulSearchStatsOverlay.attrs
        test.assert_equal('dwarfmode/ViewSheets/UNIT', attrs.viewscreens)
        test.assert_true(attrs.default_enabled)
        test.assert_false(attrs.visible)
        test.assert_true(attrs.hotspot)
        test.assert_equal(0, attrs.overlay_onupdate_max_freq_seconds)
        test.assert_equal(2, attrs.version)
    end)

    test.case('stats overlay: automatically triggers for a unit card selection', function()
        local unit={id=4}
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT/Overview'}, unit=unit})
        local widget = overlay.SoulSearchStatsOverlay{}
        test.assert_true(widget:overlay_onupdate())
        local screen = widget:overlay_trigger()
        test.assert_equal('shown', screen.id)
        test.assert_equal(unit, state.last_unit)
        test.assert_equal(1, state.opens)
        overlay, state = env.load_stats_overlay(root, {unit=unit})
        test.assert_false(overlay.SoulSearchStatsOverlay{}:overlay_onupdate())
        test.assert_equal(0, state.opens)
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

    test.case('stats overlay: trigger shares the activation boundary', function()
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
