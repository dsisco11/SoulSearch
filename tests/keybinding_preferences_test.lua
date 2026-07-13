local module_loader = require('support.module_loader')

local function load_preferences(repo_root, dependencies)
    local module = module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/keybinding_preferences.lua')
    return module.new(dependencies)
end

return function(test, repo_root)
    test.case('keybinding preferences: reads absent, valid, corrupt, and future marker states', function()
        local files = {}
        local json = {
            open=function(path, strict)
                local config = files[path]
                if strict and not config then error('missing') end
                config = config or {}
                function config:write() files[path] = self end
                return config
            end,
        }
        local dependencies = {
            json=json,
            scriptmanager={getModStatePath=function() return 'state/' end},
            filesystem={exists=function(path) return files[path] ~= nil end},
        }
        local preferences = load_preferences(repo_root, dependencies)
        test.assert_equal('unset', preferences.read())

        files['state/default-keybinding.json'] = {
            data={version=1, default_considered=true},
        }
        test.assert_equal('considered', preferences.read())
        files['state/default-keybinding.json'].data.version = 2
        test.assert_equal('corrupt', preferences.read())
        files['state/default-keybinding.json'].data = {version=1}
        test.assert_equal('corrupt', preferences.read())
    end)

    test.case('keybinding preferences: writes the versioned marker and reports write failures', function()
        local written = {}
        local writable = load_preferences(repo_root, {
            json={open=function(path)
                return {write=function(self) written[path] = self.data end}
            end},
            scriptmanager={getModStatePath=function() return 'state/' end},
            filesystem={exists=function() return false end},
        })
        test.assert_true(writable.mark_considered())
        test.assert_equal(1, written['state/default-keybinding.json'].version)
        test.assert_true(written['state/default-keybinding.json'].default_considered)

        local failing = load_preferences(repo_root, {
            json={open=function() return {write=function() error('write failed') end} end},
            scriptmanager={getModStatePath=function() return 'state/' end},
            filesystem={exists=function() return false end},
        })
        test.assert_false(failing.mark_considered())
    end)

    test.case('keybinding preferences: missing APIs and read failures are explicit', function()
        test.assert_equal('unavailable', load_preferences(repo_root, {}).read())
        local unreadable = load_preferences(repo_root, {
            json={open=function() error('decode failed') end},
            scriptmanager={getModStatePath=function() return 'state/' end},
            filesystem={exists=function() return true end},
        })
        test.assert_equal('corrupt', unreadable.read())
    end)
end
