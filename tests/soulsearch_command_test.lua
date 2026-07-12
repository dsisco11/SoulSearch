return function(test, repo_root)
    test.case('soulsearch command: reload repairs an incomplete registry environment', function()
        local separator = package.config:sub(1, 1)
        local path = repo_root .. separator ..
            'src/scripts_modinstalled/soulsearch.lua'
        local registry_state = 'incomplete'
        local clear_calls = {}
        local lifecycle = {}
        function lifecycle.prepare_for_world() lifecycle.prepared = true end
        local keybindings = {}
        function keybindings.ensure_default() keybindings.ensured = true end
        local ui = {}
        function ui.open(...) ui.opened_with = {...} end
        local registry = {
            MODULES={
                {name='internal/soulsearch/lifecycle'},
                {name='internal/soulsearch/ui'},
            },
            get_script_names=function()
                return {
                    'internal/soulsearch/module_registry',
                    'internal/soulsearch/ui',
                    'internal/soulsearch/lifecycle',
                }
            end,
            load_all=function()
                return {
                    ['internal/soulsearch/keybindings']=keybindings,
                    ['internal/soulsearch/lifecycle']=lifecycle,
                    ['internal/soulsearch/ui']=ui,
                }
            end,
        }
        local environment = {
            dfhack_flags={},
            dfhack={
                run_command=function(command, ...)
                    table.insert(clear_calls, {command, ...})
                    registry_state = 'ready'
                end,
                run_script=function(name)
                    table.insert(clear_calls, {'run_script', name})
                    registry_state = 'ready'
                end,
            },
            reqscript=function(name)
                if name == 'internal/soulsearch/module_registry' then
                    return registry_state == 'ready' and registry or {}
                end
                error('unexpected reqscript: ' .. tostring(name))
            end,
        }
        setmetatable(environment, {__index=_G})
        local chunk = assert(loadfile(path, 't', environment))
        chunk('reload')

        test.assert_sequence({
            'devel/clear-script-env',
            'internal/soulsearch/module_registry',
        }, clear_calls[1])
        test.assert_sequence({
            'run_script',
            'internal/soulsearch/module_registry',
        }, clear_calls[2])
        test.assert_sequence({
            'devel/clear-script-env',
            'internal/soulsearch/ui',
            'internal/soulsearch/lifecycle',
        }, clear_calls[3])
        test.assert_sequence({
            'run_script',
            'internal/soulsearch/lifecycle',
        }, clear_calls[4])
        test.assert_sequence({
            'run_script',
            'internal/soulsearch/ui',
        }, clear_calls[5])
        test.assert_true(lifecycle.prepared)
        test.assert_true(keybindings.ensured)
        test.assert_sequence({'reload'}, ui.opened_with)
    end)
end
