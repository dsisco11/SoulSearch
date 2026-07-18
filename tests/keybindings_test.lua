local module_loader = require('support.module_loader')

local DEFAULT_SPEC = 'Ctrl-F@dwarfmode/Default'
local SOULSEARCH_COMMAND = 'gui/soulsearch'

local function load_keybindings(repo_root, hotkey)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/keybindings.lua',
        {dfhack={hotkey=hotkey}})
end

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('keybindings: adds the default when Ctrl-F is unclaimed', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function() return {} end,
            addKeybind=function(spec, command)
                table.insert(added, {spec=spec, command=command})
            end,
        })

        local result = keybindings.ensure_default()
        luaunit.assertIs('added', result.status)
        luaunit.assertEvalToTrue(result.binding_added)
        luaunit.assertIs(1, #added)
        luaunit.assertIs(DEFAULT_SPEC, added[1].spec)
        luaunit.assertIs(SOULSEARCH_COMMAND, added[1].command)
    end)

    add_test('keybindings: does not duplicate its existing Ctrl-F binding', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {{spec=DEFAULT_SPEC, command=SOULSEARCH_COMMAND}}
            end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })

        local result = keybindings.ensure_default()
        luaunit.assertIs('existing', result.status)
        luaunit.assertEvalToFalse(result.binding_added)
        luaunit.assertIs(0, #added)
    end)

    add_test('keybindings: does not replace another Ctrl-F binding', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {{spec=DEFAULT_SPEC, command='gui/launcher'}}
            end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })

        local result = keybindings.ensure_default()
        luaunit.assertIs('occupied', result.status)
        luaunit.assertEvalToFalse(result.binding_added)
        luaunit.assertIs(0, #added)
    end)

    add_test('keybindings: ignores bindings on other hotkeys', function()
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
        luaunit.assertIs('added', result.status)
        luaunit.assertIs(1, #added)
    end)

    add_test('keybindings: ignores malformed rows', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {false, {}, {spec=42, command='gui/launcher'}}
            end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })

        luaunit.assertIs('added', keybindings.ensure_default().status)
        luaunit.assertIs(1, #added)
    end)

    add_test('keybindings: unavailable APIs and add failures fail safely', function()
        local no_hotkey = load_keybindings(repo_root, nil)
        luaunit.assertIs('unavailable', no_hotkey.ensure_default().status)

        local failed = load_keybindings(repo_root, {
            listAllKeybinds=function() return {} end,
            addKeybind=function() error('add failed') end,
        })
        local result = failed.ensure_default()
        luaunit.assertIs('error', result.status)
        luaunit.assertEvalToFalse(result.binding_added)
    end)

return native_tests
