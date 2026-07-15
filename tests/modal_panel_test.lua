local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
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

    test.case('modal panel: open and close transitions are idempotent', function()
        local panel, get_state = make_panel()
        test.assert_false(panel.visible)
        test.assert_equal('block', panel.pointer_policy)
        test.assert_true(panel:open())
        test.assert_false(panel:open())
        test.assert_true(panel.focused)
        test.assert_true(panel.visible)
        local open, opens, closes = get_state()
        test.assert_true(open)
        test.assert_equal(1, opens)
        test.assert_equal(0, closes)

        test.assert_true(panel:close())
        test.assert_false(panel:close())
        test.assert_false(panel.focused)
        test.assert_false(panel.visible)
        open, opens, closes = get_state()
        test.assert_false(open)
        test.assert_equal(1, opens)
        test.assert_equal(1, closes)
    end)

    test.case('modal panel: input capture and right-click dismissal are exact', function()
        local panel, get_state = make_panel()
        panel.mouse_x, panel.mouse_y = 1, 1
        test.assert_false(panel:onInput{_MOUSE_L=true})
        panel:open()
        test.assert_true(panel:onInput{_MOUSE_L=true})
        test.assert_true(panel:onInput{_MOUSE_R=true})
        local open, _, closes = get_state()
        test.assert_false(open)
        test.assert_equal(1, closes)

        panel:open()
        panel.mouse_x, panel.mouse_y = nil, nil
        test.assert_false(panel:onInput{_MOUSE_L=true})
        test.assert_true(get_state())
    end)

    test.case('modal panel: child input wins before modal mouse handling', function()
        local panel = make_panel()
        panel:open()
        panel.super_input_result = true
        panel.mouse_x, panel.mouse_y = nil, nil
        test.assert_true(panel:onInput{})
        test.assert_equal(1, panel.super_input_calls)
    end)

end
