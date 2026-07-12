--@ module=true

---@class SoulSearchRefreshRequest
---@field active_filters boolean|nil
---@field pickers boolean|nil
---@field presets boolean|nil
---@field candidates boolean|nil
---@field results boolean|nil
---@field stats boolean|nil
---@field selected_filter integer|nil
---@field result SoulSearchResult|nil

---@class SoulSearchRefreshOwner
---@field refresh_active_filter_choices fun(self: SoulSearchRefreshOwner, selected: integer|nil)
---@field refresh_picker_choices fun(self: SoulSearchRefreshOwner)
---@field refresh_preset_choices fun(self: SoulSearchRefreshOwner)
---@field refresh_candidates fun(self: SoulSearchRefreshOwner)
---@field recompute_results fun(self: SoulSearchRefreshOwner): SoulSearchResult|nil
---@field refresh_stats fun(self: SoulSearchRefreshOwner, result: SoulSearchResult|nil)
---@field get_selected_result fun(self: SoulSearchRefreshOwner): SoulSearchResult|nil

---Applies each requested derived-view refresh at most once in dependency order.
---The dispatcher never mutates domain or picker state.
---@param owner SoulSearchRefreshOwner
---@param request SoulSearchRefreshRequest
function apply(owner, request)
    if request.active_filters then
        owner:refresh_active_filter_choices(request.selected_filter)
    end
    if request.pickers then
        owner:refresh_picker_choices()
    end
    if request.presets then
        owner:refresh_preset_choices()
    end
    if request.candidates then
        owner:refresh_candidates()
    end

    local result = request.result
    if request.results then
        result = owner:recompute_results()
    elseif request.stats and result == nil then
        result = owner:get_selected_result()
    end
    if request.results or request.stats then
        owner:refresh_stats(result)
    end
end

---Chooses a result row after recomputation. Unit identity wins; if that unit is
---gone, retain the previous list position and clamp it to the new final row.
---@param results SoulSearchResult[]
---@param previous_unit_id integer|nil
---@param previous_index integer|nil
---@return integer
function get_result_selection(results, previous_unit_id, previous_index)
    if previous_unit_id then
        for index, result in ipairs(results) do
            if result.unit_id == previous_unit_id then
                return index
            end
        end
    end
    return math.max(1, math.min(previous_index or 1, #results))
end
