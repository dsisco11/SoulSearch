local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('stats layout: component geometry and hitboxes are stable', function()
        local layout = soulsearch_env.load_stats_layout(repo_root)
        luaunit.assertIs('label', layout.get_header_column(0, 0))
        luaunit.assertIs('label', layout.get_header_column(22, 0))
        luaunit.assertIs('value', layout.get_header_column(26, 0))
        luaunit.assertNil(layout.get_header_column(23, 0))
        luaunit.assertNil(layout.get_header_column(26, 1))
        luaunit.assertEvalToTrue(layout.is_label_cell(2, 0))
        luaunit.assertEvalToTrue(layout.is_value_cell(32, 0))
        local compact = layout.get_overlay_columns(false)
        luaunit.assertIs(27, compact.value_column_x)
        luaunit.assertIs(26, compact.label_width)
        luaunit.assertIs(0, compact.label_inset)
        local scrolling = layout.get_overlay_columns(true)
        luaunit.assertIs(25, scrolling.value_column_x)
        luaunit.assertIs(24, scrolling.label_width)
        luaunit.assertIs(0, scrolling.label_inset)
        luaunit.assertEvalToTrue(layout.is_label_cell(0, 0, compact))
        luaunit.assertEvalToTrue(layout.is_value_cell(25, 0, scrolling))
        luaunit.assertEvalToFalse(layout.is_value_cell(25, 0, compact))
        local frames = layout.get_content_frames(12, 10, 3)
        luaunit.assertIs(0, frames.header.t)
        luaunit.assertIs(9, frames.header.h)
        luaunit.assertIs(9, frames.columns.t)
        luaunit.assertIs(2, frames.columns.h)
        luaunit.assertIs(11, frames.body.t)
        local minimum = layout.get_content_frames(1, 1, 2)
        luaunit.assertIs(2, minimum.body.t)
    end)

return native_tests
