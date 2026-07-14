--@ module=true

local filter_state = reqscript('internal/soulsearch/filter_state')
local unit_scope_provider = reqscript('internal/soulsearch/unit_scope_provider')
local window_settings = reqscript('internal/soulsearch/window_settings')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local stats_sort = reqscript('internal/soulsearch/stats_sort')

local RESULT_SORT_KEYS = {name=true, profession=true, unit_id=true}

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
---@param valid_keys table<string, boolean>
---@param kind 'result'|'stats'
---@return table
local function normalize_sort(sort, valid_keys, kind)
    if type(sort) ~= 'table' or not valid_keys[sort.key] or
            sort.phase ~= 1 and sort.phase ~= 2 then
        return {key=nil, reverse=false, phase=0}
    end
    local reverse
    if kind == 'result' then
        reverse = sort.phase == 2
    elseif sort.phase == 1 then
        reverse = sort.key == 'value'
    else
        reverse = sort.key ~= 'value'
    end
    return {key=sort.key, reverse=reverse, phase=sort.phase}
end

---@param scope any
---@return string
local function normalize_scope(scope)
    if type(scope) == 'string' and pcall(unit_scope_provider.new, scope) then
        return scope
    end
    return unit_scope_provider.get_default_scope()
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
    local filters = filter_state.get_filters(filter_state.new(filter_source))
    if options.filters ~= nil then explicit.filters = filters end

    local scope_source = options.unit_scope ~= nil and options.unit_scope or
        saved.unit_scope
    local unit_scope = normalize_scope(scope_source)
    if options.unit_scope ~= nil then explicit.unit_scope = unit_scope end

    local result_sort_source = options.result_sort ~= nil and options.result_sort or
        saved.result_sort
    local result_sort = normalize_sort(
        result_sort_source, RESULT_SORT_KEYS, 'result')
    if options.result_sort ~= nil then explicit.result_sort = result_sort end

    local stats_sort_source = options.stats_sort ~= nil and options.stats_sort or
        saved.stats_sort
    local normalized_stats_sort = stats_sort.normalize(stats_sort_source)
    if options.stats_sort ~= nil then explicit.stats_sort = normalized_stats_sort end

    local frame_source = options.frame ~= nil and options.frame or saved.frame
    local frame = normalize_frame(frame_source, screen_width, screen_height)
    if options.frame ~= nil then explicit.frame = frame end

    return {
        settings_id=settings_id,
        filters=filters,
        unit_scope=unit_scope,
        result_sort=result_sort,
        stats_sort=normalized_stats_sort,
        frame=frame,
        explicit=explicit,
    }
end
