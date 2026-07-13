--@ module=true

---@class SoulSearchFilterState
local FilterState = {}

local descriptors = reqscript('internal/soulsearch/descriptors')
local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

local FILTER_HIGH = filter_constants.direction.HIGH
local FILTER_LOW = filter_constants.direction.LOW
local FILTER_BEHAVIOR_CANDIDATE = filter_constants.behavior.CANDIDATE
local FILTER_BEHAVIOR_RANKING = filter_constants.behavior.RANKING
local DEFAULT_RACE_FILTER_ID = filter_constants.default_race_filter_id

---@type table<SoulSearchFilterState, SoulSearchSelectedFilter[]>
local filters_by_state = setmetatable({}, {__mode='k'})

---@param direction any
---@return boolean
local function is_valid_direction(direction)
    return direction == FILTER_HIGH or direction == FILTER_LOW
end

---@param filters SoulSearchSelectedFilter[]
---@return SoulSearchSelectedFilter[]
local function copy_filters(filters)
    local copy = {}
    for _, filter in ipairs(filters) do
        table.insert(copy, {id=filter.id, direction=filter.direction})
    end
    return copy
end

---@param first SoulSearchSelectedFilter[]
---@param second SoulSearchSelectedFilter[]
---@return boolean
local function filters_equal(first, second)
    if #first ~= #second then return false end
    for index, filter in ipairs(first) do
        local other = second[index]
        if filter.id ~= other.id or filter.direction ~= other.direction then
            return false
        end
    end
    return true
end

---@param state SoulSearchFilterState
---@return SoulSearchSelectedFilter[]
local function get_internal_filters(state)
    local filters = filters_by_state[state]
    assert(filters, 'expected a SoulSearchFilterState')
    return filters
end

---@param filters SoulSearchSelectedFilter[]|nil
---@return SoulSearchSelectedFilter[]
local function validate(filters)
    local valid = {}
    local seen = {}
    local catalog = descriptors.get_catalog()
    for _, filter in ipairs(type(filters) == 'table' and filters or {}) do
        if type(filter) == 'table' and
                type(filter.id) == 'string' and
                catalog.by_id[filter.id] and
                is_valid_direction(filter.direction) and
                not seen[filter.id] then
            seen[filter.id] = true
            table.insert(valid, {id=filter.id, direction=filter.direction})
        end
    end
    local has_positive_race = false
    local default_race
    for _, filter in ipairs(valid) do
        local descriptor = catalog.by_id[filter.id]
        if descriptor and descriptor.behavior == FILTER_BEHAVIOR_CANDIDATE and
                filter.direction == FILTER_HIGH then
            has_positive_race = true
            break
        end
        if filter.id == DEFAULT_RACE_FILTER_ID then default_race = filter end
    end
    if not has_positive_race then
        if default_race then
            -- A single filter ID cannot hold both directions. Restoring the
            -- default inclusion is the only non-duplicating representation.
            default_race.direction = FILTER_HIGH
        else
            table.insert(valid, 1, {
                id=DEFAULT_RACE_FILTER_ID,
                direction=FILTER_HIGH,
            })
        end
    end
    return valid
end

---@param filters SoulSearchSelectedFilter[]|nil
---@return SoulSearchFilterState
function new(filters)
    local state = setmetatable({}, {__index=FilterState})
    filters_by_state[state] = validate(filters)
    return state
end

---@param state SoulSearchFilterState
---@return SoulSearchSelectedFilter[]
function get_filters(state)
    return copy_filters(get_internal_filters(state))
end

---@param state SoulSearchFilterState
---@param behavior SoulSearchFilterBehavior
---@return SoulSearchSelectedFilter[]
local function get_filters_by_behavior(state, behavior)
    local result = {}
    local catalog = descriptors.get_catalog()
    for _, filter in ipairs(get_internal_filters(state)) do
        local descriptor = catalog.by_id[filter.id]
        if descriptor and descriptor.behavior == behavior then
            table.insert(result, {id=filter.id, direction=filter.direction})
        end
    end
    return result
end

---Returns an isolated ordered copy of filters that select candidate units.
---@param state SoulSearchFilterState
---@return SoulSearchSelectedFilter[]
function get_candidate_filters(state)
    return get_filters_by_behavior(state, FILTER_BEHAVIOR_CANDIDATE)
end

---Returns an isolated ordered copy of filters that rank already-selected rows.
---@param state SoulSearchFilterState
---@return SoulSearchSelectedFilter[]
function get_ranking_filters(state)
    return get_filters_by_behavior(state, FILTER_BEHAVIOR_RANKING)
end

---@param state SoulSearchFilterState
---@return integer
function count(state)
    return #get_internal_filters(state)
end

---@param state SoulSearchFilterState
---@param filter_id string
---@return integer|nil
function get_priority(state, filter_id)
    for index, filter in ipairs(get_internal_filters(state)) do
        if filter.id == filter_id then
            return index
        end
    end
    return nil
end

---@param state SoulSearchFilterState
---@param filter_id string
---@return boolean
function contains(state, filter_id)
    return get_priority(state, filter_id) ~= nil
end

---@param state SoulSearchFilterState
---@param filter_id string
---@return SoulSearchFilterDirection|nil
function get_direction(state, filter_id)
    local priority = get_priority(state, filter_id)
    local filter = priority and get_internal_filters(state)[priority]
    return filter and filter.direction or nil
end

---@param state SoulSearchFilterState
---@param filter_id string
---@param direction SoulSearchFilterDirection|nil
---@return boolean changed
function add(state, filter_id, direction)
    direction = direction or FILTER_HIGH
    if contains(state, filter_id) or
            not descriptors.get_catalog().by_id[filter_id] or
            not is_valid_direction(direction) then
        return false
    end
    table.insert(get_internal_filters(state), {id=filter_id, direction=direction})
    return true
end

---@param state SoulSearchFilterState
---@param filter_id string
---@return boolean changed
function remove(state, filter_id)
    local priority = get_priority(state, filter_id)
    if not priority then
        return false
    end
    local current = get_internal_filters(state)
    local next = copy_filters(current)
    table.remove(next, priority)
    next = validate(next)
    if filters_equal(current, next) then return false end
    filters_by_state[state] = next
    return true
end

---@param state SoulSearchFilterState
---@return boolean changed
function clear(state)
    local current = get_internal_filters(state)
    local reset = validate({})
    if filters_equal(current, reset) then
        return false
    end
    filters_by_state[state] = reset
    return true
end

---Replaces the active filters with a validated ordered copy. This is used by
---preset loading so stale descriptor IDs are safely ignored.
---@param state SoulSearchFilterState
---@param filters SoulSearchSelectedFilter[]|nil
---@return boolean changed
function replace(state, filters)
    local valid = validate(filters)
    local current = get_internal_filters(state)
    if filters_equal(current, valid) then
        return false
    end
    filters_by_state[state] = valid
    return true
end

---Changes an active filter or atomically adds an inactive filter with the given
---direction. Invalid IDs/directions and unchanged directions are no-ops.
---@param state SoulSearchFilterState
---@param filter_id string
---@param direction SoulSearchFilterDirection
---@return boolean changed
function set_direction(state, filter_id, direction)
    if not is_valid_direction(direction) then
        return false
    end
    local priority = get_priority(state, filter_id)
    if not priority then
        return add(state, filter_id, direction)
    end
    local current = get_internal_filters(state)
    local next = copy_filters(current)
    next[priority].direction = direction
    next = validate(next)
    if filters_equal(current, next) then return false end
    filters_by_state[state] = next
    return true
end

---Moves a filter by delta positions, clamped to the collection boundaries.
---@param state SoulSearchFilterState
---@param filter_id string
---@param delta integer
---@return boolean changed
---@return integer|nil new_priority
function move(state, filter_id, delta)
    local filters = get_internal_filters(state)
    local priority = get_priority(state, filter_id)
    if not priority then
        return false, nil
    end
    local catalog = descriptors.get_catalog()
    local descriptor = catalog.by_id[filter_id]
    if not descriptor or descriptor.behavior == FILTER_BEHAVIOR_CANDIDATE then
        return false, priority
    end
    local priorities = {}
    for index, filter in ipairs(filters) do
        local other = catalog.by_id[filter.id]
        if other and other.behavior == descriptor.behavior then
            table.insert(priorities, index)
        end
    end
    local ranking_priority
    for index, value in ipairs(priorities) do
        if value == priority then ranking_priority = index break end
    end
    local new_ranking_priority = math.max(1,
        math.min(#priorities, ranking_priority + delta))
    if new_ranking_priority == ranking_priority then
        return false, priority
    end
    local filter = table.remove(filters, priority)
    local new_priority = priorities[new_ranking_priority]
    table.insert(filters, new_priority, filter)
    return true, new_priority
end
