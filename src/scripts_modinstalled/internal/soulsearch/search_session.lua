--@ module=true

local filter_state = reqscript('internal/soulsearch/filter_state')
local search = reqscript('internal/soulsearch/search')
local unit_scope_provider = reqscript('internal/soulsearch/unit_scope_provider')

local SearchSession = {}
SearchSession.__index = SearchSession

---@enum SoulSearchQueryKind
SEARCH_QUERY_KIND = {
    RESULT='result',
    ATTRIBUTE='attribute',
    SKILL='skill',
    RACE='race',
    PRESET='preset',
}

local QUERY_FIELDS = {
    [SEARCH_QUERY_KIND.RESULT]='query',
    [SEARCH_QUERY_KIND.ATTRIBUTE]='attribute_query',
    [SEARCH_QUERY_KIND.SKILL]='skill_query',
    [SEARCH_QUERY_KIND.RACE]='race_query',
    [SEARCH_QUERY_KIND.PRESET]='preset_query',
}

local function copy_rows(rows)
    local copy = {}
    for index, row in ipairs(rows or {}) do
        local row_copy = {}
        for key, value in pairs(row) do row_copy[key] = value end
        copy[index] = row_copy
    end
    return copy
end

local function copy_sort(sort)
    return {key=sort and sort.key or nil, reverse=sort and sort.reverse or false,
        phase=sort and sort.phase or 0}
end

---@param settings {filters: SoulSearchSelectedFilter[], unit_scope: SoulSearchUnitScope, result_sort: table}
---@return SearchSession
function new(settings)
    unit_scope_provider.new(settings.unit_scope)
    return setmetatable({filter_state=filter_state.new(settings.filters),
        unit_scope=settings.unit_scope, result_sort=copy_sort(settings.result_sort),
        query='', attribute_query='', skill_query='', race_query='', preset_query='',
        rows={}, results={}, selected_unit_id=nil, selected_index=1}, SearchSession)
end

function SearchSession:get_filters() return filter_state.get_filters(self.filter_state) end
function SearchSession:get_ranking_filters() return filter_state.get_ranking_filters(self.filter_state) end
function SearchSession:get_candidate_filters() return filter_state.get_candidate_filters(self.filter_state) end
function SearchSession:filter_count() return filter_state.count(self.filter_state) end
function SearchSession:get_filter_priority(id) return filter_state.get_priority(self.filter_state, id) end
function SearchSession:contains_filter(id) return filter_state.contains(self.filter_state, id) end
function SearchSession:get_filter_direction(id) return filter_state.get_direction(self.filter_state, id) end
function SearchSession:get_unit_scope() return self.unit_scope end
function SearchSession:get_result_sort() return copy_sort(self.result_sort) end

function SearchSession:set_query(kind, text)
    local field = QUERY_FIELDS[kind]
    if not field then return false end
    text = tostring(text or '')
    if self[field] == text then return false end
    self[field] = text
    return true
end

function SearchSession:replace_rows(rows)
    self.rows = copy_rows(rows)
end

function SearchSession:set_selected_result(result, index)
    self.selected_unit_id = result and result.unit_id or nil
    self.selected_index = index or self.selected_index
end

function SearchSession:recompute_results()
    self.results = search.apply(self.rows, {query=self.query,
        selected_filters=self:get_ranking_filters()})
    search.sort_results(self.results, self.result_sort.key, self.result_sort.reverse)
    local index = math.max(1, math.min(self.selected_index, #self.results))
    if self.selected_unit_id then
        for i, result in ipairs(self.results) do
            if result.unit_id == self.selected_unit_id then index = i break end
        end
    end
    return self.results, index
end

function SearchSession:cycle_sort(column)
    local sort = self.result_sort
    if sort.key == column then sort.phase = sort.phase + 1 else sort.key, sort.phase = column, 1 end
    if sort.phase >= 3 then sort.key, sort.reverse, sort.phase = nil, false, 0
    else sort.reverse = sort.phase == 2 end
    return copy_sort(sort)
end

function SearchSession:set_unit_scope(scope)
    if scope == self.unit_scope then return false end
    unit_scope_provider.new(scope)
    self.unit_scope = scope
    return true
end

function SearchSession:add_filter(id) return filter_state.add(self.filter_state, id) end
function SearchSession:remove_filter(id) return filter_state.remove(self.filter_state, id) end
function SearchSession:clear_filters() return filter_state.clear(self.filter_state) end
function SearchSession:replace_filters(filters) return filter_state.replace(self.filter_state, filters) end
function SearchSession:set_filter_direction(id, direction) return filter_state.set_direction(self.filter_state, id, direction) end
function SearchSession:move_filter(id, delta) return filter_state.move(self.filter_state, id, delta) end
