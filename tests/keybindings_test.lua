local module_loader = require('support.module_loader')

local DEFAULT_SPEC = 'Ctrl-F@dwarfmode/Default'
local SOULSEARCH_COMMAND = 'gui/soulsearch'

local function load_keybindings(repo_root, hotkey)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/keybindings.lua',
        {dfhack={hotkey=hotkey}})
end

return function(test, repo_root)
    test.case('keybindings: adds the default when Ctrl-F is unclaimed', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function() return {} end,
            addKeybind=function(spec, command)
                table.insert(added, {spec=spec, command=command})
            end,
        })

        local result = keybindings.ensure_default()
        test.assert_equal('added', result.status)
        test.assert_true(result.binding_added)
        test.assert_equal(1, #added)
        test.assert_equal(DEFAULT_SPEC, added[1].spec)
        test.assert_equal(SOULSEARCH_COMMAND, added[1].command)
    end)

    test.case('keybindings: does not duplicate its existing Ctrl-F binding', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {{spec=DEFAULT_SPEC, command=SOULSEARCH_COMMAND}}
            end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })

        local result = keybindings.ensure_default()
        test.assert_equal('existing', result.status)
        test.assert_false(result.binding_added)
        test.assert_equal(0, #added)
    end)

    test.case('keybindings: does not replace another Ctrl-F binding', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {{spec=DEFAULT_SPEC, command='gui/launcher'}}
            end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })

        local result = keybindings.ensure_default()
        test.assert_equal('occupied', result.status)
        test.assert_false(result.binding_added)
        test.assert_equal(0, #added)
    end)

    test.case('keybindings: ignores bindings on other hotkeys', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {
                    {spec='Alt-S@dwarfmode/Default', command=SOULSEARCH_COMMAND},
                    {spec='Ctrl-G@dwarfmode/Default', command='gui/launcher'},
                }
            end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })

        local result = keybindings.ensure_default()
        test.assert_equal('added', result.status)
        test.assert_equal(1, #added)
    end)

    test.case('keybindings: ignores malformed rows', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {false, {}, {spec=42, command='gui/launcher'}}
            end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })

        test.assert_equal('added', keybindings.ensure_default().status)
        test.assert_equal(1, #added)
    end)

    test.case('keybindings: unavailable APIs and add failures fail safely', function()
        local no_hotkey = load_keybindings(repo_root, nil)
        test.assert_equal('unavailable', no_hotkey.ensure_default().status)

        local failed = load_keybindings(repo_root, {
            listAllKeybinds=function() return {} end,
            addKeybind=function() error('add failed') end,
        })
        local result = failed.ensure_default()
        test.assert_equal('error', result.status)
        test.assert_false(result.binding_added)
    end)
end
