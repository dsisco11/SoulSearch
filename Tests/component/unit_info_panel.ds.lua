local gui = require('gui')
local fixtures = require('component.support.fixtures')
local UnitInfoPanel = reqscript('internal/soulsearch/stats_panel').UnitInfoPanel

---@class tests.UnitInfoPanelScreen: gui.ZScreen
---@field panel UnitInfoPanel
local UnitInfoPanelScreen = defclass(nil, gui.ZScreen)
UnitInfoPanelScreen.ATTRS{focus_path='soulsearch/unit-info-panel-test'}

---Builds the production unit-information panel with deterministic stat data.
function UnitInfoPanelScreen:init()
    self.panel = UnitInfoPanel{view_id='unit_info', frame={l=0, t=0, w=64, h=14},
        subject=fixtures.stats_subject(), sort={key='value', reverse=true, phase=1}}
    self:addviews{self.panel}
end

---Mounts the unit-information component fixture.
---@return UnitInfoPanel panel
local function mount_panel()
    ds.mount(UnitInfoPanelScreen)
    return ds.get('unit_info'):raw()
end

describe('SoulSearch Unit Information', function()
    it('renders identity, selected criteria, and meaningful stat records', function()
        mount_panel()
        assert.equals('Urist McFixture', ds.get('unit_info/unit_identity/name'):text())
        assert.equals('Miner', ds.get('unit_info/unit_identity/title'):text())
        assert.is_true(ds.get('unit_info/matched_filters'):raw():get_height() > 0)
        assert.is_true(#ds.get('unit_info/stats_list'):raw().stats_records > 0)
    end)

    it('replaces and clears all subject-dependent content', function()
        local panel = mount_panel()
        panel:set_subject(fixtures.stats_subject({name='Domas', profession='Mason',
            filter_criteria={}}))
        assert.equals('Domas', ds.get('unit_info/unit_identity/name'):text())
        assert.equals(0, ds.get('unit_info/matched_filters'):raw():get_height())
        panel:set_subject(nil)
        assert.equals('No unit selected.', ds.get('unit_info/unit_identity/name'):text())
        assert.equals(0, #ds.get('unit_info/stats_list'):raw().stats_records)
    end)

    it('cycles stat sorting and restores requested sort and scroll position', function()
        local panel = mount_panel()
        panel:cycle_sort('label')
        assert.equals('label', panel:get_sort().key)
        panel:cycle_sort('value')
        assert.equals('value', panel:get_sort().key)
        local stats = ds.get('unit_info/stats_list'):raw()
        stats.subviews.body.start_line_num = 4
        panel:reset_view_state({key='label', reverse=false, phase=1})
        assert.equals('label', panel:get_sort().key)
        assert.equals(1, stats.subviews.body.start_line_num)
    end)

    it('provides stat-label and baseline-difference tooltips', function()
        mount_panel()
        local stats = ds.get('unit_info/stats_list'):raw()
        local body = stats.subviews.body
        stats:update_body_tooltip(body, 2, 0)
        assert.is_string(body.tooltip)
        stats:update_body_tooltip(body, 30, 0)
        assert.equals('Difference from the attribute average.', body.tooltip)
    end)
end)
