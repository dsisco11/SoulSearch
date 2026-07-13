return function(test, repo_root)
    test.case('soulsearch command: normal invocation prepares and opens without arguments', function()
        local separator = package.config:sub(1, 1)
        local path = repo_root .. separator ..
            'src/scripts_modinstalled/soulsearch.lua'
        local lifecycle = {}
        function lifecycle.prepare_for_world() lifecycle.prepared = true end
        local keybindings = {}
        function keybindings.ensure_default() keybindings.ensured = true end
        local ui = {}
        function ui.open(...) ui.opened_with = {...} end
        local registry = {
            load_all=function()
                return {
                    ['internal/soulsearch/keybindings']=keybindings,
                    ['internal/soulsearch/lifecycle']=lifecycle,
                    ['internal/soulsearch/ui']=ui,
                }
            end,
            get_script_names=function() return {} end,
        }
        local environment = {
            dfhack_flags={},
            dfhack={},
            reqscript=function(name)
                assert(name == 'internal/soulsearch/module_registry')
                return registry
            end,
        }
        setmetatable(environment, {__index=_G})
        local chunk = assert(loadfile(path, 't', environment))
        chunk()

        test.assert_true(lifecycle.prepared)
        test.assert_true(keybindings.ensured)
        test.assert_equal(0, #ui.opened_with)
    end)

    test.case('soulsearch command: reload repairs an incomplete registry environment', function()
        local separator = package.config:sub(1, 1)
        local path = repo_root .. separator ..
            'src/scripts_modinstalled/soulsearch.lua'
        local registry_state = 'incomplete'
        local events = {}
        local lifecycle = {}
        function lifecycle.prepare_for_world()
            lifecycle.prepared = true
            table.insert(events, {'prepare'})
        end
        local keybindings = {}
        function keybindings.ensure_default()
            keybindings.ensured = true
            table.insert(events, {'keybindings'})
        end
        local old_ui = {dismiss_count=0}
        function old_ui.dismiss_all()
            old_ui.dismiss_count = old_ui.dismiss_count + 1
            table.insert(events, {'dismiss_all'})
        end
        local new_ui = {open_count=0}
        function new_ui.open(...)
            new_ui.open_count = new_ui.open_count + 1
            new_ui.opened_with = {...}
            table.insert(events, {'open'})
        end
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
                    ['internal/soulsearch/ui']=new_ui,
                }
            end,
        }
        local environment = {
            dfhack_flags={},
            dfhack={
                run_command=function(command, ...)
                    table.insert(events, {command, ...})
                    registry_state = 'ready'
                end,
                run_script=function(name)
                    table.insert(events, {'run_script', name})
                    registry_state = 'ready'
                end,
            },
            reqscript=function(name)
                if name == 'internal/soulsearch/module_registry' then
                    return registry_state == 'ready' and registry or {}
                end
                if name == 'internal/soulsearch/ui' then return old_ui end
                error('unexpected reqscript: ' .. tostring(name))
            end,
        }
        setmetatable(environment, {__index=_G})
        local chunk = assert(loadfile(path, 't', environment))
        chunk('reload')

        test.assert_sequence({
            'devel/clear-script-env',
            'internal/soulsearch/module_registry',
        }, events[1])
        test.assert_sequence({
            'run_script',
            'internal/soulsearch/module_registry',
        }, events[2])
        test.assert_sequence({'dismiss_all'}, events[3])
        test.assert_sequence({
            'devel/clear-script-env',
            'internal/soulsearch/ui',
            'internal/soulsearch/lifecycle',
        }, events[4])
        test.assert_sequence({
            'run_script',
            'internal/soulsearch/lifecycle',
        }, events[5])
        test.assert_sequence({
            'run_script',
            'internal/soulsearch/ui',
        }, events[6])
        test.assert_sequence({'keybindings'}, events[7])
        test.assert_sequence({'prepare'}, events[8])
        test.assert_sequence({'open'}, events[9])
        test.assert_equal(1, old_ui.dismiss_count)
        test.assert_true(lifecycle.prepared)
        test.assert_true(keybindings.ensured)
        test.assert_equal(1, new_ui.open_count)
        test.assert_equal(0, #new_ui.opened_with)
    end)
end
