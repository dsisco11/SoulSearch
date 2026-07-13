--@ module=true

local CASCADE_OFFSET = 2

---@type table[]
local screens = {}

---@param frame table
---@return table
local function copy_frame(frame)
    return {l=frame.l, t=frame.t, w=frame.w, h=frame.h}
end

---@param first table
---@param second table
---@return boolean
local function overlaps(first, second)
    return first.l < second.l + second.w and
        second.l < first.l + first.w and
        first.t < second.t + second.h and
        second.t < first.t + first.h
end

---@param screen table
---@return boolean added
function add(screen)
    assert(type(screen) == 'table', 'SoulSearch screen must be a table.')
    for _, active in ipairs(screens) do
        if active == screen then return false end
    end
    table.insert(screens, screen)
    return true
end

---@param screen table
---@return boolean removed
function remove(screen)
    for index, active in ipairs(screens) do
        if active == screen then
            table.remove(screens, index)
            return true
        end
    end
    return false
end

---@param screen table
---@return boolean
function contains(screen)
    for _, active in ipairs(screens) do
        if active == screen then return true end
    end
    return false
end

---@return integer
function count()
    return #screens
end

---@return table[]
function snapshot()
    local copy = {}
    for _, screen in ipairs(screens) do table.insert(copy, screen) end
    return copy
end

---@return table[]
function get_frames()
    local frames = {}
    for _, screen in ipairs(screens) do
        local frame = screen.window and screen.window.frame
        if type(frame) == 'table' and frame.l and frame.t and frame.w and frame.h then
            table.insert(frames, copy_frame(frame))
        end
    end
    return frames
end

---@param frame table
---@param screen_width integer
---@param screen_height integer
---@return table
function place_frame(frame, screen_width, screen_height)
    local placed = copy_frame(frame)
    local frames = get_frames()
    local collides = false
    for _, active in ipairs(frames) do
        if overlaps(placed, active) then collides = true break end
    end
    if not collides then return placed end

    local max_left = math.max(0, screen_width - placed.w)
    local max_top = math.max(0, screen_height - placed.h)
    for attempt = 1, #frames + 1 do
        local left = max_left == 0 and 0 or
            (frame.l + attempt * CASCADE_OFFSET) % (max_left + 1)
        local top = max_top == 0 and 0 or
            (frame.t + attempt * CASCADE_OFFSET) % (max_top + 1)
        local duplicate_origin = false
        for _, active in ipairs(frames) do
            if active.l == left and active.t == top then
                duplicate_origin = true
                break
            end
        end
        if not duplicate_origin then
            placed.l = left
            placed.t = top
            return placed
        end
    end
    return placed
end

---Clears registry state for isolated pure-Lua tests.
function clear()
    screens = {}
end
