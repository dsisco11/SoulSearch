local env = require('support.soulsearch_env')

return function(test, root)
    test.case('stats overlay: registration has stable static identity', function()
        local overlay, state, config = env.load_stats_overlay(root)
        test.assert_equal(0, state.lookups)
        test.assert_true(overlay.OVERLAY_WIDGETS.soulsearch_stats ~= nil)
        local attrs = overlay.SoulSearchStatsOverlay.attrs
        test.assert_equal('dwarfmode/ViewSheets/UNIT', attrs.viewscreens)
        test.assert_true(attrs.default_enabled)
        test.assert_true(attrs.hotspot)
        test.assert_equal(0, attrs.overlay_onupdate_max_freq_seconds)
        test.assert_equal(18, attrs.version)
        test.assert_equal(config.BUTTON_PLACEMENT.OUTSIDE_LEFT,
            attrs.placement[1].button)
        test.assert_equal(config.DIRECTION.LEFT, attrs.placement[1].direction)
        test.assert_equal(config.BUTTON_PLACEMENT.OUTSIDE_RIGHT,
            attrs.placement[2].button)
        test.assert_equal(config.DIRECTION.RIGHT, attrs.placement[2].direction)
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
        test.assert_equal('value', panel.sort.key)
        test.assert_true(panel.sort.reverse)
        test.assert_equal(1, panel.sort.phase)
        test.assert_equal(1, state.lookups)
        overlay, state = env.load_stats_overlay(root, {unit=unit})
        test.assert_false(overlay.SoulSearchStatsOverlay{}:overlay_onupdate())
        test.assert_equal(0, state.lookups)
    end)

    test.case('stats overlay: uses a thin frame without the DFHack footer', function()
        local overlay = env.load_stats_overlay(root)
        local widget = overlay.SoulSearchStatsOverlay{}
        test.assert_equal('thin', widget.subviews.window.frame_style)
    end)

    test.case('stats overlay: forwards per-instance placement fallbacks in order', function()
        local overlay, state, config = env.load_stats_overlay(root)
        local widget = overlay.SoulSearchStatsOverlay{
            placement={
                {button=config.BUTTON_PLACEMENT.INSIDE_LEFT,
                    direction=config.DIRECTION.UP},
                {button=config.BUTTON_PLACEMENT.OUTSIDE_RIGHT,
                    direction=config.DIRECTION.RIGHT},
            },
        }
        widget:resolve_frame(120, 40)
        test.assert_equal(config.BUTTON_PLACEMENT.INSIDE_LEFT,
            state.placements[1].button)
        test.assert_equal(config.DIRECTION.UP, state.placements[1].direction)
        test.assert_equal(config.BUTTON_PLACEMENT.OUTSIDE_RIGHT,
            state.placements[2].button)
    end)

    test.case('stats overlay: does not measure or report a closed unit card during layout', function()
        local overlay, state = env.load_stats_overlay(root)
        overlay.SoulSearchStatsOverlay{}:preUpdateLayout({width=120, height=40})
        test.assert_equal(0, #state.errors)
        test.assert_equal(nil, state.placements)
    end)

    test.case('stats overlay: preserves a user-repositioned panel position', function()
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        widget.frame={l=18, t=7, w=3, h=1}
        widget:preUpdateLayout({width=120, height=40})
        test.assert_equal(18, state.repositioned_panel.l)
        test.assert_equal(7, state.repositioned_panel.t)

        widget.subviews.collapse_button.on_activate()
        test.assert_equal(18, widget.repositioned_panel.l)
        test.assert_equal(7, widget.repositioned_panel.t)
        widget.subviews.expand_button.on_activate()
        test.assert_equal(18, widget.repositioned_panel.l)
        test.assert_equal(7, widget.repositioned_panel.t)

        widget.frame={r=5, b=4, w=3, h=1}
        widget:preUpdateLayout({width=120, height=40})
        test.assert_equal(112, state.repositioned_panel.l)
        test.assert_equal(36, state.repositioned_panel.t)

        widget.frame={l=0, t=0, w=3, h=1}
        widget:preUpdateLayout({width=120, height=40})
        test.assert_equal(nil, state.repositioned_panel)
    end)

    test.case('stats overlay: recognizes a unit card beneath a launcher screen', function()
        local unit={id=7}
        local unit_card_screen={}
        local launcher_screen={parent=unit_card_screen}
        local overlay, state = env.load_stats_overlay(root, {screen=launcher_screen, unit=unit,
            focuses_by_screen={[launcher_screen]={'dfhack/lua/launcher'},
                [unit_card_screen]={'dwarfmode/ViewSheets/UNIT/Overview'}}})
        local widget = overlay.SoulSearchStatsOverlay{}
        test.assert_false(widget:overlay_onupdate())
        test.assert_equal(unit, widget.subviews.window.subviews.stats_panel.subject.unit)
        test.assert_equal(1, state.lookups)
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

    test.case('stats overlay: resolves tooltips while rendering', function()
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        widget:onRenderFrame(nil, nil)
        test.assert_equal(1, state.tooltip_updates)
    end)

    test.case('stats overlay: renders its tooltip above the clipped popout', function()
        local overlay = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        widget.tooltip.visible = true
        widget.tooltip.render = function() widget.tooltip_rendered = true end
        widget:render('screen')
        test.assert_true(widget.tooltip_rendered)
        test.assert_equal(widget, widget.tooltip.parent_view)
    end)

    test.case('stats overlay: collapse button shrinks and restores the popout', function()
        local overlay, state, config = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        local window = widget.subviews.window
        local panel = window.subviews.stats_panel
        test.assert_equal(string.char(30), widget.subviews.collapse_button.label)
        test.assert_equal('Collapse the SoulSearch stats view.',
            widget.subviews.collapse_button.tooltip)
        test.assert_equal('Expand the SoulSearch stats view.',
            widget.subviews.expand_button.tooltip)
        test.assert_equal(0, window.frame.l)
        widget.subviews.collapse_button.on_activate()
        test.assert_true(widget.collapsed)
        test.assert_false(window.visible)
        test.assert_false(widget.subviews.collapse_button.visible)
        test.assert_true(widget.subviews.expand_button.visible)
        test.assert_equal(3, widget.frame.w)
        test.assert_equal(1, widget.frame.h)
        test.assert_equal(config.BUTTON_PLACEMENT.OUTSIDE_LEFT,
            state.placements[1].button)
        test.assert_equal(config.DIRECTION.LEFT, state.placements[1].direction)
        test.assert_equal(72, widget.frame.l)
        test.assert_equal(11, widget.frame.t)
        test.assert_equal(config.DIRECTION.LEFT,
            widget.subviews.expand_button.direction)
        widget.subviews.expand_button.on_activate()
        test.assert_false(widget.collapsed)
        test.assert_true(window.visible)
        test.assert_equal(string.char(31), widget.subviews.expand_button.label)
        test.assert_equal(32, widget.frame.w)
        test.assert_equal(13, widget.frame.h)
        test.assert_equal(0, window.frame.l)
        test.assert_equal(1, window.frame.t)
        test.assert_equal(29, widget.subviews.collapse_button.frame.l)
        test.assert_equal(0, widget.subviews.collapse_button.frame.t)
        test.assert_equal(config.DIRECTION.LEFT,
            widget.subviews.collapse_button.direction)
        test.assert_equal(nil, panel.visible)
    end)

    test.case('stats overlay: measures the vanilla unit-card tab strip', function()
        local overlay, state = env.load_stats_overlay(root, {
            focuses={'dwarfmode/ViewSheets/UNIT'}, unit={id=4}, width=264, height=75,
            screen_rows={[15]=string.rep(' ', 169) .. 'Overview   Items   Health'},
        })
        overlay.SoulSearchStatsOverlay{}:overlay_onupdate()
        test.assert_equal(167, state.unit_card_rect.x1)
        test.assert_equal(13, state.unit_card_rect.y1)
        test.assert_equal(263, state.unit_card_rect.x2)
        test.assert_equal(74, state.unit_card_rect.y2)
    end)
end
