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

local repo_root = require('support.repo_root')

describe('creatures menu navigator', function()

    it('Creatures navigator: coroutine awaits each native UI stage', function()
        local navigator, state = load_navigator(repo_root)
        state.units[40].native_mode = 1
        local target_page, target_list = selectable_page({10, 20, 30, 40, 50}, 3)

        assert.is_truthy(navigator.show_unit(40))
        assert.is_truthy(navigator.is_running())
        assert.is_truthy(state.info.open)
        assert.are.equal(17, state.info.current_mode)
        assert.is_falsy(state.main_interface.view_sheets.open)
        assert.are.equal('', state.creatures.search_string)
        assert.are.equal(1, #state.native_inputs)
        assert.are.equal(state.native_screen, state.native_inputs[1].screen)
        assert.are.equal(41, state.native_inputs[1].key)
        assert.are.equal(0, target_list.scroll)

        -- The menu predicate does not advance while the native Tabs widget is
        -- absent, and each successful update crosses only one await boundary.
        assert.is_truthy(state.repeater ~= nil)
        assert.are.equal(2, state.repeater.delay)
        assert.are.equal('frames', state.repeater.mode)
        state.run_timer()
        assert.is_truthy(navigator.is_running())
        state.menu_built = true
        state.run_timer()
        assert.is_truthy(navigator.is_running())
        assert.are.equal(1, state.tabs.cur_idx)
        assert.are.equal(1, state.creatures.current_mode)
        -- The inactive Pets/Livestock page is populated only after the native
        -- mode has switched to it.
        state.pages['Pets/Livestock'] = target_page
        assert.are.equal(0, target_list.scroll)
        state.run_timer()
        assert.are.equal(3, target_page.cursor_idx)
        assert.are.equal(2, target_list.scroll)
        assert.is_falsy(navigator.is_running())
        assert.is_nil(state.repeater)
        assert.are.equal(1, #state.schedule_requests)
        assert.are.equal(2, state.schedule_requests[1].delay)
        assert.are.equal('frames', state.schedule_requests[1].mode)
        assert.are.equal(0, #state.printed)
        local trace = table.concat(state.logs, '\n')
        assert.is_truthy(trace:find('starting navigation for unit 40 using subtab 1', 1, true))
        assert.is_truthy(trace:find('selected subtab 1', 1, true))
        assert.is_truthy(trace:find('found unit 40', 1, true))
        assert.is_truthy(trace:find('cursor_idx=3 scroll=2', 1, true))
        assert.is_truthy(trace:find('navigation complete for unit 40', 1, true))
        local retained = navigator.get_log_messages()
        assert.are.same(state.logs, retained)
        retained[1] = 'mutated'
        assert.is_falsy(navigator.get_log_messages()[1] == 'mutated')
        navigator.clear_log_messages()
        assert.are.equal(0, #navigator.get_log_messages())
    end)

    it('Creatures navigator: already-open native panel is not toggled closed', function()
        local navigator, state = load_navigator(repo_root)
        state.info.open = true
        state.info.current_mode = 17
        state.menu_built = true
        local page = selectable_page({10}, 3)
        state.pages['Citizens'] = page

        assert.is_truthy(navigator.show_unit(10))
        assert.are.equal(0, #state.native_inputs)
        state.run_timer()
        assert.is_truthy(navigator.is_running())
        state.run_timer()
        assert.is_falsy(navigator.is_running())
        assert.are.equal(0, #state.printed)
    end)

    it('Creatures navigator: visitors select and populate the Other tab', function()
        local navigator, state = load_navigator(repo_root)
        state.units[70].native_mode = 2

        assert.is_truthy(navigator.show_unit(70))
        state.menu_built = true
        state.run_timer()
        assert.is_truthy(navigator.is_running())
        assert.are.equal(2, state.tabs.cur_idx)
        assert.are.equal(2, state.creatures.current_mode)

        local target_page, target_list = selectable_page({60, 70, 80}, 1)
        state.pages['Other'] = target_page
        state.run_timer()
        assert.are.equal(1, target_page.cursor_idx)
        assert.are.equal(1, target_list.scroll)
        assert.are.equal(0, #state.printed)
    end)

    it('Creatures navigator: native widgets may reject absent unit fields', function()
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

        assert.is_truthy(navigator.show_unit(20))
        state.menu_built = true
        state.run_timer()
        assert.is_truthy(navigator.is_running())
        state.run_timer()
        assert.are.equal(1, selection_owner.cursor_idx)
        assert.are.equal(1, target_list.scroll)
        assert.are.equal(0, #state.printed)
    end)

    it('Creatures navigator: a new request cancels the suspended flow', function()
        local navigator, state = load_navigator(repo_root)
        assert.is_truthy(navigator.show_unit(10))
        local old_callback = state.repeater.callback
        assert.is_truthy(navigator.show_unit(20))
        assert.are.equal(2, #state.schedule_requests)
        local current_repeater = state.repeater
        -- Even if an obsolete callback was already dispatched, it cannot
        -- advance or cancel the replacement flow.
        old_callback()
        assert.is_truthy(navigator.is_running())
        assert.is_truthy(current_repeater == state.repeater)
        state.menu_built = true
        local page = selectable_page({20}, 3)
        state.pages['Citizens'] = page
        state.run_timer()
        assert.is_truthy(navigator.is_running())
        state.run_timer()
        assert.is_falsy(navigator.is_running())
        assert.is_falsy(navigator.cancel())
        assert.are.equal(0, #state.printed)
    end)

    it('Creatures navigator: stalled awaits have a fixed update budget', function()
        local navigator, state = load_navigator(repo_root)
        assert.is_falsy(navigator.show_unit(nil))
        assert.are.equal('SoulSearch: no unit selected.', state.printed[1])
        assert.is_truthy(navigator.show_unit(99))
        for _ = 1, 120 do
            state.run_timer()
            assert.is_truthy(navigator.is_running())
        end
        state.run_timer()
        assert.is_falsy(navigator.is_running())
        assert.is_nil(state.repeater)
        assert.are.equal(
            'SoulSearch: unit 99 did not become available in the Creatures panel.',
            state.printed[2])
    end)

end)