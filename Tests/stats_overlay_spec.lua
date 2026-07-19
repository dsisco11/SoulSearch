local env = require('support.soulsearch_env')

local root = require('support.repo_root')

describe('stats overlay', function()

    it('stats overlay: registration has stable static identity', function()
        local overlay, state, config = env.load_stats_overlay(root)
        assert.are.equal(0, state.lookups)
        assert.is_truthy(overlay.OVERLAY_WIDGETS.soulsearch_stats ~= nil)
        local attrs = overlay.SoulSearchStatsOverlay.attrs
        assert.are.equal('dwarfmode/ViewSheets/UNIT', attrs.viewscreens)
        assert.is_truthy(attrs.default_enabled)
        assert.is_truthy(attrs.hotspot)
        assert.are.equal(0, attrs.overlay_onupdate_max_freq_seconds)
        assert.are.equal(28, attrs.version)
        assert.are.equal(config.BUTTON_PLACEMENT.OUTSIDE_LEFT,
            attrs.placement[1].button)
        assert.are.equal(config.DIRECTION.LEFT, attrs.placement[1].direction)
        assert.are.equal(config.BUTTON_PLACEMENT.OUTSIDE_RIGHT,
            attrs.placement[2].button)
        assert.are.equal(config.DIRECTION.RIGHT, attrs.placement[2].direction)
        assert.are.equal(nil, overlay.SoulSearchStatsOverlay.overlay_trigger)
    end)

    it('stats overlay: updates an attached panel for a unit card selection', function()
        local unit={id=4}
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT/Overview'}, unit=unit})
        local widget = overlay.SoulSearchStatsOverlay{}
        assert.is_falsy(widget:overlay_onupdate())
        local panel = widget.subviews.window.subviews.stats_panel
        assert.are.equal(unit, panel.subject.unit)
        assert.are.equal('value', panel.sort.key)
        assert.is_truthy(panel.sort.reverse)
        assert.are.equal(1, panel.sort.phase)
        assert.is_truthy(panel.show_header_underline)
        assert.are.equal(1, state.lookups)
        overlay, state = env.load_stats_overlay(root, {unit=unit})
        assert.is_falsy(overlay.SoulSearchStatsOverlay{}:overlay_onupdate())
        assert.are.equal(0, state.lookups)
    end)

    it('stats overlay: uses a signature-free thin frame', function()
        local overlay = env.load_stats_overlay(root)
        local widget = overlay.SoulSearchStatsOverlay{}
        assert.are.equal('interior', widget.subviews.window.frame_style)
        assert.are.equal(0, widget.subviews.window.frame_inset)
    end)

    it('stats overlay: forwards per-instance placement fallbacks in order', function()
        local overlay, state, config = env.load_stats_overlay(root)
        local widget = overlay.SoulSearchStatsOverlay{
            placement={
                {button=config.BUTTON_PLACEMENT.INSIDE_LEFT,
                    direction=config.DIRECTION.UP},
                {button=config.BUTTON_PLACEMENT.OUTSIDE_RIGHT,
                    direction=config.DIRECTION.RIGHT},
            },
        }
        state.layout={
            panel={l=43, t=5, w=32, h=12},
            button={l=72, t=4, w=3, h=1},
            direction=config.DIRECTION.UP,
        }
        widget:resolve_frame(120, 40)
        assert.are.equal(config.BUTTON_PLACEMENT.INSIDE_LEFT,
            state.placements[1].button)
        assert.are.equal(config.DIRECTION.UP, state.placements[1].direction)
        assert.are.equal(config.BUTTON_PLACEMENT.OUTSIDE_RIGHT,
            state.placements[2].button)
        assert.are.equal('[' .. string.char(31) .. ']',
            widget.subviews.collapse_button.text)
        assert.are.equal('[' .. string.char(30) .. ']',
            widget.subviews.expand_button.text)
        assert.are.equal(1, widget.subviews.window.frame.t)
        assert.are.equal(0, widget.subviews.collapse_button.frame.t)
    end)

    it('stats overlay: does not measure or report a closed unit card during layout', function()
        local overlay, state = env.load_stats_overlay(root)
        overlay.SoulSearchStatsOverlay{}:preUpdateLayout({width=120, height=40})
        assert.are.equal(0, #state.errors)
        assert.are.equal(nil, state.placements)
    end)

    it('stats overlay: captures a persisted position before the unit card opens', function()
        local overlay, state = env.load_stats_overlay(root)
        local widget = overlay.SoulSearchStatsOverlay{}
        widget.frame={r=5, b=4, w=32, h=13}
        widget:preUpdateLayout({width=120, height=40})
        assert.are.equal(83, widget.positioned_panel.l)
        assert.are.equal(24, widget.positioned_panel.t)
        assert.are.equal(nil, state.placements)

        widget:resolve_frame(120, 40)
        assert.are.equal(83, state.positioned_panel.l)
        assert.are.equal(24, state.positioned_panel.t)
    end)

    it('stats overlay: reapplies child layout after restoring a persisted position', function()
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        widget.frame={r=5, b=4, w=32, h=13}
        widget:preUpdateLayout({width=120, height=40})
        widget.frame_parent_rect={width=120, height=40}
        widget:overlay_onupdate()
        assert.are.equal(1, state.layout_updates)
        assert.is_falsy(widget.needs_layout)
    end)

    it('stats overlay: keeps a repositioned panel authoritative', function()
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        widget:resolve_frame(120, 40)
        state.layout={
            panel={l=80, t=7, w=32, h=12},
            button={l=80, t=6, w=3, h=1},
            direction='right',
        }
        widget.frame={l=80, t=6, w=32, h=13}
        widget:preUpdateLayout({width=120, height=40})
        assert.are.equal(80, state.positioned_panel.l)
        assert.are.equal(7, state.positioned_panel.t)
        assert.are.equal(80, widget.positioned_panel.l)
        assert.are.equal(7, widget.positioned_panel.t)
        assert.are.equal(80, widget.frame.l)
        assert.are.equal(6, widget.frame.t)
        assert.are.equal(0, widget.subviews.window.frame.l)
        assert.are.equal(1, widget.subviews.window.frame.t)
        assert.are.equal(0, widget.subviews.collapse_button.frame.l)

        widget.subviews.collapse_button.on_click()
        assert.are.equal(80, state.positioned_panel.l)
        assert.are.equal(80, widget.frame.l)
        assert.are.equal(6, widget.frame.t)
        assert.are.equal(32, widget.frame.w)
        assert.are.equal(13, widget.frame.h)
        widget.subviews.expand_button.on_click()
        assert.are.equal(80, state.positioned_panel.l)
        assert.are.equal(80, widget.frame.l)
        assert.are.equal(6, widget.frame.t)
    end)

    it('stats overlay: restores a persisted panel position', function()
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        state.layout={
            panel={l=83, t=24, w=32, h=12},
            button={l=83, t=23, w=3, h=1},
            direction='right',
        }
        widget.frame={r=5, b=4, w=32, h=13}
        widget:preUpdateLayout({width=120, height=40})
        assert.are.equal(83, state.positioned_panel.l)
        assert.are.equal(24, state.positioned_panel.t)
        assert.are.equal(83, widget.positioned_panel.l)
        assert.are.equal(24, widget.positioned_panel.t)

        state.layout=nil
        widget.frame={l=0, t=0, w=32, h=13}
        widget.managed_origin={l=83, t=24}
        widget:preUpdateLayout({width=120, height=40})
        assert.are.equal(nil, widget.positioned_panel)
    end)

    it('stats overlay: recognizes a unit card beneath a launcher screen', function()
        local unit={id=7}
        local unit_card_screen={}
        local launcher_screen={parent=unit_card_screen}
        local overlay, state = env.load_stats_overlay(root, {screen=launcher_screen, unit=unit,
            focuses_by_screen={[launcher_screen]={'dfhack/lua/launcher'},
                [unit_card_screen]={'dwarfmode/ViewSheets/UNIT/Overview'}}})
        local widget = overlay.SoulSearchStatsOverlay{}
        assert.is_falsy(widget:overlay_onupdate())
        assert.are.equal(unit, widget.subviews.window.subviews.stats_panel.subject.unit)
        assert.are.equal(1, state.lookups)
    end)

    it('stats overlay: only reports a subject error once', function()
        local overlay, state = env.load_stats_overlay(root, {unit={id=1}})
        assert.is_falsy(overlay.SoulSearchStatsOverlay{}:overlay_onupdate())
        assert.are.equal(0, #state.errors)
        overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}, unit={id=2}, subject_error='bad unit'})
        local widget = overlay.SoulSearchStatsOverlay{}
        widget:overlay_onupdate()
        widget:overlay_onupdate()
        assert.are.equal('bad unit', state.errors[1])
        assert.are.equal(1, #state.errors)
    end)

    it('stats overlay: resolves tooltips while rendering', function()
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        widget:onRenderFrame(nil, nil)
        assert.are.equal(1, state.tooltip_updates)
    end)

    it('stats overlay: renders its tooltip above the clipped popout', function()
        local overlay = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        widget.tooltip.visible = true
        widget.tooltip.render = function() widget.tooltip_rendered = true end
        widget:render('screen')
        assert.is_truthy(widget.tooltip_rendered)
        assert.are.equal(widget, widget.tooltip.parent_view)
    end)

    it('stats overlay: collapse button hides and restores the panel in place', function()
        local overlay, state, config = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        local window = widget.subviews.window
        local panel = window.subviews.stats_panel
        assert.are.equal('Label', widget.subviews.collapse_button.widget_kind)
        assert.are.equal('[' .. string.char(16) .. ']',
            widget.subviews.collapse_button.text)
        assert.are.equal('Collapse the SoulSearch stats view.',
            widget.subviews.collapse_button.tooltip)
        assert.are.equal('Expand the SoulSearch stats view.',
            widget.subviews.expand_button.tooltip)
        assert.are.equal(0, window.frame.l)
        widget.subviews.collapse_button.on_click()
        assert.is_truthy(widget.collapsed)
        assert.is_falsy(window.visible)
        assert.is_falsy(widget.subviews.collapse_button.visible)
        assert.is_truthy(widget.subviews.expand_button.visible)
        assert.are.equal(32, widget.frame.w)
        assert.are.equal(13, widget.frame.h)
        assert.are.equal(config.BUTTON_PLACEMENT.OUTSIDE_LEFT,
            state.placements[1].button)
        assert.are.equal(config.DIRECTION.LEFT, state.placements[1].direction)
        assert.are.equal(43, widget.frame.l)
        assert.are.equal(11, widget.frame.t)
        assert.are.equal(config.DIRECTION.LEFT,
            widget.subviews.expand_button.direction)
        assert.are.equal('[' .. string.char(17) .. ']',
            widget.subviews.expand_button.text)
        widget.subviews.expand_button.on_click()
        assert.is_falsy(widget.collapsed)
        assert.is_truthy(window.visible)
        assert.are.equal('[' .. string.char(17) .. ']',
            widget.subviews.expand_button.text)
        assert.are.equal(32, widget.frame.w)
        assert.are.equal(13, widget.frame.h)
        assert.are.equal(0, window.frame.l)
        assert.are.equal(1, window.frame.t)
        assert.are.equal(29, widget.subviews.collapse_button.frame.l)
        assert.are.equal(0, widget.subviews.collapse_button.frame.t)
        assert.are.equal(config.DIRECTION.LEFT,
            widget.subviews.collapse_button.direction)
        assert.are.equal('[' .. string.char(16) .. ']',
            widget.subviews.collapse_button.text)
        assert.are.equal(nil, panel.visible)
    end)

    it('stats overlay: measures the vanilla unit-card tab strip', function()
        local overlay, state = env.load_stats_overlay(root, {
            focuses={'dwarfmode/ViewSheets/UNIT'}, unit={id=4}, width=264, height=75,
            screen_rows={[15]=string.rep(' ', 169) .. 'Overview   Items   Health'},
        })
        overlay.SoulSearchStatsOverlay{}:overlay_onupdate()
        assert.are.equal(167, state.unit_card_rect.x1)
        assert.are.equal(13, state.unit_card_rect.y1)
        assert.are.equal(263, state.unit_card_rect.x2)
        assert.are.equal(74, state.unit_card_rect.y2)
    end)

end)
