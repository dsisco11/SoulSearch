--@ module=true

-- Providers are composed per search pass and retain no world-derived cache.

local candidate_provider =
    reqscript('internal/soulsearch/candidate_provider')
local descriptors = reqscript('internal/soulsearch/descriptors')
local race_catalog = reqscript('internal/soulsearch/race_catalog')
local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

local FILTER_HIGH = filter_constants.direction.HIGH
local FILTER_LOW = filter_constants.direction.LOW
local DEFAULT_RACE_FILTER_ID = filter_constants.default_race_filter_id

---@param filter SoulSearchSelectedFilter
---@param catalog SoulSearchFilterCatalog
---@return SoulSearchFilterDescriptor|nil
local function get_race_descriptor(filter, catalog)
    local descriptor = type(filter) == 'table' and
        type(filter.id) == 'string' and catalog.by_id[filter.id] or nil
    if descriptor and descriptor.kind == filter_constants.kind.RACE and
            descriptor.behavior == filter_constants.behavior.CANDIDATE and
            (filter.direction == FILTER_HIGH or filter.direction == FILTER_LOW) then
        return descriptor
    end
    return nil
end

---@param selected_filters SoulSearchSelectedFilter[]|nil
---@return {descriptor: SoulSearchFilterDescriptor, direction: SoulSearchFilterDirection}[]
local function resolve_filters(selected_filters)
    local catalog = descriptors.get_catalog()
    local resolved = {}
    local seen = {}
    local has_positive = false
    for _, filter in ipairs(selected_filters or {}) do
        local descriptor = get_race_descriptor(filter, catalog)
        if descriptor and not seen[descriptor.id] then
            seen[descriptor.id] = true
            table.insert(resolved, {
                descriptor=descriptor,
                direction=filter.direction,
            })
            has_positive = has_positive or filter.direction == FILTER_HIGH
        end
    end
    if not has_positive then
        local default_descriptor = catalog.by_id[DEFAULT_RACE_FILTER_ID]
        assert(default_descriptor,
            'SoulSearch race catalog is missing the Humanoids filter')
        if seen[DEFAULT_RACE_FILTER_ID] then
            for _, filter in ipairs(resolved) do
                if filter.descriptor.id == DEFAULT_RACE_FILTER_ID then
                    filter.direction = FILTER_HIGH
                    break
                end
            end
        else
            table.insert(resolved, 1, {
                descriptor=default_descriptor,
                direction=FILTER_HIGH,
            })
        end
    end
    return resolved
end

---@param unit df.unit
---@return integer|df.unit
local function get_unit_key(unit)
    return unit.id ~= nil and unit.id or unit
end

---@param upstream SoulSearchCandidateProvider
---@param selected_filters SoulSearchSelectedFilter[]|nil
---@return SoulSearchCandidateProvider
function new(upstream, selected_filters)
    assert(type(upstream) == 'table' and type(upstream.get_units) == 'function',
        'SoulSearch race filter provider requires an upstream candidate provider')

    return candidate_provider.new(function()
        local units, err = upstream.get_units()
        if not units then return nil, err end

        -- Resolve catalog IDs and directions once for this provider pass.
        local filters = resolve_filters(selected_filters)
        local result = {}
        local seen = {}
        for _, unit in ipairs(units) do
            local key = get_unit_key(unit)
            if not seen[key] then
                local included = false
                for _, filter in ipairs(filters) do
                    if filter.direction == FILTER_HIGH and
                            race_catalog.matches_unit(filter.descriptor, unit) then
                        included = true
                        break
                    end
                end
                if included then
                    local excluded = false
                    for _, filter in ipairs(filters) do
                        if filter.direction == FILTER_LOW and
                                race_catalog.matches_unit(filter.descriptor, unit) then
                            excluded = true
                            break
                        end
                    end
                    if not excluded then
                        seen[key] = true
                        table.insert(result, unit)
                    end
                end
            end
        end
        return result
    end)
end
