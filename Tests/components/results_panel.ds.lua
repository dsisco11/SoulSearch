local gui = require('gui')
local ResultsPanel = reqscript('internal/soulsearch/ui/results_panel').ResultsPanel
local SoulSearchTooltip = reqscript('internal/soulsearch/ui_tooltip').SoulSearchTooltip
local TooltipAgent = reqscript('internal/soulsearch/ui/tooltip_agent').TooltipAgent

---@class tests.ResultsPanelScreen: gui.ZScreen
---@field panel ResultsPanel
---@field callbacks table
local ResultsPanelScreen = defclass(nil, gui.ZScreen)
ResultsPanelScreen.ATTRS{callbacks=DEFAULT_NIL,
    focus_path='soulsearch/results-panel-test'}

---Builds the production Results Panel and its tooltip renderer.
function ResultsPanelScreen:init()
    self.panel = ResultsPanel{view_id='results_panel',
        frame={l=0, t=0, w=64, h=14}, inputs=self.callbacks}
    self.tooltip = SoulSearchTooltip{view_id='tooltip'}
    self:addviews{self.panel, self.tooltip}
    self.panel:set_choices({
        {text='Ada', result={unit_id=1, name='Ada'}},
        {text='Borin', result={unit_id=2, name='Borin'}},
        {text='Cera', result={unit_id=3, name='Cera'}},
    }, 1)
    self.tooltip_agent = TooltipAgent.new(self, self.tooltip)
end

---Updates production tooltip state after each screen render.
---@param dc dfhack.pen_array
function ResultsPanelScreen:onRender(dc)
    self.tooltip_agent:update()
    ResultsPanelScreen.super.onRender(self, dc)
end

---Creates spies for ResultsPanel host callbacks.
---@return table callbacks
local function results_callbacks()
    return {on_query=spy.new(function() end), on_select=spy.new(function() end),
        on_submit=spy.new(function() end), on_sort=spy.new(function() end)}
end

---Mounts the Results Panel component fixture.
---@return table callbacks
local function mount_results_panel()
    local callbacks = results_callbacks()
    ds.mount(ResultsPanelScreen{callbacks=callbacks})
    return callbacks
end

describe('SoulSearch Results Panel', function()
    it('types search text and preserves the rendered query', function()
        local callbacks = mount_results_panel()
        local search = ds.get('results_panel/search_field')
        search:click()
        search:type('miner')
        assert.spy(callbacks.on_query).was_called_with('miner', 'mine')
        assert.equals('miner', ds.get('results_panel/search_field'):inspect().text)
    end)

    it('navigates, selects, submits, and preserves requested selection', function()
        local callbacks = mount_results_panel()
        local list = ds.get('results_panel/result_list')
        list:input('STANDARDSCROLL_DOWN')
        assert.spy(callbacks.on_select).was_called_with({unit_id=2, name='Borin'})
        list:raw():submit()
        assert.spy(callbacks.on_submit).was_called_with({unit_id=2, name='Borin'})
        ds.get('results_panel'):raw():set_choices({
            {text='Cera', result={unit_id=3, name='Cera'}},
            {text='Borin', result={unit_id=2, name='Borin'}},
        }, 2)
        assert.equals(2, list:raw():getSelected())
    end)

    it('dispatches every column sort and preserves result selection', function()
        local callbacks = mount_results_panel()
        local panel = ds.get('results_panel'):raw()
        local columns = {
            {'result_columns', 'name'}, {'result_profession_column', 'profession'},
            {'result_unit_id_column', 'unit_id'},
        }
        for _, column in ipairs(columns) do
            ds.get('results_panel/' .. column[1]):raw().on_change()
            assert.spy(callbacks.on_sort).was_called_with(column[2])
        end
        panel:set_header_text('Results', '-------', nil, {key='name', reverse=false})
        panel:set_header_text('Results', '-------', nil, {key='name', reverse=true})
        panel:set_header_text('Results', '-------', nil, nil)
        assert.equals(1, panel:get_selected_index())
    end)

    it('renders each declared sort tooltip on hover', function()
        mount_results_panel()
        for _, case in ipairs({
            {'result_columns', 'Sort by name.'},
            {'result_profession_column', 'Sort by profession.'},
            {'result_unit_id_column', 'Sort by unit ID.'},
        }) do
            local header = ds.get('results_panel/' .. case[1])
            header:hover()
            ds.wait_frames(1)
            assert.equals(case[2], ds.get('tooltip'):raw().tooltip_text)
        end
    end)
end)
