--@ module=true

local candidate_provider =
    reqscript('internal/soulsearch/candidate_provider')
local descriptors = reqscript('internal/soulsearch/descriptors')
local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS

local FILTER_HIGH = filter_constants.direction.HIGH
local FILTER_LOW = filter_constants.direction.LOW

---@param selected_filters SoulSearchSelectedFilter[]|nil
---@param kind SoulSearchFilterKind
---@return {descriptor: SoulSearchFilterDescriptor, direction: SoulSearchFilterDirection}[]
---@return boolean
local function resolve_filters(selected_filters, kind)
    local catalog = descriptors.get_catalog()
    local filters, seen, has_positive = {}, {}, false
    for _, filter in ipairs(selected_filters or {}) do
        local descriptor = type(filter) == 'table' and type(filter.id) == 'string' and
            catalog.by_id[filter.id] or nil
        if descriptor and descriptor.kind == kind and
                descriptor.behavior == filter_constants.behavior.CANDIDATE and
                (filter.direction == FILTER_HIGH or filter.direction == FILTER_LOW) and
                not seen[descriptor.id] then
            seen[descriptor.id] = true
            table.insert(filters, {descriptor=descriptor, direction=filter.direction})
            has_positive = has_positive or filter.direction == FILTER_HIGH
        end
    end
    return filters, has_positive
end

---@param unit df.unit
---@return integer|df.unit
local function get_unit_key(unit)
    return unit.id ~= nil and unit.id or unit
end

---@param upstream SoulSearchCandidateProvider
---@param selected_filters SoulSearchSelectedFilter[]|nil
---@param kind SoulSearchFilterKind
---@param matches_unit fun(descriptor: SoulSearchFilterDescriptor, unit: df.unit): boolean
---@return SoulSearchCandidateProvider
function new(upstream, selected_filters, kind, matches_unit)
    assert(type(upstream) == 'table' and type(upstream.get_units) == 'function',
        'SoulSearch candidate filter family requires an upstream candidate provider')
    assert(type(kind) == 'string',
        'SoulSearch candidate filter family requires a descriptor kind')
    assert(type(matches_unit) == 'function',
        'SoulSearch candidate filter family requires a unit matcher')

    return candidate_provider.new(function()
        local units, err = upstream.get_units()
        if not units then return nil, err end

        local filters, has_positive = resolve_filters(selected_filters, kind)
        local result, seen = {}, {}
        for _, unit in ipairs(units) do
            local key = get_unit_key(unit)
            if not seen[key] then
                local included = not has_positive
                for _, filter in ipairs(filters) do
                    if filter.direction == FILTER_HIGH and
                            matches_unit(filter.descriptor, unit) then
                        included = true
                        break
                    end
                end
                if included then
                    local excluded = false
                    for _, filter in ipairs(filters) do
                        if filter.direction == FILTER_LOW and
                                matches_unit(filter.descriptor, unit) then
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
