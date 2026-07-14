local env = require('support.soulsearch_env')

return function(test, root)
    test.case('stats overlay: registration has stable static identity', function()
        local overlay, state = env.load_stats_overlay(root)
        test.assert_equal(0, state.lookups)
        test.assert_true(overlay.OVERLAY_WIDGETS.soulsearch_stats ~= nil)
        local attrs = overlay.SoulSearchStatsOverlay.attrs
        test.assert_equal('dwarfmode/ViewSheets/UNIT', attrs.viewscreens)
        test.assert_true(attrs.default_enabled)
        test.assert_true(attrs.hotspot)
        test.assert_equal(0, attrs.overlay_onupdate_max_freq_seconds)
        test.assert_equal(3, attrs.version)
        test.assert_equal(nil, overlay.SoulSearchStatsOverlay.overlay_trigger)
    end)

    test.case('stats overlay: updates an attached panel for a unit card selection', function()
        local unit={id=4}
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT/Overview'}, unit=unit})
        local widget = overlay.SoulSearchStatsOverlay{}
        test.assert_false(widget:overlay_onupdate())
        local panel = widget.subviews.window.subviews.stats_panel
        test.assert_equal(unit, panel.subject.unit)
        test.assert_equal(1, state.lookups)
        overlay, state = env.load_stats_overlay(root, {unit=unit})
        test.assert_false(overlay.SoulSearchStatsOverlay{}:overlay_onupdate())
        test.assert_equal(0, state.lookups)
    end)

    test.case('stats overlay: only reports a subject error once', function()
        local overlay, state = env.load_stats_overlay(root, {unit={id=1}})
        test.assert_false(overlay.SoulSearchStatsOverlay{}:overlay_onupdate())
        test.assert_equal(0, #state.errors)
        overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}, unit={id=2}, subject_error='bad unit'})
        local widget = overlay.SoulSearchStatsOverlay{}
        widget:overlay_onupdate()
        widget:overlay_onupdate()
        test.assert_equal('bad unit', state.errors[1])
        test.assert_equal(1, #state.errors)
    end)
end
