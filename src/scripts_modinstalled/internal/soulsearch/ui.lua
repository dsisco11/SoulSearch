--@ module=true

local residents = reqscript('internal/soulsearch/residents')
local window_settings = reqscript('internal/soulsearch/window_settings')
local window_config = reqscript('internal/soulsearch/window_config')
local screen_registry = reqscript('internal/soulsearch/screen_registry')
local SoulSearchScreen =
    reqscript('internal/soulsearch/ui/main_screen').SoulSearchScreen

---Dismisses every screen owned by this loaded UI generation.
function dismiss_all()
    screen_registry.for_each_snapshot(function(screen)
        screen:dismiss()
        screen_registry.remove(screen)
    end)
end

---Opens a new SoulSearch screen.
---@param options table|nil
---@return SoulSearchScreen|nil
function open(options)
    local err = residents.get_unavailable_reason()
    if err then
        print(err)
        return nil
    end
    options = type(options) == 'table' and options or nil
    local screen_width, screen_height = dfhack.screen.getWindowSize()
    local settings = window_config.resolve(options, screen_width, screen_height)
    if next(settings.explicit) then
        window_settings.update(settings.settings_id, settings.explicit)
    end
    if not settings.explicit.frame then
        settings.frame = screen_registry.place_frame(
            settings.frame, screen_width, screen_height)
    end
    return SoulSearchScreen{
        settings_id=settings.settings_id,
        settings=settings,
    }:show()
end
