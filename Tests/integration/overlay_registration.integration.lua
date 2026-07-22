local overlay = require('plugins.overlay')

local STATS_SOURCE = 'src/scripts_modinstalled/soulsearch-stats-overlay.lua'
local CREATURES_SOURCE = 'src/scripts_modinstalled/soulsearch-creatures-overlay.lua'

local function stage(source, name)
    local staged = ds.stage_overlay_registration(source, name)
    assert.equals(1, #staged.registered_names)
    assert.is_string(staged.path)
    return staged, staged.registered_names[1]
end

local function exercise_registration(name, focus)
    local state = overlay.get_state()
    local registration = state.db[name]
    assert.is_table(registration)
    assert.is_table(registration.widget)
    assert.equals(focus, registration.widget.viewscreens)

    overlay.overlay_command({'enable', name}, true)
    assert.is_true(overlay.isOverlayEnabled(name))
    assert.is_table(overlay.get_state().config[name].pos)

    overlay.overlay_command({'disable', name}, true)
    assert.is_false(overlay.isOverlayEnabled(name))
end

describe('SoulSearch overlay registration integration', function()
    it('stages, rescans, enables, and disables both production overlays', function()
        local stats, stats_name = stage(STATS_SOURCE, 'soulsearch-stats')
        local creatures, creatures_name =
            stage(CREATURES_SOURCE, 'soulsearch-creatures')

        assert.equals('src/scripts_modinstalled/soulsearch-stats-overlay.lua',
            stats.source)
        assert.equals('src/scripts_modinstalled/soulsearch-creatures-overlay.lua',
            creatures.source)
        exercise_registration(stats_name, 'dwarfmode/ViewSheets/UNIT')
        exercise_registration(creatures_name, 'dwarfmode/Info/CREATURES')
    end)
end)
