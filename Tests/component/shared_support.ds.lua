local widgets = require('gui.widgets')
local fixtures = require('component.support.fixtures')
local live_unit = require('component.support.live_unit')

---@class tests.SoulSearchSupportPanel: widgets.Panel
local SupportPanel = defclass(nil, widgets.Panel)
SupportPanel.ATTRS{
    view_id='support_root',
    frame={w=24, h=3},
}

---Builds a stable descendant used to verify native traversal.
function SupportPanel:init()
    self:addviews{
        widgets.Label{
            view_id='support_status',
            frame={l=1, t=1, w=18},
            text='support mounted',
        },
    }
end

describe('SoulSearch shared component support', function()
    it('creates deterministic isolated fixtures', function()
        local first = fixtures.result()
        local second = fixtures.result()

        assert.equals('Urist McFixture', first.name)
        assert.equals('physical:STRENGTH', first.filter_criteria[1].id)
        first.row.skills.MINING = 0
        assert.equals(8, second.row.skills.MINING)
    end)

    it('provides Busted spies for component callbacks', function()
        local callback = spy.new(function() end)
        local result = fixtures.result()

        callback(result, nil, 'submitted')

        assert.spy(callback).was_called(1)
        assert.spy(callback).was_called_with(result, nil, 'submitted')
    end)

    it('selects a valid live unit without mutating it', function()
        local unit, source_or_error = live_unit.find()
        assert.is_not_nil(unit, source_or_error)
        local unit_id = unit.id

        assert.is_number(unit_id)
        assert.equals(unit_id, unit.id)
        assert.is_true(source_or_error == 'citizens'
            or source_or_error == 'active units')
    end)

    it('cleanup 1 leaves an owned component for DwarfSpec cleanup', function()
        ds.mount(SupportPanel)
        assert.equals('support mounted', ds.get('support_status'):text())
    end)

    it('cleanup 2 mounts after the preceding example was cleaned', function()
        local root = ds.mount(SupportPanel)
        assert.equals('support_root', root:inspect().view_id)
        assert.equals('support mounted', ds.get('support_status'):text())
    end)
end)
