--@ module=true

-- Generic pointer targeting deliberately has no tooltip dependency. Tooltip
-- presentation consumes PointerContext in Phase 3.

local POINTER_POLICY = {
    TARGET='target',
    PASS='pass',
    BLOCK='block',
    NONE='none',
}
local reqscript_fn = rawget(_G, 'reqscript')

if type(reqscript_fn) == 'function' then
    local ok, pointer = pcall(reqscript_fn, 'dwarfui/pointer')
    if ok and type(pointer) == 'table' and type(pointer.PointerPolicy) == 'table' then
        POINTER_POLICY.TARGET = pointer.PointerPolicy.TARGET
        POINTER_POLICY.PASS = pointer.PointerPolicy.PASS
        POINTER_POLICY.BLOCK = pointer.PointerPolicy.BLOCK
        POINTER_POLICY.NONE = pointer.PointerPolicy.NONE
    end
end

local VALID_POLICIES = {
    [POINTER_POLICY.TARGET]=true,
    [POINTER_POLICY.PASS]=true,
    [POINTER_POLICY.BLOCK]=true,
    [POINTER_POLICY.NONE]=true,
    target=true,
    pass=true,
    block=true,
    none=true,
}

local function getval(value)
    if type(value) == 'function' then return value() end
    return value
end

local function is_eligible(view)
    return view and getval(view.visible) and getval(view.active)
end

local function body_contains(view, x, y)
    local body = view.frame_body
    return body and body:inClipGlobalXY(x, y)
end

local function frame_contains(view, x, y)
    local frame = view.frame_rect
    local parent = view.frame_parent_rect
    if frame and parent then
        local x1 = frame.x1 + parent.x1
        local y1 = frame.y1 + parent.y1
        return x >= x1 and x <= x1 + frame.width - 1 and
            y >= y1 and y <= y1 + frame.height - 1
    end
    return body_contains(view, x, y)
end

local function miss()
    return {kind='miss'}
end

local function blocked(view)
    return {kind='blocked', blocker=view}
end

local function targeted(view, x, y)
    local local_x, local_y = view.frame_body:localXY(x, y)
    return {kind='target', target=view, x=local_x, y=local_y}
end

local function resolve_view(view, x, y)
    if not is_eligible(view) then return miss() end
    local inside_body = body_contains(view, x, y)
    local inside_frame = frame_contains(view, x, y)
    if not inside_body and not inside_frame then return miss() end

    local policy = view.pointer_policy or POINTER_POLICY.TARGET
    assert(VALID_POLICIES[policy],
        'invalid pointer_policy ' .. tostring(policy) ..
        '; expected target, pass, block, none, or a DwarfUI PointerPolicy member.')
    if policy == 'none' or policy == POINTER_POLICY.NONE then return miss() end

    -- A target is a terminal control. This keeps a composite control (for
    -- example, TextButton or List) responsible for its own tooltip instead
    -- of letting an undecorated implementation child steal the target.
    if (policy == 'target' or policy == POINTER_POLICY.TARGET) and inside_body then
        return targeted(view, x, y)
    end

    if inside_body then
        local subviews = view.subviews or {}
        for index = #subviews, 1, -1 do
            local result = resolve_view(subviews[index], x, y)
            if result.kind ~= 'miss' then return result end
        end
    end

    if (policy == 'block' or policy == POINTER_POLICY.BLOCK) and inside_frame then
        return blocked(view)
    end
    return miss()
end

PointerContext = {}
PointerContext.__index = PointerContext

---@param root gui.View
---@return PointerContext
function PointerContext.new(root)
    assert(root, 'PointerContext requires a root view.')
    return setmetatable({root=root, target=nil, result=miss()}, PointerContext)
end

PointerDispatcher = {}

---@param root gui.View
---@param x integer
---@param y integer
---@return table
function PointerDispatcher.resolve(root, x, y)
    if not is_eligible(root) or not body_contains(root, x, y) then return miss() end
    for index = #(root.subviews or {}), 1, -1 do
        local result = resolve_view(root.subviews[index], x, y)
        if result.kind ~= 'miss' then return result end
    end
    return miss()
end

---@param context PointerContext
---@param x integer
---@param y integer
---@return table
function PointerDispatcher.sample(context, x, y)
    assert(context and context.root, 'PointerDispatcher.sample requires a PointerContext.')
    if x == nil or y == nil then
        x, y = dfhack.screen.getMousePos()
    end
    if x == nil or y == nil then
        x, y = nil, nil
    end
    local result = x and y and PointerDispatcher.resolve(context.root, x, y) or miss()
    local previous = context.target
    local target = result.kind == 'target' and result.target or nil
    if previous ~= target then
        if previous and previous.on_pointer_leave then
            previous.on_pointer_leave(previous)
        end
        if target and target.on_pointer_enter then
            target.on_pointer_enter(target, result.x, result.y)
        end
    end
    if target and target.on_pointer_update then
        target.on_pointer_update(target, result.x, result.y)
    end
    context.target = target
    context.result = result
    return result
end

return {PointerContext=PointerContext, PointerDispatcher=PointerDispatcher}
