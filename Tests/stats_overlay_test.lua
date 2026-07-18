local env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('stats overlay: registration has stable static identity', function()
        local overlay, state, config = env.load_stats_overlay(root)
        luaunit.assertIs(0, state.lookups)
        luaunit.assertEvalToTrue(overlay.OVERLAY_WIDGETS.soulsearch_stats ~= nil)
        local attrs = overlay.SoulSearchStatsOverlay.attrs
        luaunit.assertIs('dwarfmode/ViewSheets/UNIT', attrs.viewscreens)
        luaunit.assertEvalToTrue(attrs.default_enabled)
        luaunit.assertEvalToTrue(attrs.hotspot)
        luaunit.assertIs(0, attrs.overlay_onupdate_max_freq_seconds)
        luaunit.assertIs(28, attrs.version)
        luaunit.assertIs(config.BUTTON_PLACEMENT.OUTSIDE_LEFT,
            attrs.placement[1].button)
        luaunit.assertIs(config.DIRECTION.LEFT, attrs.placement[1].direction)
        luaunit.assertIs(config.BUTTON_PLACEMENT.OUTSIDE_RIGHT,
            attrs.placement[2].button)
        luaunit.assertIs(config.DIRECTION.RIGHT, attrs.placement[2].direction)
        luaunit.assertIs(nil, overlay.SoulSearchStatsOverlay.overlay_trigger)
    end)

    add_test('stats overlay: updates an attached panel for a unit card selection', function()
        local unit={id=4}
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT/Overview'}, unit=unit})
        local widget = overlay.SoulSearchStatsOverlay{}
        luaunit.assertEvalToFalse(widget:overlay_onupdate())
        local panel = widget.subviews.window.subviews.stats_panel
        luaunit.assertIs(unit, panel.subject.unit)
        luaunit.assertIs('value', panel.sort.key)
        luaunit.assertEvalToTrue(panel.sort.reverse)
        luaunit.assertIs(1, panel.sort.phase)
        luaunit.assertEvalToTrue(panel.show_header_underline)
        luaunit.assertIs(1, state.lookups)
        overlay, state = env.load_stats_overlay(root, {unit=unit})
        luaunit.assertEvalToFalse(overlay.SoulSearchStatsOverlay{}:overlay_onupdate())
        luaunit.assertIs(0, state.lookups)
    end)

    add_test('stats overlay: uses a signature-free thin frame', function()
        local overlay = env.load_stats_overlay(root)
        local widget = overlay.SoulSearchStatsOverlay{}
        luaunit.assertIs('interior', widget.subviews.window.frame_style)
        luaunit.assertIs(0, widget.subviews.window.frame_inset)
    end)

    add_test('stats overlay: forwards per-instance placement fallbacks in order', function()
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
        luaunit.assertIs(config.BUTTON_PLACEMENT.INSIDE_LEFT,
            state.placements[1].button)
        luaunit.assertIs(config.DIRECTION.UP, state.placements[1].direction)
        luaunit.assertIs(config.BUTTON_PLACEMENT.OUTSIDE_RIGHT,
            state.placements[2].button)
        luaunit.assertIs('[' .. string.char(31) .. ']',
            widget.subviews.collapse_button.text)
        luaunit.assertIs('[' .. string.char(30) .. ']',
            widget.subviews.expand_button.text)
        luaunit.assertIs(1, widget.subviews.window.frame.t)
        luaunit.assertIs(0, widget.subviews.collapse_button.frame.t)
    end)

    add_test('stats overlay: does not measure or report a closed unit card during layout', function()
        local overlay, state = env.load_stats_overlay(root)
        overlay.SoulSearchStatsOverlay{}:preUpdateLayout({width=120, height=40})
        luaunit.assertIs(0, #state.errors)
        luaunit.assertIs(nil, state.placements)
    end)

    add_test('stats overlay: captures a persisted position before the unit card opens', function()
        local overlay, state = env.load_stats_overlay(root)
        local widget = overlay.SoulSearchStatsOverlay{}
        widget.frame={r=5, b=4, w=32, h=13}
        widget:preUpdateLayout({width=120, height=40})
        luaunit.assertIs(83, widget.positioned_panel.l)
        luaunit.assertIs(24, widget.positioned_panel.t)
        luaunit.assertIs(nil, state.placements)

        widget:resolve_frame(120, 40)
        luaunit.assertIs(83, state.positioned_panel.l)
        luaunit.assertIs(24, state.positioned_panel.t)
    end)

    add_test('stats overlay: reapplies child layout after restoring a persisted position', function()
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        widget.frame={r=5, b=4, w=32, h=13}
        widget:preUpdateLayout({width=120, height=40})
        widget.frame_parent_rect={width=120, height=40}
        widget:overlay_onupdate()
        luaunit.assertIs(1, state.layout_updates)
        luaunit.assertEvalToFalse(widget.needs_layout)
    end)

    add_test('stats overlay: keeps a repositioned panel authoritative', function()
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
        luaunit.assertIs(80, state.positioned_panel.l)
        luaunit.assertIs(7, state.positioned_panel.t)
        luaunit.assertIs(80, widget.positioned_panel.l)
        luaunit.assertIs(7, widget.positioned_panel.t)
        luaunit.assertIs(80, widget.frame.l)
        luaunit.assertIs(6, widget.frame.t)
        luaunit.assertIs(0, widget.subviews.window.frame.l)
        luaunit.assertIs(1, widget.subviews.window.frame.t)
        luaunit.assertIs(0, widget.subviews.collapse_button.frame.l)

        widget.subviews.collapse_button.on_click()
        luaunit.assertIs(80, state.positioned_panel.l)
        luaunit.assertIs(80, widget.frame.l)
        luaunit.assertIs(6, widget.frame.t)
        luaunit.assertIs(32, widget.frame.w)
        luaunit.assertIs(13, widget.frame.h)
        widget.subviews.expand_button.on_click()
        luaunit.assertIs(80, state.positioned_panel.l)
        luaunit.assertIs(80, widget.frame.l)
        luaunit.assertIs(6, widget.frame.t)
    end)

    add_test('stats overlay: restores a persisted panel position', function()
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
        luaunit.assertIs(83, state.positioned_panel.l)
        luaunit.assertIs(24, state.positioned_panel.t)
        luaunit.assertIs(83, widget.positioned_panel.l)
        luaunit.assertIs(24, widget.positioned_panel.t)

        state.layout=nil
        widget.frame={l=0, t=0, w=32, h=13}
        widget.managed_origin={l=83, t=24}
        widget:preUpdateLayout({width=120, height=40})
        luaunit.assertIs(nil, widget.positioned_panel)
    end)

    add_test('stats overlay: recognizes a unit card beneath a launcher screen', function()
        local unit={id=7}
        local unit_card_screen={}
        local launcher_screen={parent=unit_card_screen}
        local overlay, state = env.load_stats_overlay(root, {screen=launcher_screen, unit=unit,
            focuses_by_screen={[launcher_screen]={'dfhack/lua/launcher'},
                [unit_card_screen]={'dwarfmode/ViewSheets/UNIT/Overview'}}})
        local widget = overlay.SoulSearchStatsOverlay{}
        luaunit.assertEvalToFalse(widget:overlay_onupdate())
        luaunit.assertIs(unit, widget.subviews.window.subviews.stats_panel.subject.unit)
        luaunit.assertIs(1, state.lookups)
    end)

    add_test('stats overlay: only reports a subject error once', function()
        local overlay, state = env.load_stats_overlay(root, {unit={id=1}})
        luaunit.assertEvalToFalse(overlay.SoulSearchStatsOverlay{}:overlay_onupdate())
        luaunit.assertIs(0, #state.errors)
        overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}, unit={id=2}, subject_error='bad unit'})
        local widget = overlay.SoulSearchStatsOverlay{}
        widget:overlay_onupdate()
        widget:overlay_onupdate()
        luaunit.assertIs('bad unit', state.errors[1])
        luaunit.assertIs(1, #state.errors)
    end)

    add_test('stats overlay: resolves tooltips while rendering', function()
        local overlay, state = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        widget:onRenderFrame(nil, nil)
        luaunit.assertIs(1, state.tooltip_updates)
    end)

    add_test('stats overlay: renders its tooltip above the clipped popout', function()
        local overlay = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        widget.tooltip.visible = true
        widget.tooltip.render = function() widget.tooltip_rendered = true end
        widget:render('screen')
        luaunit.assertEvalToTrue(widget.tooltip_rendered)
        luaunit.assertIs(widget, widget.tooltip.parent_view)
    end)

    add_test('stats overlay: collapse button hides and restores the panel in place', function()
        local overlay, state, config = env.load_stats_overlay(root,
            {focuses={'dwarfmode/ViewSheets/UNIT'}})
        local widget = overlay.SoulSearchStatsOverlay{}
        local window = widget.subviews.window
        local panel = window.subviews.stats_panel
        luaunit.assertIs('Label', widget.subviews.collapse_button.widget_kind)
        luaunit.assertIs('[' .. string.char(16) .. ']',
            widget.subviews.collapse_button.text)
        luaunit.assertIs('Collapse the SoulSearch stats view.',
            widget.subviews.collapse_button.tooltip)
        luaunit.assertIs('Expand the SoulSearch stats view.',
            widget.subviews.expand_button.tooltip)
        luaunit.assertIs(0, window.frame.l)
        widget.subviews.collapse_button.on_click()
        luaunit.assertEvalToTrue(widget.collapsed)
        luaunit.assertEvalToFalse(window.visible)
        luaunit.assertEvalToFalse(widget.subviews.collapse_button.visible)
        luaunit.assertEvalToTrue(widget.subviews.expand_button.visible)
        luaunit.assertIs(32, widget.frame.w)
        luaunit.assertIs(13, widget.frame.h)
        luaunit.assertIs(config.BUTTON_PLACEMENT.OUTSIDE_LEFT,
            state.placements[1].button)
        luaunit.assertIs(config.DIRECTION.LEFT, state.placements[1].direction)
        luaunit.assertIs(43, widget.frame.l)
        luaunit.assertIs(11, widget.frame.t)
        luaunit.assertIs(config.DIRECTION.LEFT,
            widget.subviews.expand_button.direction)
        luaunit.assertIs('[' .. string.char(17) .. ']',
            widget.subviews.expand_button.text)
        widget.subviews.expand_button.on_click()
        luaunit.assertEvalToFalse(widget.collapsed)
        luaunit.assertEvalToTrue(window.visible)
        luaunit.assertIs('[' .. string.char(17) .. ']',
            widget.subviews.expand_button.text)
        luaunit.assertIs(32, widget.frame.w)
        luaunit.assertIs(13, widget.frame.h)
        luaunit.assertIs(0, window.frame.l)
        luaunit.assertIs(1, window.frame.t)
        luaunit.assertIs(29, widget.subviews.collapse_button.frame.l)
        luaunit.assertIs(0, widget.subviews.collapse_button.frame.t)
        luaunit.assertIs(config.DIRECTION.LEFT,
            widget.subviews.collapse_button.direction)
        luaunit.assertIs('[' .. string.char(16) .. ']',
            widget.subviews.collapse_button.text)
        luaunit.assertIs(nil, panel.visible)
    end)

    add_test('stats overlay: measures the vanilla unit-card tab strip', function()
        local overlay, state = env.load_stats_overlay(root, {
            focuses={'dwarfmode/ViewSheets/UNIT'}, unit={id=4}, width=264, height=75,
            screen_rows={[15]=string.rep(' ', 169) .. 'Overview   Items   Health'},
        })
        overlay.SoulSearchStatsOverlay{}:overlay_onupdate()
        luaunit.assertIs(167, state.unit_card_rect.x1)
        luaunit.assertIs(13, state.unit_card_rect.y1)
        luaunit.assertIs(263, state.unit_card_rect.x2)
        luaunit.assertIs(74, state.unit_card_rect.y2)
    end)

return native_tests
