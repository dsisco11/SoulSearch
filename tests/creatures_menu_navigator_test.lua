local module_loader = require('support.module_loader')

local function zero_based(values)
    local vector = {}
    for index, value in ipairs(values) do vector[index - 1] = value end
    return setmetatable(vector, {__len=function() return #values end})
end

local function unit_list(unit_ids, visible)
    local rows = {}
    for _, unit_id in ipairs(unit_ids) do
        table.insert(rows, {children={{u={id=unit_id}}}})
    end
    return {children=rows, num_visible=visible or 3, scroll=0}
end

local function selectable_page(unit_ids, visible)
    local list = unit_list(unit_ids, visible)
    local owner = {children={{children={list}}}, cursor_idx=0}
    return owner, list
end

local function strict_widget(children)
    return setmetatable({children=children or {}}, {
        __index=function(_, field)
            if field == 'u' or field == 'un' then
                error('invalid native widget field: ' .. field)
            end
        end,
    })
end

local function load_navigator(repo_root)
    local printed = {}
    local logs = {}
    local native_inputs = {}
    local schedule_requests = {}
    local cancel_requests = {}
    local units = setmetatable({}, {__index=function(self, id)
        local unit = {id=id, native_mode=0}
        rawset(self, id, unit)
        return unit
    end})
    local labels = zero_based({'Citizens', 'Pets/Livestock', 'Other'})
    local tabs = {tab_labels=labels, cur_idx=0}
    local pages = {}
    for index = 0, #labels - 1 do pages[labels[index]] = {children={}} end
    local creatures = {current_mode=0, search_string='old search'}
    local info = {open=false, current_mode=-1, creatures=creatures}
    local main_interface = {info=info, view_sheets={open=true}}
    local native_screen = {}
    local function is_widget_container(widget)
        return type(widget) == 'table' and rawget(widget, 'children') ~= nil
    end
    local state = {
        printed=printed, tabs=tabs, pages=pages, creatures=creatures,
        info=info, main_interface=main_interface, menu_built=false,
        native_inputs=native_inputs, native_screen=native_screen, units=units,
        logs=logs, repeater=nil, schedule_requests=schedule_requests,
        cancel_requests=cancel_requests,
    }
    function state.run_timer()
        local repeater = assert(state.repeater, 'no scheduled repeater')
        repeater.callback()
        return repeater
    end
    local globals = {
        print=function(message) table.insert(printed, message) end,
        require=function(name)
            if name == 'repeat-util' then
                return {
                    scheduleEvery=function(key, delay, mode, callback)
                        local request = {
                            key=key, delay=delay, mode=mode,
                            callback=callback,
                        }
                        state.repeater = request
                        table.insert(schedule_requests, request)
                    end,
                    cancel=function(key)
                        table.insert(cancel_requests, key)
                        if state.repeater and state.repeater.key == key then
                            state.repeater = nil
                        end
                    end,
                }
            end
            assert(name == 'gui', 'unexpected require: ' .. tostring(name))
            return {
                simulateInput=function(screen, key)
                    table.insert(native_inputs, {screen=screen, key=key})
                    -- Model the state change performed by the native input
                    -- handler. Widget construction still happens later.
                    info.open = true
                    info.current_mode = 17
                end,
            }
        end,
        df={
            info_interface_mode_type={CREATURES=17},
            unit_list_mode_type={CITIZEN=0, PET=1, OTHER=2, DECEASED=3},
            interface_key={D_UNITLIST=41},
            widget_container={
                is_instance=function(_, widget)
                    return is_widget_container(widget)
                end,
            },
            unit={find=function(id) return units[id] end},
            global={game={main_interface=main_interface}},
        },
        dfhack={
            println=function(message) table.insert(logs, message) end,
            units={
                isDead=function(unit) return unit.native_mode == 3 end,
                isActive=function(unit) return unit.native_mode ~= 3 end,
                isCitizen=function(unit) return unit.native_mode == 0 end,
                isResident=function() return false end,
                isPet=function(unit) return unit.native_mode == 1 end,
                isAnimal=function(unit) return unit.native_mode == 1 end,
                isFortControlled=function(unit) return unit.native_mode == 1 end,
            },
            gui={
                getDFViewscreen=function() return native_screen end,
                getWidgetChildren=function(widget)
                    assert(is_widget_container(widget),
                        'bad argument #1 to getWidgetChildren ' ..
                        '(invalid pointer type; expected: widget_container)')
                    return widget.children
                end,
                getWidget=function(widget, name)
                    if widget == creatures and name == 'Tabs' and state.menu_built then
                        return tabs
                    end
                    if widget == tabs then return pages[name] end
                end,
            },
        },
    }
    local navigator = module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/creatures_menu_navigator.lua',
        globals)
    return navigator, state
end

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('Creatures navigator: coroutine awaits each native UI stage', function()
        local navigator, state = load_navigator(repo_root)
        state.units[40].native_mode = 1
        local target_page, target_list = selectable_page({10, 20, 30, 40, 50}, 3)

        luaunit.assertEvalToTrue(navigator.show_unit(40))
        luaunit.assertEvalToTrue(navigator.is_running())
        luaunit.assertEvalToTrue(state.info.open)
        luaunit.assertIs(17, state.info.current_mode)
        luaunit.assertEvalToFalse(state.main_interface.view_sheets.open)
        luaunit.assertIs('', state.creatures.search_string)
        luaunit.assertIs(1, #state.native_inputs)
        luaunit.assertIs(state.native_screen, state.native_inputs[1].screen)
        luaunit.assertIs(41, state.native_inputs[1].key)
        luaunit.assertIs(0, target_list.scroll)

        -- The menu predicate does not advance while the native Tabs widget is
        -- absent, and each successful update crosses only one await boundary.
        luaunit.assertEvalToTrue(state.repeater ~= nil)
        luaunit.assertIs(2, state.repeater.delay)
        luaunit.assertIs('frames', state.repeater.mode)
        state.run_timer()
        luaunit.assertEvalToTrue(navigator.is_running())
        state.menu_built = true
        state.run_timer()
        luaunit.assertEvalToTrue(navigator.is_running())
        luaunit.assertIs(1, state.tabs.cur_idx)
        luaunit.assertIs(1, state.creatures.current_mode)
        -- The inactive Pets/Livestock page is populated only after the native
        -- mode has switched to it.
        state.pages['Pets/Livestock'] = target_page
        luaunit.assertIs(0, target_list.scroll)
        state.run_timer()
        luaunit.assertIs(3, target_page.cursor_idx)
        luaunit.assertIs(2, target_list.scroll)
        luaunit.assertEvalToFalse(navigator.is_running())
        luaunit.assertNil(state.repeater)
        luaunit.assertIs(1, #state.schedule_requests)
        luaunit.assertIs(2, state.schedule_requests[1].delay)
        luaunit.assertIs('frames', state.schedule_requests[1].mode)
        luaunit.assertIs(0, #state.printed)
        local trace = table.concat(state.logs, '\n')
        luaunit.assertEvalToTrue(trace:find('starting navigation for unit 40 using subtab 1', 1, true))
        luaunit.assertEvalToTrue(trace:find('selected subtab 1', 1, true))
        luaunit.assertEvalToTrue(trace:find('found unit 40', 1, true))
        luaunit.assertEvalToTrue(trace:find('cursor_idx=3 scroll=2', 1, true))
        luaunit.assertEvalToTrue(trace:find('navigation complete for unit 40', 1, true))
        local retained = navigator.get_log_messages()
        luaunit.assertEquals(state.logs, retained)
        retained[1] = 'mutated'
        luaunit.assertEvalToFalse(navigator.get_log_messages()[1] == 'mutated')
        navigator.clear_log_messages()
        luaunit.assertIs(0, #navigator.get_log_messages())
    end)

    add_test('Creatures navigator: already-open native panel is not toggled closed', function()
        local navigator, state = load_navigator(repo_root)
        state.info.open = true
        state.info.current_mode = 17
        state.menu_built = true
        local page = selectable_page({10}, 3)
        state.pages['Citizens'] = page

        luaunit.assertEvalToTrue(navigator.show_unit(10))
        luaunit.assertIs(0, #state.native_inputs)
        state.run_timer()
        luaunit.assertEvalToTrue(navigator.is_running())
        state.run_timer()
        luaunit.assertEvalToFalse(navigator.is_running())
        luaunit.assertIs(0, #state.printed)
    end)

    add_test('Creatures navigator: visitors select and populate the Other tab', function()
        local navigator, state = load_navigator(repo_root)
        state.units[70].native_mode = 2

        luaunit.assertEvalToTrue(navigator.show_unit(70))
        state.menu_built = true
        state.run_timer()
        luaunit.assertEvalToTrue(navigator.is_running())
        luaunit.assertIs(2, state.tabs.cur_idx)
        luaunit.assertIs(2, state.creatures.current_mode)

        local target_page, target_list = selectable_page({60, 70, 80}, 1)
        state.pages['Other'] = target_page
        state.run_timer()
        luaunit.assertIs(1, target_page.cursor_idx)
        luaunit.assertIs(1, target_list.scroll)
        luaunit.assertIs(0, #state.printed)
    end)

    add_test('Creatures navigator: native widgets may reject absent unit fields', function()
        local navigator, state = load_navigator(repo_root)
        local target_list = {
            children={
                strict_widget({{u={id=10}}}),
                strict_widget({{u={id=20}}}),
            },
            num_visible=1,
            scroll=0,
        }
        local selection_owner = {cursor_idx=0, children={
            strict_widget({strict_widget({target_list})}),
        }}
        state.pages['Citizens'] = selection_owner

        luaunit.assertEvalToTrue(navigator.show_unit(20))
        state.menu_built = true
        state.run_timer()
        luaunit.assertEvalToTrue(navigator.is_running())
        state.run_timer()
        luaunit.assertIs(1, selection_owner.cursor_idx)
        luaunit.assertIs(1, target_list.scroll)
        luaunit.assertIs(0, #state.printed)
    end)

    add_test('Creatures navigator: a new request cancels the suspended flow', function()
        local navigator, state = load_navigator(repo_root)
        luaunit.assertEvalToTrue(navigator.show_unit(10))
        local old_callback = state.repeater.callback
        luaunit.assertEvalToTrue(navigator.show_unit(20))
        luaunit.assertIs(2, #state.schedule_requests)
        local current_repeater = state.repeater
        -- Even if an obsolete callback was already dispatched, it cannot
        -- advance or cancel the replacement flow.
        old_callback()
        luaunit.assertEvalToTrue(navigator.is_running())
        luaunit.assertEvalToTrue(current_repeater == state.repeater)
        state.menu_built = true
        local page = selectable_page({20}, 3)
        state.pages['Citizens'] = page
        state.run_timer()
        luaunit.assertEvalToTrue(navigator.is_running())
        state.run_timer()
        luaunit.assertEvalToFalse(navigator.is_running())
        luaunit.assertEvalToFalse(navigator.cancel())
        luaunit.assertIs(0, #state.printed)
    end)

    add_test('Creatures navigator: stalled awaits have a fixed update budget', function()
        local navigator, state = load_navigator(repo_root)
        luaunit.assertEvalToFalse(navigator.show_unit(nil))
        luaunit.assertIs('SoulSearch: no unit selected.', state.printed[1])
        luaunit.assertEvalToTrue(navigator.show_unit(99))
        for _ = 1, 120 do
            state.run_timer()
            luaunit.assertEvalToTrue(navigator.is_running())
        end
        state.run_timer()
        luaunit.assertEvalToFalse(navigator.is_running())
        luaunit.assertNil(state.repeater)
        luaunit.assertIs(
            'SoulSearch: unit 99 did not become available in the Creatures panel.',
            state.printed[2])
    end)

return native_tests
