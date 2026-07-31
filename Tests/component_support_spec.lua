local fixtures = require('component.support.fixtures')
local live_unit = require('component.support.live_unit')
local module_loader = require('support.module_loader')
local repo_root = require('support.repo_root')
local widget_harness = require('support.widget_harness')

---Loads the main screen against narrow constructor stubs for ID inspection.
---@return table main_screen
local function load_main_screen()
    local widgets = widget_harness.widgets()
    local modules = {
        ['internal/soulsearch/ui/widget_extensions']={},
        ['internal/soulsearch/screen_registry']={
            add=function() end,
            remove=function() end,
        },
        ['internal/soulsearch/ui/main_window']={
            SoulSearchWindow=function(info)
                info.persist_frame_if_needed = function() end
                return info
            end,
        },
        ['dwarfui/tooltip/api']={
            register=function() return true end,
            unregister=function() return true end,
        },
    }
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui/main_screen.lua', {
            DEFAULT_NIL={},
            defclass=widget_harness.defclass,
            dfhack={println=function() end},
            require=function(name)
                assert.equals('gui', name)
                return {ZScreen=widgets.Panel}
            end,
            reqscript=function(name)
                assert.is_not_nil(modules[name], name)
                return modules[name]
            end,
        })
end

describe('component support', function()
    it('creates all fixture shapes with deterministic defaults', function()
        local filter = fixtures.filter_choice()
        local custom = fixtures.preset_choice()
        local default = fixtures.preset_choice{kind='default'}
        local role = fixtures.preset_choice{kind='role'}
        local result = fixtures.result()
        local subject = fixtures.stats_subject()

        assert.equals('physical:STRENGTH', filter.descriptor.id)
        assert.equals('Mining team', custom.name)
        assert.equals('strong', default.default_id)
        assert.equals('miner', role.role_id)
        assert.equals(101, result.unit_id)
        assert.equals('Urist McFixture', subject.name)
    end)

    it('does not share mutable fixture defaults', function()
        local first = fixtures.result()
        local second = fixtures.result()

        first.row.traits.PATIENCE = 0
        first.filter_criteria[1] = nil

        assert.equals(62, second.row.traits.PATIENCE)
        assert.equals('physical:STRENGTH', second.filter_criteria[1].id)
    end)

    it('prefers citizens and only reads the selected unit', function()
        local unit = setmetatable({}, {__index=function(_, key)
            assert.equals('id', key)
            return 42
        end})
        local selected, source = live_unit.find{
            dfhack={
                isMapLoaded=function() return true end,
                units={getCitizens=function() return {unit} end},
            },
            df={global={world={units={active={{id=99}}}}}},
        }

        assert.equals(unit, selected)
        assert.equals('citizens', source)
    end)

    it('falls back to active units and reports unavailable maps', function()
        local selected, source = live_unit.find{
            dfhack={
                isMapLoaded=function() return true end,
                units={getCitizens=function() return {} end},
            },
            df={global={world={units={active={{id=99}}}}}},
        }
        assert.equals(99, selected.id)
        assert.equals('active units', source)

        local missing, reason = live_unit.find{
            dfhack={isMapLoaded=function() return false end},
            df={},
        }
        assert.is_nil(missing)
        assert.equals('a map must be loaded', reason)
    end)

    it('gives the main screen stable direct-child IDs', function()
        local main_screen = load_main_screen()
        local screen = main_screen.SoulSearchScreen{settings={}}

        assert.equals('window', screen.window.view_id)
        assert.equals(screen.window, screen.subviews.window)
        assert.is_nil(screen.tooltip)
        assert.is_nil(screen.subviews.tooltip)
    end)
end)
