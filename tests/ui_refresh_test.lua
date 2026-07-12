local soulsearch_env = require('support.soulsearch_env')

local function make_owner()
    local owner = {calls={}, counts={}}
    local function record(self, name, value)
        table.insert(self.calls, name)
        self.counts[name] = (self.counts[name] or 0) + 1
        self.values = self.values or {}
        self.values[name] = value
        self.last_value = value
    end
    function owner:refresh_active_filter_choices(selected)
        record(self, 'active_filters', selected)
    end
    function owner:refresh_picker_choices() record(self, 'pickers') end
    function owner:refresh_preset_choices() record(self, 'presets') end
    function owner:recompute_results()
        record(self, 'results')
        return {unit_id=42}
    end
    function owner:refresh_stats(result) record(self, 'stats', result) end
    function owner:get_selected_result()
        record(self, 'get_selected_result')
        return {unit_id=7}
    end
    return owner
end

return function(test, repo_root)
    local ui_refresh = soulsearch_env.load_ui_refresh(repo_root)

    test.case('UI refresh: filter change refreshes each dependent view once', function()
        local owner = make_owner()
        ui_refresh.apply(owner, {
            active_filters=true,
            pickers=true,
            results=true,
            selected_filter=3,
        })
        test.assert_sequence(
            {'active_filters', 'pickers', 'results', 'stats'},
            owner.calls)
        test.assert_equal(1, owner.counts.results)
        test.assert_equal(1, owner.counts.stats)
        test.assert_equal(3, owner.values.active_filters)
        test.assert_equal(42, owner.last_value.unit_id)
    end)

    test.case('UI refresh: picker change never recomputes results', function()
        local owner = make_owner()
        ui_refresh.apply(owner, {pickers=true})
        test.assert_sequence({'pickers'}, owner.calls)
        test.assert_nil(owner.counts.results)
        test.assert_nil(owner.counts.stats)
    end)

    test.case('UI refresh: preset change never recomputes results', function()
        local owner = make_owner()
        ui_refresh.apply(owner, {presets=true})
        test.assert_sequence({'presets'}, owner.calls)
        test.assert_nil(owner.counts.results)
        test.assert_nil(owner.counts.stats)
    end)

    test.case('UI refresh: query or resident change recomputes once', function()
        local owner = make_owner()
        ui_refresh.apply(owner, {results=true})
        test.assert_sequence({'results', 'stats'}, owner.calls)
        test.assert_equal(1, owner.counts.results)
    end)

    test.case('UI refresh: selection or sort change refreshes only stats', function()
        local owner = make_owner()
        ui_refresh.apply(owner, {stats=true})
        test.assert_sequence({'get_selected_result', 'stats'}, owner.calls)
        test.assert_equal(7, owner.last_value.unit_id)
        test.assert_nil(owner.counts.results)
    end)

    test.case('UI refresh: result selection preserves unit identity', function()
        local results = {{unit_id=1}, {unit_id=7}, {unit_id=3}}
        test.assert_equal(2, ui_refresh.get_result_selection(results, 7, 1))
    end)

    test.case('UI refresh: missing resident keeps and clamps list position', function()
        local results = {{unit_id=1}, {unit_id=2}}
        test.assert_equal(2, ui_refresh.get_result_selection(results, 7, 2))
        test.assert_equal(2, ui_refresh.get_result_selection(results, 7, 5))
        test.assert_equal(1, ui_refresh.get_result_selection({}, 7, 5))
    end)
end
