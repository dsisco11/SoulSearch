--@ module=true

local filter_state = reqscript('internal/soulsearch/filter_state')
local filter_constants =
    reqscript('internal/soulsearch/filter_constants').FILTER_CONSTANTS
local window_settings = reqscript('internal/soulsearch/window_settings')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local sort_state = reqscript('internal/soulsearch/sort_state')

local RESULT_SORT_SPEC = sort_state.new_spec({'name', 'profession', 'unit_id'})
local STATS_SORT_SPEC = sort_state.new_spec({'label', 'value'}, {value=true})

---@param value any
---@return table
local function copy_table(value)
    local copy = {}
    if type(value) ~= 'table' then return copy end
    for key, child in pairs(value) do
        copy[key] = type(child) == 'table' and copy_table(child) or child
    end
    return copy
end

---@param value any
---@param fallback integer
---@return integer
local function to_integer(value, fallback)
    return type(value) == 'number' and math.floor(value) or fallback
end

---@param value any
---@param fallback number
---@return number
local function to_alignment(value, fallback)
    if type(value) ~= 'number' then return fallback end
    return math.max(0, math.min(1, value))
end

---@param frame any
---@param screen_width integer
---@param screen_height integer
---@return table
local function normalize_frame(frame, screen_width, screen_height)
    frame = type(frame) == 'table' and frame or ui_layout.WINDOW_FRAME
    local defaults = ui_layout.WINDOW_FRAME
    local minimum = ui_layout.WINDOW_RESIZE_MIN
    screen_width = math.max(1, to_integer(screen_width, defaults.w))
    screen_height = math.max(1, to_integer(screen_height, defaults.h))
    local min_width = math.min(screen_width, minimum.w)
    local min_height = math.min(screen_height, minimum.h)
    local width = math.max(min_width,
        math.min(screen_width, to_integer(frame.w, defaults.w)))
    local height = math.max(min_height,
        math.min(screen_height, to_integer(frame.h, defaults.h)))
    local left = frame.l
    if type(left) ~= 'number' then
        left = math.floor((screen_width - width) *
            to_alignment(frame.xalign, defaults.xalign or 0))
    end
    local top = frame.t
    if type(top) ~= 'number' then
        top = math.floor((screen_height - height) *
            to_alignment(frame.yalign, defaults.yalign or 0))
    end
    return {
        l=math.max(0, math.min(screen_width - width, math.floor(left))),
        t=math.max(0, math.min(screen_height - height, math.floor(top))),
        w=width,
        h=height,
    }
end

---@param sort any
---@param spec SoulSearchSortSpec
---@return table
local function normalize_sort(sort, spec)
    return sort_state.normalize(sort, spec)
end

local UNIT_SCOPE = filter_constants.unit_scope
local LEGACY_ALL_ACTIVE = 'all_active'

local function get_scope_filter_id(scope)
    if scope == LEGACY_ALL_ACTIVE then return nil end
    for _, key in ipairs{
        UNIT_SCOPE.CITIZENS, UNIT_SCOPE.FORT_RESIDENTS,
        UNIT_SCOPE.LIVESTOCK, UNIT_SCOPE.PETS, UNIT_SCOPE.VISITORS,
        UNIT_SCOPE.WILDLIFE,
    } do
        if scope == key then return UNIT_SCOPE.id_prefix .. key end
    end
end

local function has_unit_scope(filters)
    for _, filter in ipairs(filters or {}) do
        if type(filter) == 'table' and type(filter.id) == 'string' and
                filter.id:sub(1, #UNIT_SCOPE.id_prefix) == UNIT_SCOPE.id_prefix then
            return true
        end
    end
    return false
end

local function without_unit_scopes(filters)
    local result = {}
    for _, filter in ipairs(filters or {}) do
        if type(filter) == 'table' and type(filter.id) == 'string' and
                filter.id:sub(1, #UNIT_SCOPE.id_prefix) ~= UNIT_SCOPE.id_prefix then
            table.insert(result, filter)
        end
    end
    return result
end

---@param options table|nil
---@param screen_width integer
---@param screen_height integer
---@return table config
function resolve(options, screen_width, screen_height)
    options = type(options) == 'table' and copy_table(options) or {}
    local settings_id = window_settings.normalize_settings_id(options.settings_id)
    local saved = window_settings.load(settings_id) or {}
    local explicit = {}

    local filter_source = options.filters ~= nil and options.filters or saved.filters
    if filter_source == nil and settings_id == 'default' then
        filter_source = {{
            id=filter_constants.default_race_filter_id,
            direction=filter_constants.direction.HIGH,
        }}
    end
    local legacy_scope = options.unit_scope
    local scope_filter_id = get_scope_filter_id(legacy_scope)
    local explicit_scope = options.filters ~= nil and has_unit_scope(options.filters)
    if legacy_scope ~= nil and (legacy_scope == LEGACY_ALL_ACTIVE or scope_filter_id) and
            not explicit_scope then
        filter_source = without_unit_scopes(filter_source)
        if scope_filter_id then table.insert(filter_source, {
            id=scope_filter_id, direction=filter_constants.direction.HIGH}) end
    end
    local filters = filter_state.get_filters(filter_state.new(filter_source))
    if options.filters ~= nil then explicit.filters = filters end

    local result_sort_source = options.result_sort ~= nil and options.result_sort or
        saved.result_sort
    local result_sort = normalize_sort(result_sort_source, RESULT_SORT_SPEC)
    if options.result_sort ~= nil then explicit.result_sort = result_sort end

    local stats_sort_source = options.stats_sort ~= nil and options.stats_sort or
        saved.stats_sort
    local normalized_stats_sort = normalize_sort(stats_sort_source, STATS_SORT_SPEC)
    if options.stats_sort ~= nil then explicit.stats_sort = normalized_stats_sort end

    local frame_source = options.frame ~= nil and options.frame or saved.frame
    local frame = normalize_frame(frame_source, screen_width, screen_height)
    if options.frame ~= nil then explicit.frame = frame end

    return {
        settings_id=settings_id,
        filters=filters,
        result_sort=result_sort,
        stats_sort=normalized_stats_sort,
        frame=frame,
        explicit=explicit,
    }
end
