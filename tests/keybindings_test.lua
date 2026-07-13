local module_loader = require('support.module_loader')

local function load_keybindings(repo_root, hotkey)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/keybindings.lua',
        {dfhack={hotkey=hotkey}})
end

local function preferences(status, mark_success)
    local state = {status=status or 'unset', marks=0}
    function state.read() return state.status end
    function state.mark_considered()
        state.marks = state.marks + 1
        if mark_success == false then return false, 'error' end
        state.status = 'considered'
        return true
    end
    return state
end

return function(test, repo_root)
    test.case('keybindings: adds the default on a pristine first install', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function() return {} end,
            addKeybind=function(spec, command)
                table.insert(added, {spec=spec, command=command})
            end,
        })
        local marker = preferences()
        local result = keybindings.ensure_default(marker)
        test.assert_equal('added', result.status)
        test.assert_true(result.binding_added)
        test.assert_equal(1, marker.marks)
        test.assert_equal(1, #added)
        test.assert_equal('Ctrl-F@dwarfmode/Default', added[1].spec)
        test.assert_equal('gui/soulsearch', added[1].command)
    end)

    test.case('keybindings: preserves existing seeded and custom bindings', function()
        for _, spec in ipairs({'Ctrl-F@dwarfmode/Default', 'Alt-S@dwarfmode'}) do
            local added = {}
            local keybindings = load_keybindings(repo_root, {
                listAllKeybinds=function()
                    return {{spec=spec, command='gui/soulsearch'}}
                end,
                addKeybind=function(...) table.insert(added, {...}) end,
            })
            local marker = preferences()
            local result = keybindings.ensure_default(marker)
            test.assert_equal('existing', result.status)
            test.assert_equal(1, marker.marks)
            test.assert_equal(0, #added)
        end
    end)

    test.case('keybindings: respects post-seed removal as an opt-out', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function() return {} end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })
        local marker = preferences('considered')
        local result = keybindings.ensure_default(marker)
        test.assert_equal('opted_out', result.status)
        test.assert_equal(0, marker.marks)
        test.assert_equal(0, #added)
    end)

    test.case('keybindings: repeated setup is idempotent across a simulated restart', function()
        local bindings, added = {}, {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function() return bindings end,
            addKeybind=function(spec, command)
                table.insert(added, {spec=spec, command=command})
                table.insert(bindings, {spec=spec, command=command})
            end,
        })
        local first_run_marker = preferences()
        test.assert_equal('added', keybindings.ensure_default(first_run_marker).status)

        local restarted_marker = preferences('considered')
        test.assert_equal('existing', keybindings.ensure_default(restarted_marker).status)
        test.assert_equal(1, #added)
        test.assert_equal(0, restarted_marker.marks)
    end)

    test.case('keybindings: ignores unsupported GUI arguments and malformed duplicate rows', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {
                    false,
                    {command='gui/soulsearch scoped'},
                    {command='gui/soulsearch scoped'},
                }
            end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })
        local result = keybindings.ensure_default(preferences())
        test.assert_equal('added', result.status)
        test.assert_equal(1, #added)
    end)

    test.case('keybindings: recognizes a valid binding among duplicate rows', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function()
                return {
                    {command='gui/soulsearch'},
                    {command='gui/soulsearch'},
                }
            end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })
        local result = keybindings.ensure_default(preferences())
        test.assert_equal('existing', result.status)
        test.assert_equal(0, #added)
    end)

    test.case('keybindings: missing or partial APIs remain unavailable without marking', function()
        local marker = preferences()
        local no_hotkey = load_keybindings(repo_root, nil)
        test.assert_equal('unavailable', no_hotkey.ensure_default(marker).status)
        test.assert_equal(0, marker.marks)

        local partial = load_keybindings(repo_root, {listAllKeybinds=function() return {} end})
        test.assert_equal('unavailable', partial.ensure_default(marker).status)
        test.assert_equal(0, marker.marks)
    end)

    test.case('keybindings: add failures do not record a decision', function()
        local marker = preferences()
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function() return {} end,
            addKeybind=function() error('add failed') end,
        })
        local result = keybindings.ensure_default(marker)
        test.assert_equal('error', result.status)
        test.assert_false(result.binding_added)
        test.assert_equal(0, marker.marks)
    end)

    test.case('keybindings: transient unavailable state retries cleanly', function()
        local added = {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function() return {} end,
            addKeybind=function(...) table.insert(added, {...}) end,
        })
        test.assert_equal('unavailable', keybindings.ensure_default(preferences('unavailable')).status)
        test.assert_equal('added', keybindings.ensure_default(preferences()).status)
        test.assert_equal(1, #added)
    end)

    test.case('keybindings: marker-write failure retries without a duplicate binding', function()
        local bindings, added = {}, {}
        local keybindings = load_keybindings(repo_root, {
            listAllKeybinds=function() return bindings end,
            addKeybind=function(spec, command)
                table.insert(added, {spec=spec, command=command})
                table.insert(bindings, {spec=spec, command=command})
            end,
        })
        local failed_marker = preferences('unset', false)
        local first = keybindings.ensure_default(failed_marker)
        test.assert_equal('error', first.status)
        test.assert_true(first.binding_added)
        test.assert_equal(1, #added)

        local retry_marker = preferences()
        local second = keybindings.ensure_default(retry_marker)
        test.assert_equal('existing', second.status)
        test.assert_equal(1, retry_marker.marks)
        test.assert_equal(1, #added)
    end)
end
