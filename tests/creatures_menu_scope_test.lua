local module_loader = require('support.module_loader')

local CONSTANTS = {
    direction={HIGH='high'},
    unit_scope={
        id_prefix='unit_scope:',
        FORT_RESIDENTS='fort_residents',
        CITIZENS_AND_PETS='citizens_and_pets',
        VISITORS='visitors',
    },
    race={
        group_id_prefix='race:group:',
        group={
            HUMANOIDS='HUMANOIDS',
            TAMEABLE_ANIMALS='TAMEABLE_ANIMALS',
        },
    },
}

local function load_scope(repo_root, focus_by_screen, top_screen, tab_label)
    local tabs = {cur_idx=0, tab_labels={[0]=tab_label}}
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/creatures_menu_scope.lua', {
            df={global={game={main_interface={info={creatures={}}}}}},
            dfhack={gui={
                getCurViewscreen=function() return top_screen end,
                getFocusStrings=function(screen)
                    return focus_by_screen[screen] or {}
                end,
                getWidget=function(_, name)
                    if name == 'Tabs' then return tabs end
                end,
            }},
            reqscript=function(name)
                assert(name == 'internal/soulsearch/filter_constants')
                return {FILTER_CONSTANTS=CONSTANTS}
            end,
        })
end

return function(test, repo_root)
    test.case('creatures menu scope: maps supported tabs to explicit candidate presets', function()
        local screen = {}
        local focuses = {[screen]={'dwarfmode/Info/CREATURES/Residents'}}
        local scope = load_scope(repo_root, focuses, screen)

        local residents = scope.get_active()
        test.assert_equal('Residents', residents.label)
        test.assert_equal('creatures:residents', residents.options.settings_id)
        test.assert_equal('unit_scope:fort_residents', residents.options.filters[1].id)
        test.assert_equal('race:group:HUMANOIDS', residents.options.filters[2].id)
        test.assert_equal('high', residents.options.filters[1].direction)

        focuses[screen] = {'dwarfmode/Info/CREATURES/Pets/Livestock'}
        local pets = scope.get_active()
        test.assert_equal('Pets/Livestock', pets.label)
        test.assert_equal('creatures:pets-livestock', pets.options.settings_id)
        test.assert_equal('unit_scope:citizens_and_pets', pets.options.filters[1].id)
        test.assert_equal('race:group:TAMEABLE_ANIMALS', pets.options.filters[2].id)
        test.assert_equal('high', pets.options.filters[1].direction)

        focuses[screen] = {'dwarfmode/Info/CREATURES/Visitors'}
        local visitors = scope.get_active()
        test.assert_equal('Visitors', visitors.label)
        test.assert_equal('unit_scope:visitors', visitors.options.filters[1].id)
    end)

    test.case('creatures menu scope: resolves the suffix-free Residents focus from vanilla tabs', function()
        local screen = {}
        local focuses = {[screen]={'dwarfmode/Info/CREATURES'}}
        local scope = load_scope(repo_root, focuses, screen, 'Residents')
        test.assert_equal('Residents', scope.get_active().label)

        scope = load_scope(repo_root, focuses, screen, 'Dead/Missing')
        test.assert_nil(scope.get_active())
    end)

    test.case('creatures menu scope: accepts live focus names and rejects unrelated contexts', function()
        local screen = {}
        local focuses = {[screen]={'dwarfmode/Info/CREATURES/CITIZEN'}}
        local scope = load_scope(repo_root, focuses, screen)
        test.assert_equal('Residents', scope.get_active().label)

        focuses[screen] = {'dwarfmode/Info/CREATURES/Others'}
        test.assert_equal('Visitors', scope.get_active().label)
        test.assert_nil(scope.get_from_focuses({'dwarfmode/ViewSheets/UNIT'}))
    end)

    test.case('creatures menu scope: returns fresh options and finds an underlying menu', function()
        local creatures = {}
        local launcher = {parent=creatures}
        local scope = load_scope(repo_root, {
            [creatures]={'dwarfmode/Info/CREATURES/Pets'},
            [launcher]={'dfhack/lua/launcher'},
        }, launcher)

        local first = scope.get_active()
        first.options.filters[2].id = 'changed'
        local second = scope.get_active()
        test.assert_equal('race:group:TAMEABLE_ANIMALS', second.options.filters[2].id)
    end)
end
