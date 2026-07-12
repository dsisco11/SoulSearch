--@ module=true

---@class SoulSearchFilterState
local FilterState = {}

local descriptors = reqscript('internal/soulsearch/descriptors')

local FILTER_HIGH = 'high'
local FILTER_LOW = 'low'

---@type table<SoulSearchFilterState, SoulSearchSelectedFilter[]>
local filters_by_state = setmetatable({}, {__mode='k'})

---@type SoulSearchSelectedFilter[]
local saved_filters = {}

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
    table.remove(get_internal_filters(state), priority)
    return true
end

---@param state SoulSearchFilterState
---@return boolean changed
function clear(state)
    local filters = get_internal_filters(state)
    if #filters == 0 then
        return false
    end
    filters_by_state[state] = {}
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
    local filter = get_internal_filters(state)[priority]
    if filter.direction == direction then
        return false
    end
    filter.direction = direction
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
    local new_priority = math.max(1, math.min(#filters, priority + delta))
    if new_priority == priority then
        return false, priority
    end
    local filter = table.remove(filters, priority)
    table.insert(filters, new_priority, filter)
    return true, new_priority
end

---Loads a copy of the persisted filter state, validating it against the active
---descriptor catalog. Persistence belongs to this module and lasts for this
---loaded script environment; world/script lifecycle policy does not clear it.
---@return SoulSearchFilterState
function load()
    return new(saved_filters)
end

---Persists an isolated ordered copy for the next window in this script session.
---@param state SoulSearchFilterState
function save(state)
    saved_filters = copy_filters(get_internal_filters(state))
end
