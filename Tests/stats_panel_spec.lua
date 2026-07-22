local env = require('support.soulsearch_env')
local root = require('support.repo_root')

describe('stats panel', function()

    it('stats panel: host API and layout are isolated from terminal tooltip ownership', function()
        local Panel = env.load_stats_panel(root)
        local changes = {}
        local incoming = {key='label', reverse=false, phase=1}
        local panel = Panel{subject={row={}, unit={}}, sort=incoming,
            on_sort_change=function(sort) table.insert(changes, sort) end}
        incoming.key='value'
        assert.are.equal('label', panel:get_sort().key)
        local read = panel:get_sort(); read.key='value'
        assert.are.equal('label', panel:get_sort().key)
        panel:set_sort({key='value', phase=1})
        assert.are.equal(0, #changes)
        local layouts = 0
        panel.frame_parent_rect = {}
        panel.updateLayout = function() layouts = layouts + 1 end
        panel:set_subject({row={}, unit={}})
        assert.are.equal(1, layouts)
        panel.subviews.stats_list.subviews.body.start_line_num=9
        panel:reset_view_state({key='label', phase=1})
        assert.are.equal(1, panel.subviews.stats_list.subviews.body.start_line_num)
        assert.are.equal(0, #changes)
        panel:cycle_sort('value')
        assert.are.equal(1, #changes)
        changes[1].key='label'
        assert.are.equal('value', panel:get_sort().key)
        -- widgets.Panel invokes its on_layout attribute with dot syntax after
        -- it computes the panel body frame.
        panel.on_layout({height=12})
        assert.is_nil(panel.subviews.title)
        assert.is_nil(panel.subviews.underline)
        assert.is_nil(panel.subviews.header)
        assert.are.equal(0, panel.subviews.unit_identity.frame.t)
        assert.are.equal(3, panel.subviews.unit_identity.frame.h)
        assert.are.equal(1, panel.subviews.stats_list.header_height)
    end)

end)
