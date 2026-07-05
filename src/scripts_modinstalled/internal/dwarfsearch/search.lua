--@ module=true

local attributes = reqscript('internal/dwarfsearch/attributes')

local FILTER_HIGH = 'high'
local MATCHED_FILTER_SCORE = 10
local FILTER_PRIORITY_WEIGHT_BONUS = 0.2
local SKILL_CATEGORY_LABOR = 'Labor'
local SKILL_CATEGORY_COMBAT = 'Combat'
local SKILL_CATEGORY_SOCIAL = 'Social'
local SKILL_CATEGORY_OTHER = 'Other Skills'
local SKILL_CATEGORY_KNOWLEDGE = 'Knowledge'

local SKILL_CATEGORY_BY_KEY = {
    MINING=SKILL_CATEGORY_LABOR,
    WOODCUTTING=SKILL_CATEGORY_LABOR,
    WOOD_CUTTING=SKILL_CATEGORY_LABOR,
    CARPENTRY=SKILL_CATEGORY_LABOR,
    BOWYER=SKILL_CATEGORY_LABOR,
    DETAILSTONE=SKILL_CATEGORY_LABOR,
    ENGRAVING=SKILL_CATEGORY_LABOR,
    STONECUTTING=SKILL_CATEGORY_LABOR,
    STONE_CUTTING=SKILL_CATEGORY_LABOR,
    STONE_CARVING=SKILL_CATEGORY_LABOR,
    MASONRY=SKILL_CATEGORY_LABOR,
    ANIMALTRAIN=SKILL_CATEGORY_LABOR,
    ANIMAL_TRAINING=SKILL_CATEGORY_LABOR,
    ANIMALCARE=SKILL_CATEGORY_LABOR,
    ANIMAL_CARE=SKILL_CATEGORY_LABOR,
    DISSECT_FISH=SKILL_CATEGORY_LABOR,
    DISSECT_VERMIN=SKILL_CATEGORY_LABOR,
    PROCESSFISH=SKILL_CATEGORY_LABOR,
    FISH_CLEANING=SKILL_CATEGORY_LABOR,
    FISHING=SKILL_CATEGORY_LABOR,
    BUTCHER=SKILL_CATEGORY_LABOR,
    TRAPPING=SKILL_CATEGORY_LABOR,
    TANNER=SKILL_CATEGORY_LABOR,
    BREWING=SKILL_CATEGORY_LABOR,
    CHEESEMAKING=SKILL_CATEGORY_LABOR,
    CHEESE_MAKING=SKILL_CATEGORY_LABOR,
    MILK=SKILL_CATEGORY_LABOR,
    MILKING=SKILL_CATEGORY_LABOR,
    GELD=SKILL_CATEGORY_LABOR,
    GELDING=SKILL_CATEGORY_LABOR,
    PLANT=SKILL_CATEGORY_LABOR,
    PLANTING=SKILL_CATEGORY_LABOR,
    HERBALISM=SKILL_CATEGORY_LABOR,
    SOAP_MAKING=SKILL_CATEGORY_LABOR,
    POTASH_MAKING=SKILL_CATEGORY_LABOR,
    LYE_MAKING=SKILL_CATEGORY_LABOR,
    DYEING=SKILL_CATEGORY_LABOR,
    COOK=SKILL_CATEGORY_LABOR,
    COOKING=SKILL_CATEGORY_LABOR,
    MILLING=SKILL_CATEGORY_LABOR,
    PROCESS_PLANTS=SKILL_CATEGORY_LABOR,
    SHEARING=SKILL_CATEGORY_LABOR,
    SPINNING=SKILL_CATEGORY_LABOR,
    PRESSING=SKILL_CATEGORY_LABOR,
    BEEKEEPING=SKILL_CATEGORY_LABOR,
    WAX_WORKING=SKILL_CATEGORY_LABOR,
    WOOD_BURNING=SKILL_CATEGORY_LABOR,
    FURNACE_OPERATING=SKILL_CATEGORY_LABOR,
    WEAPONSMITH=SKILL_CATEGORY_LABOR,
    WEAPONSMITHING=SKILL_CATEGORY_LABOR,
    ARMORER=SKILL_CATEGORY_LABOR,
    ARMORSMITH=SKILL_CATEGORY_LABOR,
    ARMORSMITHING=SKILL_CATEGORY_LABOR,
    BLACKSMITH=SKILL_CATEGORY_LABOR,
    BLACKSMITHING=SKILL_CATEGORY_LABOR,
    METALCRAFT=SKILL_CATEGORY_LABOR,
    METALCRAFTING=SKILL_CATEGORY_LABOR,
    GEM_CUTTING=SKILL_CATEGORY_LABOR,
    GEM_SETTING=SKILL_CATEGORY_LABOR,
    WOODCRAFT=SKILL_CATEGORY_LABOR,
    WOOD_CRAFTING=SKILL_CATEGORY_LABOR,
    STONECRAFT=SKILL_CATEGORY_LABOR,
    STONE_CRAFTING=SKILL_CATEGORY_LABOR,
    BONECARVE=SKILL_CATEGORY_LABOR,
    BONE_CARVING=SKILL_CATEGORY_LABOR,
    GLASSMAKER=SKILL_CATEGORY_LABOR,
    GLASSMAKING=SKILL_CATEGORY_LABOR,
    GLAZING=SKILL_CATEGORY_LABOR,
    WEAVING=SKILL_CATEGORY_LABOR,
    CLOTHESMAKING=SKILL_CATEGORY_LABOR,
    CLOTHIER=SKILL_CATEGORY_LABOR,
    LEATHERWORK=SKILL_CATEGORY_LABOR,
    LEATHERWORKING=SKILL_CATEGORY_LABOR,
    STRAND_EXTRACTION=SKILL_CATEGORY_LABOR,
    POTTERY=SKILL_CATEGORY_LABOR,
    PAPERMAKING=SKILL_CATEGORY_LABOR,
    PAPER_MAKING=SKILL_CATEGORY_LABOR,
    BOOKBINDING=SKILL_CATEGORY_LABOR,
    BOOK_BINDING=SKILL_CATEGORY_LABOR,
    MECHANICS=SKILL_CATEGORY_LABOR,
    SIEGECRAFT=SKILL_CATEGORY_LABOR,
    SIEGE_ENGINEERING=SKILL_CATEGORY_LABOR,
    SIEGEOPERATE=SKILL_CATEGORY_LABOR,
    SIEGE_OPERATING=SKILL_CATEGORY_LABOR,
    PUMP_OPERATE=SKILL_CATEGORY_LABOR,
    PUMP_OPERATING=SKILL_CATEGORY_LABOR,
    KNAPPING=SKILL_CATEGORY_LABOR,

    ARCHERY=SKILL_CATEGORY_COMBAT,
    ARCHER=SKILL_CATEGORY_COMBAT,
    ARMOR=SKILL_CATEGORY_COMBAT,
    ARMOR_USER=SKILL_CATEGORY_COMBAT,
    AXE=SKILL_CATEGORY_COMBAT,
    AXEMAN=SKILL_CATEGORY_COMBAT,
    BITE=SKILL_CATEGORY_COMBAT,
    BITER=SKILL_CATEGORY_COMBAT,
    BLOWGUN=SKILL_CATEGORY_COMBAT,
    BLOWGUNNER=SKILL_CATEGORY_COMBAT,
    BOW=SKILL_CATEGORY_COMBAT,
    BOWMAN=SKILL_CATEGORY_COMBAT,
    CROSSBOW=SKILL_CATEGORY_COMBAT,
    CROSSBOWMAN=SKILL_CATEGORY_COMBAT,
    DODGE=SKILL_CATEGORY_COMBAT,
    DODGER=SKILL_CATEGORY_COMBAT,
    FIGHTING=SKILL_CATEGORY_COMBAT,
    FIGHTER=SKILL_CATEGORY_COMBAT,
    HAMMER=SKILL_CATEGORY_COMBAT,
    HAMMERMAN=SKILL_CATEGORY_COMBAT,
    KICK=SKILL_CATEGORY_COMBAT,
    KICKER=SKILL_CATEGORY_COMBAT,
    KNIFE=SKILL_CATEGORY_COMBAT,
    KNIFE_USER=SKILL_CATEGORY_COMBAT,
    LASH=SKILL_CATEGORY_COMBAT,
    LASHER=SKILL_CATEGORY_COMBAT,
    MACE=SKILL_CATEGORY_COMBAT,
    MACEMAN=SKILL_CATEGORY_COMBAT,
    MILITARY_TACTICS=SKILL_CATEGORY_COMBAT,
    MISC_OBJECT=SKILL_CATEGORY_COMBAT,
    MISC_OBJECT_USER=SKILL_CATEGORY_COMBAT,
    MISC_WEAPON=SKILL_CATEGORY_COMBAT,
    PIKE=SKILL_CATEGORY_COMBAT,
    PIKEMAN=SKILL_CATEGORY_COMBAT,
    SHIELD=SKILL_CATEGORY_COMBAT,
    SHIELD_USER=SKILL_CATEGORY_COMBAT,
    SPEAR=SKILL_CATEGORY_COMBAT,
    SPEARMAN=SKILL_CATEGORY_COMBAT,
    STRIKE=SKILL_CATEGORY_COMBAT,
    STRIKER=SKILL_CATEGORY_COMBAT,
    SWORD=SKILL_CATEGORY_COMBAT,
    SWORDSMAN=SKILL_CATEGORY_COMBAT,
    THROW=SKILL_CATEGORY_COMBAT,
    THROWER=SKILL_CATEGORY_COMBAT,
    WRESTLE=SKILL_CATEGORY_COMBAT,
    WRESTLER=SKILL_CATEGORY_COMBAT,
    DISCIPLINE=SKILL_CATEGORY_COMBAT,

    APPRAISAL=SKILL_CATEGORY_SOCIAL,
    ORGANIZATION=SKILL_CATEGORY_SOCIAL,
    RECORD_KEEPING=SKILL_CATEGORY_SOCIAL,
    COMEDY=SKILL_CATEGORY_SOCIAL,
    CONVERSATION=SKILL_CATEGORY_SOCIAL,
    FLATTERY=SKILL_CATEGORY_SOCIAL,
    INTIMIDATION=SKILL_CATEGORY_SOCIAL,
    JUDGING_INTENT=SKILL_CATEGORY_SOCIAL,
    LYING=SKILL_CATEGORY_SOCIAL,
    NEGOTIATION=SKILL_CATEGORY_SOCIAL,
    PERSUASION=SKILL_CATEGORY_SOCIAL,
    LEADERSHIP=SKILL_CATEGORY_SOCIAL,
    TEACHING=SKILL_CATEGORY_SOCIAL,
    CONSOLE=SKILL_CATEGORY_SOCIAL,
    CONSOLING=SKILL_CATEGORY_SOCIAL,
    PACIFY=SKILL_CATEGORY_SOCIAL,
    PACIFICATION=SKILL_CATEGORY_SOCIAL,
    SCHEMING=SKILL_CATEGORY_SOCIAL,

    CRITICAL_THINKING=SKILL_CATEGORY_KNOWLEDGE,
    LOGIC=SKILL_CATEGORY_KNOWLEDGE,
    MATHEMATICS=SKILL_CATEGORY_KNOWLEDGE,
    ASTRONOMY=SKILL_CATEGORY_KNOWLEDGE,
    CHEMISTRY=SKILL_CATEGORY_KNOWLEDGE,
    GEOGRAPHY=SKILL_CATEGORY_KNOWLEDGE,
    OPTICS_ENGINEER=SKILL_CATEGORY_KNOWLEDGE,
    OPTICS_ENGINEERING=SKILL_CATEGORY_KNOWLEDGE,
    FLUID_ENGINEER=SKILL_CATEGORY_KNOWLEDGE,
    FLUID_ENGINEERING=SKILL_CATEGORY_KNOWLEDGE,
    WORDSMITH=SKILL_CATEGORY_KNOWLEDGE,
    WRITING=SKILL_CATEGORY_KNOWLEDGE,

    CLIMBING=SKILL_CATEGORY_OTHER,
    CONCENTRATION=SKILL_CATEGORY_OTHER,
    CRUTCH_WALK=SKILL_CATEGORY_OTHER,
    CRUTCH_WALKING=SKILL_CATEGORY_OTHER,
    OBSERVER=SKILL_CATEGORY_OTHER,
    READING=SKILL_CATEGORY_OTHER,
    RIDING=SKILL_CATEGORY_OTHER,
    STUDENT=SKILL_CATEGORY_OTHER,
    SWIMMING=SKILL_CATEGORY_OTHER,
    TRACKING=SKILL_CATEGORY_OTHER,
    DANCING=SKILL_CATEGORY_OTHER,
    SINGING=SKILL_CATEGORY_OTHER,
    MUSICIAN=SKILL_CATEGORY_OTHER,
    POET=SKILL_CATEGORY_OTHER,
    SPEAKER=SKILL_CATEGORY_OTHER,
    KEYBOARD_INSTRUMENT=SKILL_CATEGORY_OTHER,
    STRINGED_INSTRUMENT=SKILL_CATEGORY_OTHER,
    WIND_INSTRUMENT=SKILL_CATEGORY_OTHER,
    PERCUSSION_INSTRUMENT=SKILL_CATEGORY_OTHER,
    BALANCE=SKILL_CATEGORY_OTHER,
    COORDINATION=SKILL_CATEGORY_OTHER,
    DRUID=SKILL_CATEGORY_OTHER,
}

local function enum_keys(enum)
    local keys = {}
    for index, name in ipairs(enum) do
        if name ~= 'NONE' then
            table.insert(keys, {name=name, value=enum[name] or index})
        end
    end
    table.sort(keys, function(a, b) return a.value < b.value end)
    return keys
end

local function title_case_enum_name(name)
    local words = {}
    for word in name:gmatch('[^_]+') do
        local lower = word:lower()
        table.insert(words, lower:sub(1, 1):upper() .. lower:sub(2))
    end
    return table.concat(words, ' ')
end

local function make_descriptor(kind, key, label)
    return {
        id=kind .. ':' .. key,
        kind=kind,
        key=key,
        label=label,
    }
end

local function get_skill_category(key)
    return SKILL_CATEGORY_BY_KEY[key] or SKILL_CATEGORY_OTHER
end

local function sort_descriptors_by_label(descriptors)
    table.sort(descriptors, function(a, b)
        if a.label ~= b.label then
            return a.label < b.label
        end
        return a.id < b.id
    end)
    return descriptors
end

local function get_trait_descriptors()
    local descriptors = {}
    for _, trait in ipairs(enum_keys(df.personality_facet_type)) do
        table.insert(descriptors, make_descriptor(
            'trait',
            trait.name,
            title_case_enum_name(trait.name)))
    end
    return sort_descriptors_by_label(descriptors)
end

local function get_mental_attribute_descriptors()
    local descriptors = {}
    for _, attr in ipairs(enum_keys(df.mental_attribute_type)) do
        table.insert(descriptors, make_descriptor(
            'mental_attribute',
            attr.name,
            title_case_enum_name(attr.name)))
    end
    return sort_descriptors_by_label(descriptors)
end

local function get_physical_attribute_descriptors()
    local descriptors = {}
    for _, attr in ipairs(enum_keys(df.physical_attribute_type)) do
        table.insert(descriptors, make_descriptor(
            'physical_attribute',
            attr.name,
            title_case_enum_name(attr.name)))
    end
    return sort_descriptors_by_label(descriptors)
end

local function get_skill_descriptors()
    local descriptors = {}
    for _, skill in ipairs(enum_keys(df.job_skill)) do
        local descriptor = make_descriptor(
            'skill',
            skill.name,
            title_case_enum_name(skill.name))
        descriptor.category = get_skill_category(skill.name)
        table.insert(descriptors, descriptor)
    end
    return sort_descriptors_by_label(descriptors)
end

local function flatten_descriptors(descriptors)
    local flattened = {}
    for _, descriptor in ipairs(descriptors.skills or {}) do
        table.insert(flattened, descriptor)
    end
    for _, descriptor in ipairs(descriptors.physical_attributes or {}) do
        table.insert(flattened, descriptor)
    end
    for _, descriptor in ipairs(descriptors.mental_attributes or {}) do
        table.insert(flattened, descriptor)
    end
    for _, descriptor in ipairs(descriptors.traits or {}) do
        table.insert(flattened, descriptor)
    end
    return flattened
end

local function get_descriptor_by_id(descriptor_id)
    for _, descriptor in ipairs(flatten_descriptors(get_filter_descriptors())) do
        if descriptor.id == descriptor_id then
            return descriptor
        end
    end
    return nil
end

local function get_value(row, descriptor)
    if descriptor.kind == 'trait' then
        return row.traits and row.traits[descriptor.key]
    end
    if descriptor.kind == 'mental_attribute' then
        return row.mental_attributes and row.mental_attributes[descriptor.key]
    end
    if descriptor.kind == 'physical_attribute' then
        return row.physical_attributes and row.physical_attributes[descriptor.key]
    end
    if descriptor.kind == 'skill' then
        return row.skills and row.skills[descriptor.key] or 0
    end
    return nil
end

local function contains_text(haystack, needle)
    if not needle or needle == '' then
        return true
    end
    return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

local function copy_selected_descriptors(selected)
    local descriptors = {}
    for _, descriptor in ipairs(selected or {}) do
        table.insert(descriptors, descriptor)
    end
    return descriptors
end

local function make_selected_descriptor(descriptor, direction)
    local selected = {}
    for key, value in pairs(descriptor) do
        selected[key] = value
    end
    selected.direction = direction or FILTER_HIGH
    return selected
end

local function selected_ids_to_descriptors(selected_ids)
    local descriptors = {}
    for _, descriptor_id in ipairs(selected_ids or {}) do
        local descriptor = get_descriptor_by_id(descriptor_id)
        if descriptor then
            table.insert(descriptors, make_selected_descriptor(descriptor, FILTER_HIGH))
        end
    end
    return descriptors
end

local function selected_filters_to_descriptors(selected_filters)
    local descriptors = {}
    for _, selected_filter in ipairs(selected_filters or {}) do
        local descriptor = get_descriptor_by_id(selected_filter.id)
        if descriptor then
            table.insert(descriptors, make_selected_descriptor(
                descriptor,
                selected_filter.direction))
        end
    end
    return descriptors
end

local function get_priority_weight(priority_index)
    return 1 + FILTER_PRIORITY_WEIGHT_BONUS / math.max(priority_index or 1, 1)
end

local function score_weighted_match(value_score, priority_index)
    return (MATCHED_FILTER_SCORE + value_score) * get_priority_weight(priority_index)
end

local function score_row(row, selected_descriptors)
    local matched = {}
    local criteria = {}
    local score = 0
    local weighted_score = 0

    for index, descriptor in ipairs(selected_descriptors) do
        local value = get_value(row, descriptor)
        local evaluation = attributes.evaluate(descriptor.kind, descriptor.key, value, row.unit)
        local matches = attributes.matches_direction(evaluation, descriptor.direction)
        if evaluation then
            if matches then
                local value_score = attributes.score_direction(evaluation, descriptor.direction)
                score = score + value_score
                weighted_score = weighted_score +
                    score_weighted_match(value_score, index)
            end
            local criterion = {
                id=descriptor.id,
                kind=descriptor.kind,
                key=descriptor.key,
                label=descriptor.label,
                direction=descriptor.direction,
                value=value,
                baseline=evaluation.baseline,
                deviation=evaluation.deviation,
                tier_distance=evaluation.tier_distance,
                matched=matches,
            }
            table.insert(criteria, criterion)
            if matches then
                table.insert(matched, criterion)
            end
        end
    end

    return criteria, matched, #matched, score, weighted_score
end

local function make_result(row, selected_descriptors)
    local criteria, matched, matched_count, score, weighted_score = score_row(row, selected_descriptors)
    return {
        row=row,
        unit=row.unit,
        unit_id=row.unit_id,
        name=row.name,
        profession=row.profession,
        filter_criteria=criteria,
        matched_criteria=matched,
        matched_count=matched_count,
        criteria_count=#selected_descriptors,
        match_label=('%d/%d'):format(matched_count, #selected_descriptors),
        score=score,
        weighted_score=weighted_score,
    }
end

function get_filter_descriptors()
    return {
        skills=get_skill_descriptors(),
        traits=get_trait_descriptors(),
        mental_attributes=get_mental_attribute_descriptors(),
        physical_attributes=get_physical_attribute_descriptors(),
    }
end

function get_flat_filter_descriptors()
    return flatten_descriptors(get_filter_descriptors())
end

function apply(rows, opts)
    opts = opts or {}
    local query = opts.query or ''
    local selected_descriptors = opts.selected_descriptors and
        copy_selected_descriptors(opts.selected_descriptors) or
        opts.selected_filters and selected_filters_to_descriptors(opts.selected_filters) or
        selected_ids_to_descriptors(opts.selected_filter_ids)
    local results = {}

    for _, row in ipairs(rows or {}) do
        if contains_text(row.name or '', query) then
            table.insert(results, make_result(row, selected_descriptors))
        end
    end

    table.sort(results, function(a, b)
        if a.matched_count ~= b.matched_count then
            return a.matched_count > b.matched_count
        end
        if a.weighted_score ~= b.weighted_score then
            return a.weighted_score > b.weighted_score
        end
        if a.score ~= b.score then
            return a.score > b.score
        end
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.unit_id < b.unit_id
    end)

    return results
end
