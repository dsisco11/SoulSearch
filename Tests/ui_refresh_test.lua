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
    function owner:refresh_candidates() record(self, 'candidates') end
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

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local ui_refresh = soulsearch_env.load_ui_refresh(repo_root)

    add_test('UI refresh: filter change refreshes each dependent view once', function()
        local owner = make_owner()
        ui_refresh.apply(owner, {
            active_filters=true,
            pickers=true,
            results=true,
            selected_filter=3,
        })
        luaunit.assertEquals(
            {'active_filters', 'pickers', 'results', 'stats'},
            owner.calls)
        luaunit.assertIs(1, owner.counts.results)
        luaunit.assertIs(1, owner.counts.stats)
        luaunit.assertIs(3, owner.values.active_filters)
        luaunit.assertIs(42, owner.last_value.unit_id)
    end)

    add_test('UI refresh: picker change never recomputes results', function()
        local owner = make_owner()
        ui_refresh.apply(owner, {pickers=true})
        luaunit.assertEquals({'pickers'}, owner.calls)
        luaunit.assertNil(owner.counts.results)
        luaunit.assertNil(owner.counts.stats)
    end)

    add_test('UI refresh: candidate refresh precedes result recomputation', function()
        local owner = make_owner()
        ui_refresh.apply(owner, {candidates=true, results=true})
        luaunit.assertEquals({'candidates', 'results', 'stats'}, owner.calls)
        luaunit.assertIs(1, owner.counts.candidates)
        luaunit.assertIs(1, owner.counts.results)
    end)

    add_test('UI refresh: preset change never recomputes results', function()
        local owner = make_owner()
        ui_refresh.apply(owner, {presets=true})
        luaunit.assertEquals({'presets'}, owner.calls)
        luaunit.assertNil(owner.counts.results)
        luaunit.assertNil(owner.counts.stats)
    end)

    add_test('UI refresh: query or resident change recomputes once', function()
        local owner = make_owner()
        ui_refresh.apply(owner, {results=true})
        luaunit.assertEquals({'results', 'stats'}, owner.calls)
        luaunit.assertIs(1, owner.counts.results)
    end)

    add_test('UI refresh: selection or sort change refreshes only stats', function()
        local owner = make_owner()
        ui_refresh.apply(owner, {stats=true})
        luaunit.assertEquals({'get_selected_result', 'stats'}, owner.calls)
        luaunit.assertIs(7, owner.last_value.unit_id)
        luaunit.assertNil(owner.counts.results)
    end)

    add_test('UI refresh: result selection preserves unit identity', function()
        local results = {{unit_id=1}, {unit_id=7}, {unit_id=3}}
        luaunit.assertIs(2, ui_refresh.get_result_selection(results, 7, 1))
    end)

    add_test('UI refresh: missing resident keeps and clamps list position', function()
        local results = {{unit_id=1}, {unit_id=2}}
        luaunit.assertIs(2, ui_refresh.get_result_selection(results, 7, 2))
        luaunit.assertIs(2, ui_refresh.get_result_selection(results, 7, 5))
        luaunit.assertIs(1, ui_refresh.get_result_selection({}, 7, 5))
    end)

return native_tests
