local function script_path(repo_root, relative_path)
    local separator = package.config:sub(1, 1)
    return repo_root .. separator .. relative_path:gsub('[/\\]', separator)
end

local function load_script(path, environment)
    setmetatable(environment, {__index=_G})
    return assert(loadfile(path, 't', environment))
end

local repo_root = require('support.repo_root')

describe('soulsearch command', function()

    local command_path = script_path(repo_root, 'src/scripts_modinstalled/soulsearch.lua')
    local gui_path = script_path(repo_root, 'src/scripts_modinstalled/gui/soulsearch.lua')

    it('soulsearch command: normal invocation uses native imports without clearing or opening UI', function()
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
        local reload_commands = 0
        local chunk = load_script(command_path, {
            dfhack_flags={},
            dfhack={
                run_command=function() reload_commands = reload_commands + 1 end,
                run_script=function() reload_commands = reload_commands + 1 end,
            },
            reqscript=function(name)
                assert(name == 'internal/soulsearch/module_registry')
                return registry
            end,
        })
        chunk()

        assert.is_truthy(lifecycle.prepared)
        assert.is_truthy(keybindings.ensured)
        assert.are.equal(0, ui.open_count)
        assert.are.equal(0, reload_commands)
    end)

    it('soulsearch module load: bootstraps keybindings without loading the full runtime', function()
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

        assert.are.equal('function', type(environment.initialize))
        assert.is_falsy(lifecycle.prepared)
        assert.is_truthy(keybindings.ensured)
        assert.is_truthy(environment.isEnabled())
    end)

    it('soulsearch module load: preserves an explicit disabled state', function()
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

        assert.is_falsy(environment.isEnabled())
        assert.are.equal(0, requested)
    end)

    it('soulsearch module load: repeated scans leave setup idempotent', function()
        local keybindings = {calls=0, added=0}
        function keybindings.ensure_default()
            keybindings.calls = keybindings.calls + 1
            if keybindings.calls == 1 then
                keybindings.added = keybindings.added + 1
                return {status='added'}
            end
            return {status='existing'}
        end
        local environment = {
            dfhack_flags={module=true},
            dfhack={},
            reqscript=function(name)
                assert(name == 'internal/soulsearch/keybindings')
                return keybindings
            end,
        }
        load_script(command_path, environment)()
        load_script(command_path, environment)()

        assert.is_truthy(environment.isEnabled())
        assert.are.equal(2, keybindings.calls)
        assert.are.equal(1, keybindings.added)
    end)

    it('soulsearch module load: unavailable setup fails soft without loading the runtime', function()
        local requested = 0
        local environment = {
            dfhack_flags={module=true},
            dfhack={},
            reqscript=function(name)
                requested = requested + 1
                assert(name == 'internal/soulsearch/keybindings')
                return {ensure_default=function() return {status='unavailable'} end}
            end,
        }
        local ok = pcall(load_script(command_path, environment))

        assert.is_truthy(ok)
        assert.is_truthy(environment.isEnabled())
        assert.are.equal(1, requested)
    end)

    it('soulsearch enable and disable flags only control bootstrap state', function()
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
        assert.is_truthy(environment.isEnabled())
        assert.are.equal(1, keybindings.calls)

        environment.dfhack_flags = {enable=true, enable_state=false}
        load_script(command_path, environment)()
        assert.is_falsy(environment.isEnabled())
        assert.are.equal(1, keybindings.calls)
    end)

    it('soulsearch command: explicit initialization remains usable while bootstrap is disabled', function()
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

        assert.is_falsy(environment.isEnabled())
        assert.is_truthy(keybindings.ensured)
        assert.is_truthy(lifecycle.prepared)
    end)

    it('soulsearch command: manual setup retries an unavailable bootstrap result', function()
        local lifecycle = {}
        function lifecycle.prepare_for_world() lifecycle.prepared = true end
        local keybindings = {calls=0}
        function keybindings.ensure_default()
            keybindings.calls = keybindings.calls + 1
            return {status=keybindings.calls == 1 and 'unavailable' or 'added'}
        end
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
            dfhack_flags={module=true},
            dfhack={},
            reqscript=function(name)
                if name == 'internal/soulsearch/keybindings' then return keybindings end
                assert(name == 'internal/soulsearch/module_registry')
                return registry
            end,
        }
        load_script(command_path, environment)()
        environment.initialize()

        assert.are.equal(2, keybindings.calls)
        assert.is_truthy(lifecycle.prepared)
    end)

    it('gui/soulsearch: initializes then opens without arguments', function()
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

        assert.are.equal(1, initialized)
        assert.are.equal(1, ui.open_count)
        assert.are.equal(0, #ui.opened_with)
    end)

    it('gui/soulsearch: remains a fallback while bootstrap is disabled or missed', function()
        local initialized, opened = 0, 0
        local chunk = load_script(gui_path, {
            reqscript=function(name)
                assert(name == 'soulsearch')
                return {
                    isEnabled=function() return false end,
                    initialize=function()
                        initialized = initialized + 1
                        return {['internal/soulsearch/ui']={
                            open=function() opened = opened + 1 end,
                        }}
                    end,
                }
            end,
        })
        chunk()

        assert.are.equal(1, initialized)
        assert.are.equal(1, opened)
    end)

    it('soulsearch command: invalid arguments preserve the usage contract', function()
        local usage
        local chunk = load_script(command_path, {
            dfhack_flags={},
            dfhack={},
            qerror=function(message) usage = message; error(message) end,
            reqscript=function() error('invalid arguments must not load modules') end,
        })
        local ok = pcall(chunk, 'invalid')

        assert.is_falsy(ok)
        assert.are.equal('Usage: soulsearch [reload]', usage)
    end)

    it('soulsearch command: reload reconstructs from a fresh registry without opening UI', function()
        local registry_state = 'incomplete'
        local registry_runs = 0
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
        local old_navigator = {cancel_count=0}
        function old_navigator.cancel()
            old_navigator.cancel_count = old_navigator.cancel_count + 1
            table.insert(events, {'cancel_navigation'})
        end
        local new_ui = {open_count=0}
        function new_ui.open(...)
            new_ui.open_count = new_ui.open_count + 1
            new_ui.opened_with = {...}
            table.insert(events, {'open'})
        end
        local old_registry = {
            MODULES={
                {name='internal/soulsearch/lifecycle'},
                {name='internal/soulsearch/ui'},
            },
            get_script_names=function()
                return {
                    'internal/soulsearch/module_registry',
                    'internal/soulsearch/ui',
                    'internal/soulsearch/creatures_menu_navigator',
                    'internal/soulsearch/lifecycle',
                    'internal/soulsearch/removed_module',
                }
            end,
            load_all=function() error('stale registry must not reconstruct modules') end,
        }
        local fresh_registry = {
            MODULES={
                {name='internal/soulsearch/new_module'},
                {name='internal/soulsearch/lifecycle'},
                {name='internal/soulsearch/ui'},
            },
            get_script_names=function() return {} end,
            load_all=function()
                return {
                    ['internal/soulsearch/keybindings']=keybindings,
                    ['internal/soulsearch/lifecycle']=lifecycle,
                    ['internal/soulsearch/ui']=new_ui,
                }
            end,
        }
        local environment = {
            bootstrap_enabled=false,
            dfhack_flags={},
            dfhack={
                run_command=function(command, ...)
                    table.insert(events, {command, ...})
                end,
                run_script=function(name)
                    table.insert(events, {'run_script', name})
                    if name == 'internal/soulsearch/module_registry' then
                        registry_runs = registry_runs + 1
                        registry_state = registry_runs == 1 and 'old' or 'fresh'
                    end
                end,
                findScript=function(name)
                    return '/scripts/' .. name .. '.lua'
                end,
                internal={scripts={
                    ['/scripts/internal/soulsearch/module_registry.lua']={stale=true},
                    ['/scripts/internal/soulsearch/ui.lua']={stale=true},
                    ['/scripts/internal/soulsearch/creatures_menu_navigator.lua']={stale=true},
                    ['/scripts/internal/soulsearch/lifecycle.lua']={stale=true},
                    ['/scripts/internal/soulsearch/new_module.lua']={stale=true},
                    ['/scripts/soulsearch-stats-overlay.lua']={stale=true},
                    ['/scripts/soulsearch-creatures-overlay.lua']={stale=true},
                }},
            },
            reqscript=function(name)
                if name == 'internal/soulsearch/module_registry' then
                    if registry_state == 'old' then return old_registry end
                    if registry_state == 'fresh' then return fresh_registry end
                    return {}
                end
                if name == 'internal/soulsearch/ui' then return old_ui end
                if name == 'internal/soulsearch/creatures_menu_navigator' then
                    return old_navigator
                end
                error('unexpected reqscript: ' .. tostring(name))
            end,
            require=function(name)
                assert(name == 'plugins.overlay')
                return {
                    rescan=function() table.insert(events, {'overlay_rescan'}) end,
                }
            end,
        }
        local chunk = load_script(command_path, environment)
        chunk('reload')

        assert.are.same({
            'devel/clear-script-env',
            'internal/soulsearch/module_registry',
        }, events[1])
        assert.are.same({
            'run_script',
            'internal/soulsearch/module_registry',
        }, events[2])
        assert.are.same({'dismiss_all'}, events[3])
        assert.are.same({'cancel_navigation'}, events[4])
        assert.are.same({
            'devel/clear-script-env',
            'internal/soulsearch/ui',
            'internal/soulsearch/creatures_menu_navigator',
            'internal/soulsearch/lifecycle',
        }, events[5])
        assert.are.same({
            'devel/clear-script-env',
            'internal/soulsearch/module_registry',
        }, events[6])
        assert.are.same({
            'run_script',
            'internal/soulsearch/module_registry',
        }, events[7])
        assert.are.same({
            'devel/clear-script-env',
            'internal/soulsearch/new_module',
            'internal/soulsearch/lifecycle',
            'internal/soulsearch/ui',
        }, events[8])
        assert.are.same({'run_script', 'internal/soulsearch/new_module'}, events[9])
        assert.are.same({'run_script', 'internal/soulsearch/lifecycle'}, events[10])
        assert.are.same({'run_script', 'internal/soulsearch/ui'}, events[11])
        assert.are.same({'overlay_rescan'}, events[12])
        assert.is_nil(environment.dfhack.internal.scripts[
            '/scripts/soulsearch-stats-overlay.lua'])
        assert.is_nil(environment.dfhack.internal.scripts[
            '/scripts/soulsearch-creatures-overlay.lua'])
        assert.are.same({'keybindings'}, events[13])
        assert.are.same({'prepare'}, events[14])
        assert.are.equal(1, old_ui.dismiss_count)
        assert.are.equal(1, old_navigator.cancel_count)
        assert.is_truthy(lifecycle.prepared)
        assert.is_truthy(keybindings.ensured)
        assert.are.equal(0, new_ui.open_count)
        assert.is_falsy(environment.isEnabled())
    end)

end)