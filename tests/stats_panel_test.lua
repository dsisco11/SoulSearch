local env = require('support.soulsearch_env')
local luaunit = require('luaunit')
local root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    add_test('stats panel: host API and layout are isolated from terminal tooltip ownership', function()
        local Panel = env.load_stats_panel(root)
        local changes = {}
        local incoming = {key='label', reverse=false, phase=1}
        local panel = Panel{subject={row={}, unit={}}, sort=incoming,
            on_sort_change=function(sort) table.insert(changes, sort) end}
        incoming.key='value'
        luaunit.assertIs('label', panel:get_sort().key)
        local read = panel:get_sort(); read.key='value'
        luaunit.assertIs('label', panel:get_sort().key)
        panel:set_sort({key='value', phase=1})
        luaunit.assertIs(0, #changes)
        local layouts = 0
        panel.frame_parent_rect = {}
        panel.updateLayout = function() layouts = layouts + 1 end
        panel:set_subject({row={}, unit={}})
        luaunit.assertIs(1, layouts)
        panel.subviews.stats_list.subviews.body.start_line_num=9
        panel:reset_view_state({key='label', phase=1})
        luaunit.assertIs(1, panel.subviews.stats_list.subviews.body.start_line_num)
        luaunit.assertIs(0, #changes)
        panel:cycle_sort('value')
        luaunit.assertIs(1, #changes)
        changes[1].key='label'
        luaunit.assertIs('value', panel:get_sort().key)
        -- widgets.Panel invokes its on_layout attribute with dot syntax after
        -- it computes the panel body frame.
        panel.on_layout({height=12})
        luaunit.assertNil(panel.subviews.title)
        luaunit.assertNil(panel.subviews.underline)
        luaunit.assertNil(panel.subviews.header)
        luaunit.assertIs(0, panel.subviews.unit_identity.frame.t)
        luaunit.assertIs(3, panel.subviews.unit_identity.frame.h)
        luaunit.assertIs(1, panel.subviews.stats_list.header_height)
    end)

return native_tests
