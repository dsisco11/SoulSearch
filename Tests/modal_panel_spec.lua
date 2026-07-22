local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('modal panel', function()

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

    it('modal panel: open and close transitions are idempotent', function()
        local panel, get_state = make_panel()
        assert.is_falsy(panel.visible)
        assert.are.equal('block', panel.pointer_policy)
        assert.is_truthy(panel:open())
        assert.is_falsy(panel:open())
        assert.is_truthy(panel.focused)
        assert.is_truthy(panel.visible)
        local open, opens, closes = get_state()
        assert.is_truthy(open)
        assert.are.equal(1, opens)
        assert.are.equal(0, closes)

        assert.is_truthy(panel:close())
        assert.is_falsy(panel:close())
        assert.is_falsy(panel.focused)
        assert.is_falsy(panel.visible)
        open, opens, closes = get_state()
        assert.is_falsy(open)
        assert.are.equal(1, opens)
        assert.are.equal(1, closes)
    end)

    it('modal panel: input capture and right-click dismissal are exact', function()
        local panel, get_state = make_panel()
        panel.mouse_x, panel.mouse_y = 1, 1
        assert.is_falsy(panel:onInput{_MOUSE_L=true})
        panel:open()
        assert.is_truthy(panel:onInput{_MOUSE_L=true})
        assert.is_truthy(panel:onInput{_MOUSE_R=true})
        local open, _, closes = get_state()
        assert.is_falsy(open)
        assert.are.equal(1, closes)

        panel:open()
        panel.mouse_x, panel.mouse_y = nil, nil
        assert.is_falsy(panel:onInput{_MOUSE_L=true})
        assert.is_truthy(get_state())
    end)

    it('modal panel: child input wins before modal mouse handling', function()
        local panel = make_panel()
        panel:open()
        panel.super_input_result = true
        panel.mouse_x, panel.mouse_y = nil, nil
        assert.is_truthy(panel:onInput{})
        assert.are.equal(1, panel.super_input_calls)
    end)


end)