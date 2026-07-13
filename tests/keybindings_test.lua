local module_loader = require('support.module_loader')

local function load_keybindings(repo_root, hotkey)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/keybindings.lua',
        {dfhack={hotkey=hotkey}})
end

return function(test, repo_root)
    test.case('keybindings: adds the default when SoulSearch is unbound', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function() return {} end,
            addKeybind=function(spec, command)
                table.insert(added, {spec=spec, command=command})
            end,
        })
        test.assert_true(keybindings.ensure_default())
        test.assert_equal(1, #added)
        test.assert_equal('Ctrl-F@dwarfmode/Default', added[1].spec)
        test.assert_equal('gui/soulsearch', added[1].command)
    end)

    test.case('keybindings: preserves an existing SoulSearch GUI binding', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {{spec='Alt-S@dwarfmode', command='gui/soulsearch'}}
            end,
            addKeybind=function(spec, command)
                table.insert(added, {spec=spec, command=command})
            end,
        })
        test.assert_false(keybindings.ensure_default())
        test.assert_equal(0, #added)
    end)

    test.case('keybindings: unsupported GUI command arguments do not suppress the default', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {{spec='Alt-R', command='gui/soulsearch scoped'}}
            end,
            addKeybind=function(spec, command)
                table.insert(added, {spec=spec, command=command})
            end,
        })
        test.assert_true(keybindings.ensure_default())
        test.assert_equal(1, #added)
        test.assert_equal('gui/soulsearch', added[1].command)
    end)

    test.case('keybindings: initialization commands do not suppress the GUI default', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {{spec='Alt-R', command='soulsearch reload'}}
            end,
            addKeybind=function(spec, command)
                table.insert(added, {spec=spec, command=command})
            end,
        })
        test.assert_true(keybindings.ensure_default())
        test.assert_equal(1, #added)
        test.assert_equal('gui/soulsearch', added[1].command)
    end)

    test.case('keybindings: tolerates a DFHack without the hotkey API', function()
        local keybindings = load_keybindings(repo_root, nil)
        test.assert_false(keybindings.ensure_default())
    end)
end
