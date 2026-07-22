local live_unit = require('tests.components.support.live_unit')
local popover = reqscript('internal/soulsearch/stats_popover')
local StatsOverlay = reqscript('soulsearch-stats-overlay').SoulSearchStatsOverlay

---Finds a real resident which the production stats adapter can display.
---@return df.unit unit
---@return SoulSearchStatsSubject subject
local function find_displayable_unit()
    local citizens = dfhack.units.getCitizens(false, true)
    for _, unit in pairs(citizens) do
        local subject = popover.get_subject(unit)
        if subject then return unit, subject end
    end

    local unit, reason = live_unit.find()
    assert.is_truthy(unit, reason)
    local subject, err = popover.get_subject(unit)
    assert.is_truthy(subject, err)
    return unit, subject
end

---Finds two real residents that can populate the production stats panel.
---@return df.unit first
---@return df.unit second
local function find_displayable_units()
    local matches = {}
    for _, unit in pairs(dfhack.units.getCitizens(false, true)) do
        if popover.get_subject(unit) then
            matches[#matches + 1] = unit
            if #matches == 2 then return matches[1], matches[2] end
        end
    end
    error('Stats Overlay component tests require two displayable residents.')
end

---Mounts the real overlay at a deterministic, isolated viewport position.
---@return SoulSearchStatsOverlay overlay
---@return df.unit unit
---@return SoulSearchStatsSubject subject
local function mount_overlay()
    local unit, subject = find_displayable_unit()
    ds.mount(StatsOverlay, {
        overlay_position={x=1, y=1},
        viewport={width=120, height=40},
    })
    local overlay = ds.root():raw()
    overlay:update_subject(unit)
    return overlay, unit, subject
end

describe('SoulSearch Stats Overlay', function()
    it('mounts the production overlay and renders a live resident stat subject', function()
        local overlay, unit, subject = mount_overlay()
        local panel = overlay.subviews.window.subviews.stats_panel

        assert.equals(unit.id, panel.subject.unit.id)
        assert.equals(subject.unit_id, panel.subject.unit_id)
        assert.is_true(#panel.stats_records > 0)
        assert.is_true(#ds.get('window/stats_panel/body'):text() > 0)
    end)

    it('collapses and expands the mounted panel without losing its live subject', function()
        local overlay = mount_overlay()
        ds.get('collapse_button'):click('left')

        assert.is_true(overlay.collapsed)
        assert.is_false(overlay.subviews.window.visible)
        assert.is_true(overlay.subviews.expand_button.visible)

        ds.get('expand_button'):click('left')
        assert.is_false(overlay.collapsed)
        assert.is_true(overlay.subviews.window.visible)
        assert.is_not_nil(overlay.subviews.window.subviews.stats_panel.subject)
        assert.is_true(#overlay.subviews.window.subviews.stats_panel.stats_records > 0)
    end)

    it('sorts rendered stats through the mounted column header', function()
        local overlay = mount_overlay()
        local panel = overlay.subviews.window.subviews.stats_panel
        local before = panel:get_sort()

        ds.get('window/stats_panel/value_column'):raw().on_change()
        assert.equals('value', panel:get_sort().key)
        assert.is_not_equal(before.reverse, panel:get_sort().reverse)
    end)

    it('refreshes the rendered subject when the selected resident changes', function()
        local overlay = mount_overlay()
        local first, second = find_displayable_units()
        local panel = overlay.subviews.window.subviews.stats_panel

        overlay:update_subject(first)
        assert.equals(first.id, panel.subject.unit_id)
        overlay:update_subject(second)
        assert.equals(second.id, panel.subject.unit_id)
        assert.is_true(#panel.stats_records > 0)
    end)

    it('clears stale resident data when the unit card has no selected unit', function()
        local overlay = mount_overlay()
        local panel = overlay.subviews.window.subviews.stats_panel
        assert.is_not_nil(panel.subject)

        overlay:update_subject(nil)

        assert.is_nil(overlay.unit_id)
        assert.is_nil(panel.subject)
        assert.equals(0, #panel.stats_records)
        assert.equals('', ds.get('window/stats_panel/body'):text())
    end)

    it('keeps a usable panel frame and correct docking arrows across viewports', function()
        local overlay = mount_overlay()
        local panel = overlay.subviews.window
        local collapse = overlay.subviews.collapse_button
        local expand = overlay.subviews.expand_button

        assert.is_not_nil(collapse.text)
        ds.viewport(100, 32)
        assert.is_not_nil(panel.frame)

        ds.get('collapse_button'):click('left')
        assert.is_not_nil(expand.text)
        ds.viewport(140, 50)
        assert.is_not_nil(overlay.frame)
        assert.is_not_nil(panel.frame)
    end)

    it('renders header and stat-body tooltips above the clipped overlay', function()
        local overlay = mount_overlay()

        local stats = overlay.subviews.window.subviews.stats_panel
        local body = stats.subviews.body
        stats:update_body_tooltip(body, 0, 0)
        assert.is_string(body.tooltip)
        assert.equals(overlay, overlay.tooltip.parent_view)
    end)

    it('unmounts the overlay and gives a later mount fresh UI state', function()
        local overlay = mount_overlay()
        ds.get('collapse_button'):click('left')
        assert.is_true(overlay.collapsed)

        ds.unmount()
        ds.mount(StatsOverlay, {
            overlay_position={x=1, y=1}, viewport={width=120, height=40},
        })
        local fresh = ds.root():raw()
        assert.is_false(fresh.collapsed)
        assert.is_true(fresh.subviews.window.visible)
        assert.is_not_equal(overlay.collapsed, fresh.collapsed)
    end)
end)
