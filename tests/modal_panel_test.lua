local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local ModalPanelWindow =
        soulsearch_env.load_modal_panel(repo_root).ModalPanelWindow

    local function make_panel()
        local opens, closes = 0, 0
        local panel = ModalPanelWindow{
            on_open=function() opens = opens + 1 end,
            on_close=function() closes = closes + 1 end,
        }
        function panel:setFocus(value) self.focused = value end
        function panel:getMouseFramePos()
            return self.mouse_x, self.mouse_y
        end
        return panel, function() return panel:is_open(), opens, closes end
    end

    add_test('modal panel: open and close transitions are idempotent', function()
        local panel, get_state = make_panel()
        luaunit.assertEvalToFalse(panel.visible)
        luaunit.assertIs('block', panel.pointer_policy)
        luaunit.assertEvalToTrue(panel:open())
        luaunit.assertEvalToFalse(panel:open())
        luaunit.assertEvalToTrue(panel.focused)
        luaunit.assertEvalToTrue(panel.visible)
        local open, opens, closes = get_state()
        luaunit.assertEvalToTrue(open)
        luaunit.assertIs(1, opens)
        luaunit.assertIs(0, closes)

        luaunit.assertEvalToTrue(panel:close())
        luaunit.assertEvalToFalse(panel:close())
        luaunit.assertEvalToFalse(panel.focused)
        luaunit.assertEvalToFalse(panel.visible)
        open, opens, closes = get_state()
        luaunit.assertEvalToFalse(open)
        luaunit.assertIs(1, opens)
        luaunit.assertIs(1, closes)
    end)

    add_test('modal panel: input capture and right-click dismissal are exact', function()
        local panel, get_state = make_panel()
        panel.mouse_x, panel.mouse_y = 1, 1
        luaunit.assertEvalToFalse(panel:onInput{_MOUSE_L=true})
        panel:open()
        luaunit.assertEvalToTrue(panel:onInput{_MOUSE_L=true})
        luaunit.assertEvalToTrue(panel:onInput{_MOUSE_R=true})
        local open, _, closes = get_state()
        luaunit.assertEvalToFalse(open)
        luaunit.assertIs(1, closes)

        panel:open()
        panel.mouse_x, panel.mouse_y = nil, nil
        luaunit.assertEvalToFalse(panel:onInput{_MOUSE_L=true})
        luaunit.assertEvalToTrue(get_state())
    end)

    add_test('modal panel: child input wins before modal mouse handling', function()
        local panel = make_panel()
        panel:open()
        panel.super_input_result = true
        panel.mouse_x, panel.mouse_y = nil, nil
        luaunit.assertEvalToTrue(panel:onInput{})
        luaunit.assertIs(1, panel.super_input_calls)
    end)


return native_tests
