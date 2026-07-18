local module_loader = require('support.module_loader')

local function make_class(parent)
    local class = {super=parent, attrs={}}
    function class.ATTRS(attributes)
        for key, value in pairs(attributes) do class.attrs[key] = value end
    end
    return setmetatable(class, {
        __index=parent,
        __call=function(cls, info)
            local instance = info or {}
            setmetatable(instance, {__index=cls})
            if cls.init then cls.init(instance, info or {}) end
            return instance
        end,
    })
end

local function load_overlay(repo_root, scope, command)
    local base = {}
    function base:addviews(views)
        self.subviews = {}
        for _, view in ipairs(views) do self.subviews[view.view_id] = view end
    end
    function base:updateLayout()
        self.layout_updates = (self.layout_updates or 0) + 1
    end
    local width, height = 80, 25
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/soulsearch-creatures-overlay.lua', {
            defclass=function(_, parent) return make_class(parent) end,
            require=function(name)
                if name == 'plugins.overlay' then return {OverlayWidget=base} end
                if name == 'gui.widgets' then
                    return {TextButton=setmetatable({}, {
                        __call=function(_, info) return info end,
                    })}
                end
                error('unexpected require: ' .. name)
            end,
            reqscript=function(name)
                if name == 'internal/soulsearch/creatures_menu_scope' then return scope end
                if name == 'soulsearch' then return command end
                error('unexpected reqscript: ' .. name)
            end,
            dfhack={screen={
                getWindowSize=function() return width, height end,
            }},
            df={global={game={main_interface={info={creatures={
                rect={x1=5, y1=6, x2=71, y2=22},
            }}}}}},
        })
end

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('creatures menu overlay: registers a visible native button on supported tabs', function()
        local scope = {get_active=function() return nil end}
        local overlay = load_overlay(repo_root, scope, {initialize=function() return {} end})
        local attrs = overlay.SoulSearchCreaturesOverlay.attrs
        luaunit.assertEvalToTrue(overlay.OVERLAY_WIDGETS.soulsearch_creatures ~= nil)
        luaunit.assertNil(
            overlay.OVERLAY_WIDGETS.soulsearch_creatures_navigator)
        luaunit.assertIs('dwarfmode/Info/CREATURES', attrs.viewscreens)
        luaunit.assertEvalToTrue(attrs.default_enabled)
        luaunit.assertEvalToTrue(attrs.hotspot)
        luaunit.assertIs(0, attrs.overlay_onupdate_max_freq_seconds)
        luaunit.assertIs(9, attrs.version)
        luaunit.assertIs(-2, attrs.default_pos.x)
        luaunit.assertIs(2, attrs.default_pos.y)
        luaunit.assertEvalToFalse(attrs.active())

        local widget = overlay.SoulSearchCreaturesOverlay{}
        local button = widget.subviews.open_scoped_search
        luaunit.assertIs('Open SoulSearch', button.label)
        luaunit.assertIs('Open SoulSearch scoped to the active Creatures tab.', button.tooltip)
    end)

    add_test('creatures menu overlay: docks below the Residents subtab', function()
        local scope = {get_active=function() return nil end}
        local overlay = load_overlay(repo_root, scope, {initialize=function() return {} end})
        local widget = overlay.SoulSearchCreaturesOverlay{}
        widget:preUpdateLayout({width=80, height=25})
        luaunit.assertIs(7, widget.frame.l)
        luaunit.assertIs(9, widget.frame.t)
        luaunit.assertIs(17, widget.frame.w)
        luaunit.assertIs(1, widget.frame.h)
    end)

    add_test('creatures menu overlay: opens every current unified filter preset', function()
        local cases = {
            {label='Residents', filters={'unit_scope:fort_residents', 'unit_scope:citizens',
                'race:group:HUMANOIDS'}},
            {label='Pets/Livestock', filters={'unit_scope:pets', 'unit_scope:livestock',
                'race:group:TAMEABLE_ANIMALS'}},
            {label='Visitors', filters={'unit_scope:visitors'}},
        }
        for _, case in ipairs(cases) do
            local options = {settings_id='creatures:' .. case.label, filters={}}
            for _, id in ipairs(case.filters) do
                table.insert(options.filters, {id=id, direction='high'})
            end
            local scope = {get_active=function() return {label=case.label, options=options} end}
            local initialized, opened = 0, 0
            local command = {initialize=function()
                initialized = initialized + 1
                return {['internal/soulsearch/ui']={open=function(given)
                    opened = opened + 1
                    luaunit.assertEvalToTrue(given == options)
                    return {}
                end}}
            end}
            local overlay = load_overlay(repo_root, scope, command)
            local widget = overlay.SoulSearchCreaturesOverlay{}
            luaunit.assertEvalToTrue(overlay.SoulSearchCreaturesOverlay.attrs.active())
            luaunit.assertEvalToTrue(widget:open_scoped_search())
            luaunit.assertIs(1, initialized)
            luaunit.assertIs(1, opened)
        end
    end)

    add_test('creatures menu overlay: does not initialize SoulSearch without a supported tab', function()
        local scope = {get_active=function() return nil end}
        local initialized = 0
        local overlay = load_overlay(repo_root, scope, {initialize=function()
            initialized = initialized + 1
            return {}
        end})
        luaunit.assertEvalToFalse(overlay.SoulSearchCreaturesOverlay{}:open_scoped_search())
        luaunit.assertIs(0, initialized)
    end)

return native_tests
