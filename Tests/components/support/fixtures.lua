local M = {}

---@param value any
---@param fallback any
---@return any
local function default(value, fallback)
    if value == nil then return fallback end
    return value
end

---@param source table|nil
---@return table
local function copy_map(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

---@param source table[]|nil
---@return table[]
local function copy_sequence(source)
    local copy = {}
    for index, value in ipairs(source or {}) do copy[index] = value end
    return copy
end

---Creates a deterministic stat descriptor.
---@param options table|nil
---@return table descriptor
function M.descriptor(options)
    options = options or {}
    local key = options.key or 'STRENGTH'
    local kind = options.kind or 'physical'
    return {
        id=options.id or (kind .. ':' .. key),
        kind=kind,
        key=key,
        label=options.label or 'Strength',
        behavior=options.behavior or 'high_low',
        category=options.category,
    }
end

---Creates a deterministic picker choice for a filter descriptor.
---@param options table|nil
---@return table choice
function M.filter_choice(options)
    options = options or {}
    local descriptor = options.descriptor or M.descriptor(options)
    return {
        text=options.text or descriptor.label,
        descriptor=descriptor,
        selected=default(options.selected, false),
        search_key=options.search_key or descriptor.label,
    }
end

---Creates a deterministic custom, default, or role preset choice.
---@param options table|nil
---@return table choice
function M.preset_choice(options)
    options = options or {}
    local kind = options.kind or 'custom'
    local choice = {
        text=options.text or 'Mining team',
        search_key=options.search_key or 'Mining team',
    }
    if kind == 'role' then
        choice.role_id = options.role_id or 'miner'
    elseif kind == 'default' then
        choice.default_id = options.default_id or 'strong'
    else
        choice.name = options.name or 'Mining team'
    end
    return choice
end

---Creates a deterministic resident row with isolated stat maps.
---@param options table|nil
---@return SoulSearchResidentRow row
function M.resident_row(options)
    options = options or {}
    local unit = options.unit or {id=default(options.unit_id, 101)}
    local unit_id = default(options.unit_id, unit.id)
    return {
        unit=unit,
        unit_id=unit_id,
        name=options.name or 'Urist McFixture',
        profession=options.profession or 'Miner',
        traits=copy_map(options.traits or {PATIENCE=62}),
        mental_attributes=copy_map(options.mental_attributes or {FOCUS=1150}),
        physical_attributes=copy_map(options.physical_attributes or {STRENGTH=1250}),
        skills=copy_map(options.skills or {MINING=8}),
    }
end

---Creates a deterministic matched-filter criterion.
---@param options table|nil
---@return SoulSearchFilterCriterion criterion
function M.criterion(options)
    options = options or {}
    return {
        id=options.id or 'physical:STRENGTH',
        kind=options.kind or 'physical',
        key=options.key or 'STRENGTH',
        label=options.label or 'Strength',
        direction=options.direction or 'high',
        value=default(options.value, 1250),
        baseline=default(options.baseline, 1000),
        deviation=default(options.deviation, 250),
        tier_distance=default(options.tier_distance, 1),
        matched=default(options.matched, true),
    }
end

---Creates a deterministic search result with an isolated criterion sequence.
---@param options table|nil
---@return SoulSearchResult result
function M.result(options)
    options = options or {}
    local row = options.row or M.resident_row(options)
    local criteria = options.filter_criteria or {M.criterion()}
    return {
        row=row,
        unit=options.unit or row.unit,
        unit_id=default(options.unit_id, row.unit_id),
        name=options.name or row.name,
        profession=options.profession or row.profession,
        filter_criteria=copy_sequence(criteria),
        matched_count=default(options.matched_count, #criteria),
        score=default(options.score, 1),
        weighted_score=default(options.weighted_score, 1),
    }
end

---Creates a deterministic stats subject from a resident row.
---@param options table|nil
---@return SoulSearchStatsSubject subject
function M.stats_subject(options)
    options = options or {}
    local row = options.row or M.resident_row(options)
    return {
        unit=options.unit or row.unit,
        unit_id=default(options.unit_id, row.unit_id),
        row=row,
        name=options.name or row.name,
        profession=options.profession or row.profession,
        filter_criteria=copy_sequence(options.filter_criteria or {M.criterion()}),
    }
end

return M
