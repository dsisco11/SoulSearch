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

return function(test, repo_root)
    test.case('creatures menu overlay: registers a visible native button on supported tabs', function()
        local scope = {get_active=function() return nil end}
        local overlay = load_overlay(repo_root, scope, {initialize=function() return {} end})
        local attrs = overlay.SoulSearchCreaturesOverlay.attrs
        test.assert_true(overlay.OVERLAY_WIDGETS.soulsearch_creatures ~= nil)
        test.assert_equal('dwarfmode/Info/CREATURES', attrs.viewscreens)
        test.assert_true(attrs.default_enabled)
        test.assert_true(attrs.hotspot)
        test.assert_equal(0, attrs.overlay_onupdate_max_freq_seconds)
        test.assert_equal(9, attrs.version)
        test.assert_equal(-2, attrs.default_pos.x)
        test.assert_equal(2, attrs.default_pos.y)
        test.assert_false(attrs.active())

        local widget = overlay.SoulSearchCreaturesOverlay{}
        local button = widget.subviews.open_scoped_search
        test.assert_equal('Open SoulSearch', button.label)
        test.assert_equal('Open SoulSearch scoped to the active Creatures tab.', button.tooltip)
    end)

    test.case('creatures menu overlay: docks below the Residents subtab', function()
        local scope = {get_active=function() return nil end}
        local overlay = load_overlay(repo_root, scope, {initialize=function() return {} end})
        local widget = overlay.SoulSearchCreaturesOverlay{}
        widget:preUpdateLayout({width=80, height=25})
        test.assert_equal(7, widget.frame.l)
        test.assert_equal(9, widget.frame.t)
        test.assert_equal(17, widget.frame.w)
        test.assert_equal(1, widget.frame.h)
    end)

    test.case('creatures menu overlay: opens the current explicit scope through initialized UI', function()
        local options = {settings_id='creatures:residents', filters={}}
        local scope = {get_active=function() return {label='Residents', options=options} end}
        local initialized, opened = 0, 0
        local command = {initialize=function()
            initialized = initialized + 1
            return {['internal/soulsearch/ui']={open=function(given)
                opened = opened + 1
                test.assert_true(given == options)
                return {}
            end}}
        end}
        local overlay = load_overlay(repo_root, scope, command)
        local widget = overlay.SoulSearchCreaturesOverlay{}
        test.assert_true(overlay.SoulSearchCreaturesOverlay.attrs.active())
        test.assert_true(widget:open_scoped_search())
        test.assert_equal(1, initialized)
        test.assert_equal(1, opened)
    end)

    test.case('creatures menu overlay: does not initialize SoulSearch without a supported tab', function()
        local scope = {get_active=function() return nil end}
        local initialized = 0
        local overlay = load_overlay(repo_root, scope, {initialize=function()
            initialized = initialized + 1
            return {}
        end})
        test.assert_false(overlay.SoulSearchCreaturesOverlay{}:open_scoped_search())
        test.assert_equal(0, initialized)
    end)
end
