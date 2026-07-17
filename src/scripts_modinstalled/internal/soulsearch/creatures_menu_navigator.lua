--@ module=true

local gui = require('gui')
local repeat_util = require('repeat-util')

local INFO_MODE = df.info_interface_mode_type
local UNIT_LIST_MODE = df.unit_list_mode_type
local WIDGET_CONTAINER = df.widget_container
local OPEN_CREATURES_KEY = df.interface_key.D_UNITLIST
local POLL_INTERVAL_FRAMES = 2
local MAX_FLOW_POLLS = 120
local POLL_KEY = 'soulsearch-creatures-navigation'
local MAX_SCAN_DEPTH = 12
local MAX_SCAN_NODES = 2000
local MAX_LOG_MESSAGES = 500
local LOG_PREFIX = 'SoulSearch Creatures Navigator: '

local active_flow
local logging_enabled = true
local log_messages = {}

local function log(format_string, ...)
    if not logging_enabled then return end
    local ok, message = pcall(string.format, format_string, ...)
    message = ok and message or ('could not format log message: ' .. tostring(message))
    message = LOG_PREFIX .. message
    if #log_messages >= MAX_LOG_MESSAGES then table.remove(log_messages, 1) end
    table.insert(log_messages, message)
    if dfhack.println then
        dfhack.println(message)
    else
        print(message)
    end
end

local function mode_name(mode)
    local ok, name = pcall(function() return UNIT_LIST_MODE[mode] end)
    return ok and type(name) == 'string' and name or tostring(mode)
end

local function trace_wait(stage, detail)
    local flow = active_flow
    if not flow then return end
    local signature = stage .. ':' .. tostring(detail)
    if flow.last_wait_signature == signature then return end
    flow.last_wait_signature = signature
    log('waiting for %s (%s)', stage, tostring(detail))
end

local function get_children(widget)
    if not widget or not dfhack.gui.getWidgetChildren then return {} end
    -- getWidgetChildren() accepts only native widget_container instances.
    -- A container's children can include leaf widgets, so recursive scans must
    -- stop at those leaves instead of passing every widget back to DFHack.
    if not WIDGET_CONTAINER or not WIDGET_CONTAINER:is_instance(widget) then
        return {}
    end
    return dfhack.gui.getWidgetChildren(widget) or {}
end

local function read_field(widget, field)
    if not widget then return false, nil end
    return pcall(function() return widget[field] end)
end

local function read_unit_field(widget, field)
    if not widget then return nil end
    local ok, unit = pcall(function() return widget[field] end)
    if not ok or not unit then return nil end
    local id_ok, id = pcall(function() return unit.id end)
    if id_ok and type(id) == 'number' then return unit end
end

local function get_unit(widget)
    -- DF widgets are native userdata. Accessing a field that the concrete
    -- widget type does not own raises instead of returning nil, so probe the
    -- known unit fields defensively. Most rendered rows use `u`; `un` is used
    -- by the underlying creature-row records.
    local unit = read_unit_field(widget, 'u') or read_unit_field(widget, 'un')
    if unit then return unit end
    for _, child in ipairs(get_children(widget)) do
        unit = read_unit_field(child, 'u') or read_unit_field(child, 'un')
        if unit then return unit end
    end
end

local function find_unit_list(widget, unit_id, scan, depth, selection_owner)
    if not widget or depth > MAX_SCAN_DEPTH or scan.nodes >= MAX_SCAN_NODES then
        return nil
    end
    local key = tostring(widget)
    if scan.visited[key] then return nil end
    scan.visited[key] = true
    scan.nodes = scan.nodes + 1

    local cursor_ok, cursor_idx = read_field(widget, 'cursor_idx')
    if cursor_ok and type(cursor_idx) == 'number' then
        selection_owner = widget
    end

    local children = get_children(widget)
    for index, child in ipairs(children) do
        local unit = get_unit(child)
        if unit and unit.id == unit_id then
            return widget, selection_owner, index, #children
        end
    end
    for _, child in ipairs(children) do
        local list, owner, index, count =
            find_unit_list(child, unit_id, scan, depth + 1, selection_owner)
        if list then return list, owner, index, count end
    end
end

local function select_and_center_row(selection_owner, list, index, count)
    local cursor_idx = index - 1
    local cursor_ok, cursor_error = pcall(function()
        selection_owner.cursor_idx = cursor_idx
    end)
    if not cursor_ok then
        error('could not set native cursor_idx: ' .. tostring(cursor_error))
    end
    local _, num_visible = read_field(list, 'num_visible')
    local visible = math.max(tonumber(num_visible) or 1, 1)
    local maximum = math.max(count - visible, 0)
    local scroll = math.max(0, math.min(
        cursor_idx - math.floor(visible / 2), maximum))
    local scroll_ok, scroll_error = pcall(function() list.scroll = scroll end)
    if not scroll_ok then
        error('could not set native list scroll: ' .. tostring(scroll_error))
    end
    local _, actual_cursor = read_field(selection_owner, 'cursor_idx')
    local _, actual_scroll = read_field(list, 'scroll')
    log('selected row %d/%d: cursor_idx=%s scroll=%s visible=%d owner=%s list=%s',
        index, count, tostring(actual_cursor), tostring(actual_scroll), visible,
        tostring(selection_owner), tostring(list))
end

local function matches_unit(predicate, unit, ...)
    local fn = dfhack.units and dfhack.units[predicate]
    return fn and fn(unit, ...) or false
end

local function get_unit_list_mode(unit)
    if matches_unit('isDead', unit) or not matches_unit('isActive', unit) then
        return UNIT_LIST_MODE.DECEASED
    end
    if matches_unit('isCitizen', unit, true) or
            matches_unit('isResident', unit, true) then
        return UNIT_LIST_MODE.CITIZEN
    end
    if matches_unit('isPet', unit) or
            (matches_unit('isAnimal', unit) and
             matches_unit('isFortControlled', unit)) then
        return UNIT_LIST_MODE.PET
    end
    return UNIT_LIST_MODE.OTHER
end

local function get_creatures()
    local game = df.global and df.global.game
    local main_interface = game and game.main_interface
    local info = main_interface and main_interface.info
    return info and info.creatures, info, main_interface
end

local function detect_creatures_menu_ready()
    local creatures, info = get_creatures()
    if not creatures or not info then return false, 'interface unavailable' end
    if not info.open then return false, 'Info panel is closed' end
    if info.current_mode ~= INFO_MODE.CREATURES then
        return false, ('Info mode is %s'):format(tostring(info.current_mode))
    end
    local tabs = dfhack.gui.getWidget and
        dfhack.gui.getWidget(creatures, 'Tabs') or nil
    local labels = tabs and tabs.tab_labels
    if not tabs then return false, 'native Tabs widget is absent' end
    if not labels or #labels == 0 then return false, 'native tab labels are empty' end
    if type(tabs.cur_idx) ~= 'number' then
        return false, 'native tab index is unavailable'
    end
    return true, creatures, tabs
end

local function detect_unit_list(tabs, unit_id, tab_mode)
    local labels = tabs and tabs.tab_labels
    local label = labels and labels[tab_mode]
    if not label then
        return false, ('tab %s has no label'):format(mode_name(tab_mode))
    end
    local page = dfhack.gui.getWidget(tabs, label)
    if not page then
        return false, ('%s page widget is absent'):format(tostring(label))
    end
    local scan = {nodes=0, visited={}}
    local list, selection_owner, row_index, row_count =
        find_unit_list(page, unit_id, scan, 0)
    if list and selection_owner then
        return true, list, selection_owner, row_index, row_count
    end
    if list then
        return false, ('%s target row found after %d nodes, but no cursor owner exists')
            :format(tostring(label), scan.nodes)
    end
    return false, ('%s target row absent after scanning %d nodes')
        :format(tostring(label), scan.nodes)
end

local function select_tab(creatures, tabs, tab_mode)
    local _, previous_tab = read_field(tabs, 'cur_idx')
    local _, previous_mode = read_field(creatures, 'current_mode')
    tabs.cur_idx = tab_mode
    creatures.current_mode = tab_mode
    log('selected subtab %s: tabs.cur_idx %s -> %s, creatures.current_mode %s -> %s',
        mode_name(tab_mode), tostring(previous_tab), tostring(tabs.cur_idx),
        tostring(previous_mode), tostring(creatures.current_mode))
end

local function open_creatures_panel()
    local creatures, info, main_interface = get_creatures()
    if main_interface.view_sheets then
        main_interface.view_sheets.open = false
        log('closed the native unit sheet before opening Creatures')
    end
    creatures.search_string = ''
    log('cleared the native Creatures search string')

    -- Dispatch the native Creatures action so DF runs its private activation
    -- and population callbacks. The exposed Info fields describe UI state;
    -- assigning them directly only displays an uninitialized, blank page.
    if not info.open or info.current_mode ~= INFO_MODE.CREATURES then
        local screen = dfhack.gui.getDFViewscreen(true)
        if not screen then error('the native fortress viewscreen is unavailable') end
        log('sending native D_UNITLIST input to %s', tostring(screen))
        gui.simulateInput(screen, OPEN_CREATURES_KEY)
    else
        log('Creatures panel is already open; native toggle input skipped')
    end
end

local function await(condition)
    return coroutine.yield(condition)
end

local function navigate(unit_id, tab_mode)
    open_creatures_panel()
    local creatures, tabs = await(function()
        local ready, first, second = detect_creatures_menu_ready()
        if not ready then
            trace_wait('Creatures menu', first)
            return false
        end
        log('Creatures menu is ready: tabs=%s current=%s labels=%d',
            tostring(second), tostring(second.cur_idx), #second.tab_labels)
        return true, first, second
    end)
    select_tab(creatures, tabs, tab_mode)
    local list, selection_owner, row_index, row_count = await(function()
        local ready, current_creatures, current_tabs =
            detect_creatures_menu_ready()
        if not ready or current_creatures ~= creatures or current_tabs ~= tabs then
            trace_wait('stable Creatures menu', ready and 'native widgets changed' or current_creatures)
            return false
        end
        if tabs.cur_idx ~= tab_mode or creatures.current_mode ~= tab_mode then
            trace_wait('subtab transition', ('tabs=%s mode=%s expected=%s'):format(
                tostring(tabs.cur_idx), tostring(creatures.current_mode), mode_name(tab_mode)))
            return false
        end
        local found, first, second, third, fourth =
            detect_unit_list(tabs, unit_id, tab_mode)
        if not found then
            trace_wait('unit row', first)
            return false
        end
        log('found unit %d in %s at row %d/%d after native population',
            unit_id, mode_name(tab_mode), third, fourth)
        return true, first, second, third, fourth
    end)
    select_and_center_row(selection_owner, list, row_index, row_count)
    log('navigation complete for unit %d', unit_id)
end

local function clear_flow()
    repeat_util.cancel(POLL_KEY)
    active_flow = nil
end

local function fail_flow(message)
    log('navigation failed: %s', tostring(message))
    clear_flow()
    print('SoulSearch: ' .. message)
end

local function resume_flow(...)
    local flow = active_flow
    if not flow then return false end
    local resumed = table.pack(coroutine.resume(flow.coroutine, ...))
    if not resumed[1] then
        local failure = tostring(resumed[2])
        if debug and debug.traceback then
            failure = debug.traceback(flow.coroutine, failure)
        end
        fail_flow('could not navigate the Creatures panel: ' .. failure)
        return false
    end
    local status = coroutine.status(flow.coroutine)
    log('coroutine resume completed with status=%s yielded=%s',
        status, type(resumed[2]))
    if status == 'dead' then
        clear_flow()
        return true
    end
    if type(resumed[2]) ~= 'function' then
        fail_flow('the Creatures navigation flow yielded an invalid condition.')
        return false
    end
    flow.condition = resumed[2]
    return true
end

---@return boolean
function is_running()
    return active_flow ~= nil
end

---Advances at most one await boundary. Called by the scheduled frame poll so
---native UI logic receives time to settle between mutations.
---@return boolean running
function update()
    local flow = active_flow
    if not flow then return false end
    flow.polls = flow.polls + 1
    if flow.polls == 1 then
        log('controller began advancing unit %d', flow.unit_id)
    elseif flow.polls % 30 == 0 then
        log('still waiting after %d polls (%s)', flow.polls,
            tostring(flow.last_wait_signature or 'condition unchanged'))
    end
    if flow.polls > MAX_FLOW_POLLS then
        fail_flow(('unit %d did not become available in the Creatures panel.')
            :format(flow.unit_id))
        return false
    end

    local checked = table.pack(pcall(flow.condition))
    if not checked[1] then
        fail_flow('could not inspect the Creatures panel: ' .. tostring(checked[2]))
        return false
    end
    if not checked[2] then return true end
    resume_flow(table.unpack(checked, 3, checked.n))
    return is_running()
end

---@param flow table
---@return boolean scheduled
local function schedule_polling(flow)
    if active_flow ~= flow then return false end
    local ok, err = pcall(repeat_util.scheduleEvery,
        POLL_KEY, POLL_INTERVAL_FRAMES, 'frames', function()
        -- Flow identity makes an obsolete callback a no-op instead of letting
        -- it advance a newer request registered under the same scheduler key.
        if active_flow ~= flow then return end
        update()
    end)
    if not ok then
        fail_flow('could not schedule Creatures navigation polling: ' ..
            tostring(err))
        return false
    end
    return true
end

---@return boolean cancelled
function cancel()
    if not active_flow then return false end
    clear_flow()
    return true
end

---@param enabled boolean
function set_logging(enabled)
    logging_enabled = enabled ~= false
end

---Returns an isolated snapshot of the retained console diagnostics.
---@return string[]
function get_log_messages()
    local copy = {}
    for index, message in ipairs(log_messages) do copy[index] = message end
    return copy
end

---Clears retained diagnostics without changing live console logging.
function clear_log_messages()
    log_messages = {}
end

---Writes a diagnostic event to the DFHack console.
---@param format_string string
---@param ... any
function log_event(format_string, ...)
    log(format_string, ...)
end

---@param unit_id integer
---@return boolean started
function show_unit(unit_id)
    if type(unit_id) ~= 'number' then
        print('SoulSearch: no unit selected.')
        return false
    end
    local _, _, main_interface = get_creatures()
    if not main_interface then
        print('SoulSearch: the native Creatures panel is unavailable.')
        return false
    end
    local unit = df.unit.find(unit_id)
    if not unit then
        print(('SoulSearch: unit %d is no longer available.'):format(unit_id))
        return false
    end
    local tab_mode = get_unit_list_mode(unit)

    cancel()
    active_flow = {
        unit_id=unit_id,
        polls=0,
        last_wait_signature=nil,
        coroutine=coroutine.create(function() navigate(unit_id, tab_mode) end),
    }
    log('starting navigation for unit %d using subtab %s',
        unit_id, mode_name(tab_mode))
    if not resume_flow() then return false end
    if not active_flow then return true end
    log('polling awaits every %d frames with a %d-poll limit',
        POLL_INTERVAL_FRAMES, MAX_FLOW_POLLS)
    return schedule_polling(active_flow)
end
