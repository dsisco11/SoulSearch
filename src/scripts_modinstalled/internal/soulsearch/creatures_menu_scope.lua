--@ module=true

---Scope presets supplied by the vanilla Creatures menu integration. The
---returned options use the ordinary multi-window API, so a future integration
---can add profession, location, or explicit-unit scopes without changing the
---overlay's opening behaviour.

local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

local DIRECTION = filter_constants.direction
local SCOPE = filter_constants.unit_scope
local RACE = filter_constants.race

local CREATURES_FOCUS_PREFIX = 'dwarfmode/info/creatures'

local function race_group_id(group)
    return RACE.group_id_prefix .. group
end

local TAB_SCOPES = {
    {
        -- DFHack exposes the vanilla Citizens tab as .../CITIZEN.
        focus_tokens={'resident', 'citizen'},
        tab_labels={'residents', 'citizens'},
        settings_id='creatures:residents', label='Residents',
        unit_scope=SCOPE.FORT_RESIDENTS,
        race_group=RACE.group.HUMANOIDS,
    },
    {
        focus_tokens={'pet', 'livestock', 'work_animal'},
        tab_labels={'pets/livestock'},
        settings_id='creatures:pets-livestock', label='Pets/Livestock',
        unit_scope=SCOPE.CITIZENS_AND_PETS,
        race_group=RACE.group.TAMEABLE_ANIMALS,
    },
    {
        focus_tokens={'visitor', 'other'},
        tab_labels={'visitors', 'other'},
        settings_id='creatures:visitors', label='Visitors',
        unit_scope=SCOPE.VISITORS,
    },
}

local function tab_matches_label(label, tab)
    label = type(label) == 'string' and label:lower() or ''
    for _, expected in ipairs(tab.tab_labels or {}) do
        if label == expected then return true end
    end
    return false
end

local function focus_matches_tab(focus, tab)
    focus = type(focus) == 'string' and focus:lower() or ''
    if focus:sub(1, #CREATURES_FOCUS_PREFIX) ~= CREATURES_FOCUS_PREFIX then
        return false
    end
    for _, token in ipairs(tab.focus_tokens) do
        if focus:find('/' .. token, #CREATURES_FOCUS_PREFIX + 1, true) then
            return true
        end
    end
    return false
end

---@param tab table
---@return table
local function make_options(tab)
    local options = {
        settings_id=tab.settings_id,
        unit_scope=tab.unit_scope,
    }
    if tab.race_group then
        options.filters={{
            id=race_group_id(tab.race_group),
            direction=DIRECTION.HIGH,
        }}
    end
    return options
end

---@param focuses string[]|nil
---@return {label: string, options: table}|nil
function get_from_focuses(focuses)
    for _, focus in ipairs(focuses or {}) do
        for _, tab in ipairs(TAB_SCOPES) do
            if focus_matches_tab(focus, tab) then
                return {label=tab.label, options=make_options(tab)}
            end
        end
    end
    return nil
end

---@param label string|nil
---@return {label: string, options: table}|nil
function get_from_tab_label(label)
    for _, tab in ipairs(TAB_SCOPES) do
        if tab_matches_label(label, tab) then
            return {label=tab.label, options=make_options(tab)}
        end
    end
end

local function get_active_tab_label()
    local game = df.global and df.global.game
    local main_interface = game and game.main_interface
    local info = main_interface and main_interface.info
    local creatures = info and info.creatures
    if not creatures or not dfhack.gui.getWidget then return nil end
    local tabs = dfhack.gui.getWidget(creatures, 'Tabs')
    if not tabs or type(tabs.cur_idx) ~= 'number' or not tabs.tab_labels then
        return nil
    end
    return tabs.tab_labels[tabs.cur_idx]
end

---Returns the current Creatures-menu preset, including when a DFHack screen
---is temporarily above the vanilla menu.
---@return {label: string, options: table}|nil
function get_active()
    local screen = dfhack.gui.getCurViewscreen(true)
    while screen do
        local focuses = dfhack.gui.getFocusStrings(screen) or {}
        local scope = get_from_focuses(focuses)
        if scope then return scope end
        for _, focus in ipairs(focuses) do
            focus = type(focus) == 'string' and focus:lower() or ''
            if focus:sub(1, #CREATURES_FOCUS_PREFIX) == CREATURES_FOCUS_PREFIX then
                return get_from_tab_label(get_active_tab_label())
            end
        end
        screen = screen.parent
    end
    return nil
end
