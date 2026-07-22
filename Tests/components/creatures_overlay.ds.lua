local creatures_scope = reqscript('internal/soulsearch/creatures_menu_scope')
local SoulSearchCommand = reqscript('soulsearch')
local CreaturesOverlay =
    reqscript('soulsearch-creatures-overlay').SoulSearchCreaturesOverlay

local original_get_active = creatures_scope.get_active
local original_initialize = SoulSearchCommand.initialize

local function scoped_options(label)
    return {
        label=label,
        options={
            settings_id='creatures:' .. label:lower():gsub('/', '-'),
            filters={{id='unit_scope:' .. label, direction='high'}},
        },
    }
end

---@param scope table|nil
---@return SoulSearchCreaturesOverlay overlay
local function mount_overlay(scope)
    creatures_scope.get_active = function() return scope end
    ds.mount(CreaturesOverlay, {
        overlay_position={x=1, y=1}, viewport={width=120, height=40},
    })
    return ds.root():raw()
end

describe('SoulSearch Creatures Overlay', function()
    after_each(function()
        creatures_scope.get_active = original_get_active
        SoulSearchCommand.initialize = original_initialize
    end)

    it('mounts and renders a launch button for every supported Creatures tab', function()
        for _, label in ipairs({'Residents', 'Pets/Livestock', 'Visitors'}) do
            local overlay = mount_overlay(scoped_options(label))

            assert.is_true(overlay.active())
            assert.is_true(ds.get('open_scoped_search'):inspect().visible)
            assert.equals('Open SoulSearch',
                ds.get('open_scoped_search'):raw().label.text[1].text)
            ds.unmount()
        end
    end)

    it('hides itself for unsupported tabs without initializing SoulSearch', function()
        local initialize = spy.new(function() end)
        SoulSearchCommand.initialize = initialize
        local overlay = mount_overlay(nil)

        assert.is_false(overlay.active())
        assert.is_false(overlay:open_scoped_search())
        assert.spy(initialize).was_not_called()
    end)

    it('opens SoulSearch with the active candidate scope from the launch button', function()
        local scope = scoped_options('Pets/Livestock')
        local open = spy.new(function(options)
            assert.same(scope.options, options)
            return {}
        end)
        local initialize = spy.new(function()
            return {['internal/soulsearch/ui']={open=open}}
        end)
        SoulSearchCommand.initialize = initialize
        mount_overlay(scope)

        ds.get('open_scoped_search'):click('left')

        assert.spy(initialize).was_called(1)
        assert.spy(open).was_called_with(scope.options)
    end)

    it('keeps the launch button docked through repeated overlay layout updates', function()
        local overlay = mount_overlay(scoped_options('Residents'))
        local button = overlay.subviews.open_scoped_search
        local initial = {l=overlay.frame.l, t=overlay.frame.t,
            w=overlay.frame.w, h=overlay.frame.h}

        overlay:overlay_onupdate()
        overlay:overlay_onupdate()

        assert.same(initial, overlay.frame)
        assert.equals(0, button.frame.r)
        assert.equals(1, button.frame.h)
        assert.equals(1, overlay.frame.h)
        ds.viewport(100, 32)
        assert.is_not_nil(overlay.frame)
        assert.is_true(overlay.frame.l >= 0)
        assert.is_true(overlay.frame.t >= 0)
    end)

    it('unmounts cleanly and mounts a fresh overlay instance afterward', function()
        local overlay = mount_overlay(scoped_options('Residents'))
        ds.unmount()

        local fresh = mount_overlay(scoped_options('Visitors'))
        assert.is_not_equal(overlay, fresh)
        assert.is_true(fresh.active())
    end)
end)
