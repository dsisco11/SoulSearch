--@ module=true

local function enum_keys(enum)
    local keys = {}
    for key, value in pairs(enum) do
        if type(key) == 'string' and type(value) == 'number' and key:sub(1, 1) ~= '_' then
            table.insert(keys, {name=key, value=value})
        end
    end
    table.sort(keys, function(a, b) return a.value < b.value end)
    return keys
end

local function copy_position(pos)
    if not pos then
        return nil
    end
    return {x=pos.x, y=pos.y, z=pos.z}
end

local function get_trait_values(unit)
    local values = {}
    local soul = unit.status and unit.status.current_soul
    local personality = soul and soul.personality
    local traits = personality and personality.traits
    if not traits then
        return values
    end

    for _, trait in ipairs(enum_keys(df.personality_facet_type)) do
        local ok, value = pcall(function() return traits[trait.value] end)
        if ok and value ~= nil then
            values[trait.name] = value
        end
    end
    return values
end

local function get_mental_attribute_values(unit)
    local values = {}
    for _, attr in ipairs(enum_keys(df.mental_attribute_type)) do
        local ok, value = pcall(dfhack.units.getMentalAttrValue, unit, attr.value)
        if ok and value ~= nil then
            values[attr.name] = value
        end
    end
    return values
end

local function get_readable_name(unit)
    local name = dfhack.units.getReadableName(unit)
    if name and name ~= '' then
        return name
    end
    return ('Unit #%d'):format(unit.id)
end

local function build_resident_row(unit)
    return {
        unit=unit,
        unit_id=unit.id,
        name=get_readable_name(unit),
        profession=dfhack.units.getProfessionName(unit),
        position=copy_position(dfhack.units.getPosition(unit)),
        traits=get_trait_values(unit),
        mental_attributes=get_mental_attribute_values(unit),
    }
end

function get_unavailable_reason()
    if not dfhack.isMapLoaded() then
        return 'DwarfSearch requires a loaded fortress map.'
    end
    if not dfhack.world.isFortressMode() then
        return 'DwarfSearch only works in fortress mode.'
    end
    return nil
end

function collect_residents()
    local reason = get_unavailable_reason()
    if reason then
        return nil, reason
    end

    local rows = {}
    for _, unit in ipairs(dfhack.units.getCitizens(false, true)) do
        table.insert(rows, build_resident_row(unit))
    end
    return rows
end
