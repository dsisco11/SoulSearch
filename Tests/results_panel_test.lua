local soulsearch_env = require('support.soulsearch_env')

local function ids(views)
    local result = {}
    for _, view in ipairs(views or {}) do table.insert(result, view.view_id) end
    return result
end

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local module = soulsearch_env.load_results_panel(repo_root)

    local function make_panel(calls)
        return module.ResultsPanel{view_id='results_panel', frame={l=0,t=0,r=0,b=0},
            inputs={
                on_query=function(text) calls.query = text end,
                on_select=function(result) calls.selected = result end,
                on_submit=function(result) calls.submitted = result end,
                on_sort=function(column) calls.sorted = column end,
            }}
    end

    add_test('results panel: owns the stable result view hierarchy', function()
        local panel = make_panel({})
        luaunit.assertIs('Panel', panel.widget_kind)
        luaunit.assertEquals({'search_field', 'result_header',
            'result_header_underline', 'result_columns',
            'result_profession_column', 'result_unit_id_column', 'result_list'},
            ids(panel.subviews))
        luaunit.assertIs('CUSTOM_F', panel.subviews.search_field.key)
        luaunit.assertEvalToTrue(panel.subviews.search_field.modal)
    end)

    add_test('results panel: preserves query, selection, submission, and sort callbacks', function()
        local calls = {}
        local panel = make_panel(calls)
        local result = {unit_id=42}
        panel.subviews.search_field.on_change('miner')
        panel.subviews.result_list.on_select(1, {result=result})
        panel.subviews.result_list.on_submit(1, {result=result})
        panel.subviews.result_columns.on_change()
        luaunit.assertIs('miner', calls.query)
        luaunit.assertEvalToTrue(calls.selected == result)
        luaunit.assertEvalToTrue(calls.submitted == result)
        luaunit.assertIs('name', calls.sorted)
    end)

    add_test('results panel: exposes narrow update, navigation, and declared header tooltips', function()
        local panel = make_panel({})
        local result = {unit_id=7}
        panel:set_query_text('smith')
        panel:set_header_text('Results (1)', '-----------', nil,
            {key='unit_id', reverse=true})
        panel:set_choices({{result=result}}, 1)
        panel:move_cursor(-10)
        luaunit.assertIs('smith', panel.subviews.search_field.text)
        luaunit.assertIs('Results (1)', panel.subviews.result_header.text)
        luaunit.assertIs(1, panel:get_selected_index())
        luaunit.assertEvalToTrue(panel:get_selected_result() == result)
        luaunit.assertIs(-10, panel.subviews.result_list.cursor_delta)
        luaunit.assertIs(0, panel.subviews.result_columns.option)
        luaunit.assertIs(0, panel.subviews.result_profession_column.option)
        luaunit.assertIs(2, panel.subviews.result_unit_id_column.option)
        luaunit.assertIs('Sort by name.', panel.subviews.result_columns.tooltip)
        luaunit.assertIs('Sort by profession.', panel.subviews.result_profession_column.tooltip)
        luaunit.assertIs('Sort by unit ID.', panel.subviews.result_unit_id_column.tooltip)
    end)

return native_tests
