local module_loader = require('support.module_loader')

local DEFAULT_SPEC = 'Ctrl-F@dwarfmode/Default'
local SOULSEARCH_COMMAND = 'gui/soulsearch'

local function load_keybindings(repo_root, hotkey)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/keybindings.lua',
        {dfhack={hotkey=hotkey}})
end

local repo_root = require('support.repo_root')

describe('keybindings', function()

    it('keybindings: adds the default when Ctrl-F is unclaimed', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function() return {} end,
            addKeybind=function(spec, command)
                table.insert(added, {spec=spec, command=command})
            end,
        })

        local result = keybindings.ensure_default()
        assert.are.equal('added', result.status)
        assert.is_truthy(result.binding_added)
        assert.are.equal(1, #added)
        assert.are.equal(DEFAULT_SPEC, added[1].spec)
        assert.are.equal(SOULSEARCH_COMMAND, added[1].command)
    end)

    it('keybindings: does not duplicate its existing Ctrl-F binding', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {{spec=DEFAULT_SPEC, command=SOULSEARCH_COMMAND}}
            end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })

        local result = keybindings.ensure_default()
        assert.are.equal('existing', result.status)
        assert.is_falsy(result.binding_added)
        assert.are.equal(0, #added)
    end)

    it('keybindings: does not replace another Ctrl-F binding', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {{spec=DEFAULT_SPEC, command='gui/launcher'}}
            end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })

        local result = keybindings.ensure_default()
        assert.are.equal('occupied', result.status)
        assert.is_falsy(result.binding_added)
        assert.are.equal(0, #added)
    end)

    it('keybindings: ignores bindings on other hotkeys', function()
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
        assert.are.equal('added', result.status)
        assert.are.equal(1, #added)
    end)

    it('keybindings: ignores malformed rows', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {false, {}, {spec=42, command='gui/launcher'}}
            end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })

        assert.are.equal('added', keybindings.ensure_default().status)
        assert.are.equal(1, #added)
    end)

    it('keybindings: unavailable APIs and add failures fail safely', function()
        local no_hotkey = load_keybindings(repo_root, nil)
        assert.are.equal('unavailable', no_hotkey.ensure_default().status)

        local failed = load_keybindings(repo_root, {
            listAllKeybinds=function() return {} end,
            addKeybind=function() error('add failed') end,
        })
        local result = failed.ensure_default()
        assert.are.equal('error', result.status)
        assert.is_falsy(result.binding_added)
    end)

end)
