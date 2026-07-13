local function script_path(repo_root, relative_path)
    local separator = package.config:sub(1, 1)
    return repo_root .. separator .. relative_path:gsub('[/\\]', separator)
end

local function load_script(path, environment)
    setmetatable(environment, {__index=_G})
    return assert(loadfile(path, 't', environment))
end

return function(test, repo_root)
    local command_path = script_path(repo_root, 'src/scripts_modinstalled/soulsearch.lua')
    local gui_path = script_path(repo_root, 'src/scripts_modinstalled/gui/soulsearch.lua')

    test.case('soulsearch command: normal invocation prepares without opening UI', function()
        local lifecycle = {}
        function lifecycle.prepare_for_world() lifecycle.prepared = true end
        local keybindings = {}
        function keybindings.ensure_default() keybindings.ensured = true end
        local ui = {open_count=0}
        function ui.open() ui.open_count = ui.open_count + 1 end
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
        local chunk = load_script(command_path, {
            dfhack_flags={},
            dfhack={},
            reqscript=function(name)
                assert(name == 'internal/soulsearch/module_registry')
                return registry
            end,
        })
        chunk()

        test.assert_true(lifecycle.prepared)
        test.assert_true(keybindings.ensured)
        test.assert_equal(0, ui.open_count)
    end)

    test.case('soulsearch module load: bootstraps keybindings without loading the full runtime', function()
        local lifecycle = {}
        function lifecycle.prepare_for_world() lifecycle.prepared = true end
        local keybindings = {}
        function keybindings.ensure_default()
            keybindings.ensured = true
            return {status='added'}
        end
        local environment = {
            dfhack_flags={module=true},
            dfhack={},
            reqscript=function(name)
                assert(name == 'internal/soulsearch/keybindings')
                return keybindings
            end,
        }
        local chunk = load_script(command_path, environment)
        chunk()

        test.assert_equal('function', type(environment.initialize))
        test.assert_false(lifecycle.prepared)
        test.assert_true(keybindings.ensured)
        test.assert_true(environment.isEnabled())
    end)

    test.case('soulsearch module load: preserves an explicit disabled state', function()
        local requested = 0
        local environment = {
            bootstrap_enabled=false,
            dfhack_flags={module=true},
            dfhack={},
            reqscript=function()
                requested = requested + 1
                error('disabled bootstrap must not load dependencies')
            end,
        }
        load_script(command_path, environment)()

        test.assert_false(environment.isEnabled())
        test.assert_equal(0, requested)
    end)

    test.case('soulsearch enable and disable flags only control bootstrap state', function()
        local keybindings = {calls=0}
        function keybindings.ensure_default()
            keybindings.calls = keybindings.calls + 1
            return {status='added'}
        end
        local environment = {
            dfhack_flags={enable=true, enable_state=true},
            dfhack={},
            reqscript=function(name)
                assert(name == 'internal/soulsearch/keybindings')
                return keybindings
            end,
        }
        load_script(command_path, environment)()
        test.assert_true(environment.isEnabled())
        test.assert_equal(1, keybindings.calls)

        environment.dfhack_flags = {enable=true, enable_state=false}
        load_script(command_path, environment)()
        test.assert_false(environment.isEnabled())
        test.assert_equal(1, keybindings.calls)
    end)

    test.case('soulsearch command: explicit initialization remains usable while bootstrap is disabled', function()
        local lifecycle = {}
        function lifecycle.prepare_for_world() lifecycle.prepared = true end
        local keybindings = {}
        function keybindings.ensure_default() keybindings.ensured = true end
        local registry = {
            load_all=function()
                return {
                    ['internal/soulsearch/keybindings']=keybindings,
                    ['internal/soulsearch/lifecycle']=lifecycle,
                }
            end,
            get_script_names=function() return {} end,
        }
        local environment = {
            bootstrap_enabled=false,
            dfhack_flags={},
            dfhack={},
            reqscript=function(name)
                assert(name == 'internal/soulsearch/module_registry')
                return registry
            end,
        }
        load_script(command_path, environment)()

        test.assert_false(environment.isEnabled())
        test.assert_true(keybindings.ensured)
        test.assert_true(lifecycle.prepared)
    end)

    test.case('gui/soulsearch: initializes then opens without arguments', function()
        local initialized = 0
        local ui = {open_count=0}
        function ui.open(...)
            ui.open_count = ui.open_count + 1
            ui.opened_with = {...}
        end
        local chunk = load_script(gui_path, {
            reqscript=function(name)
                assert(name == 'soulsearch')
                return {
                    initialize=function()
                        initialized = initialized + 1
                        return {['internal/soulsearch/ui']=ui}
                    end,
                }
            end,
        })
        chunk()

        test.assert_equal(1, initialized)
        test.assert_equal(1, ui.open_count)
        test.assert_equal(0, #ui.opened_with)
    end)

    test.case('soulsearch command: reload repairs an incomplete registry environment without opening UI', function()
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
        local chunk = load_script(command_path, {
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
        })
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
        test.assert_equal(1, old_ui.dismiss_count)
        test.assert_true(lifecycle.prepared)
        test.assert_true(keybindings.ensured)
        test.assert_equal(0, new_ui.open_count)
    end)
end
