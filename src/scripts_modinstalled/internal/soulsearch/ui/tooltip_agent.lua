--@ module=true

local pointer = reqscript('internal/soulsearch/ui/pointer_dispatcher')

local MAX_DEBUG_MESSAGES = 500
local debug_messages = {}

local function retain_debug_message(message)
    if #debug_messages >= MAX_DEBUG_MESSAGES then table.remove(debug_messages, 1) end
    table.insert(debug_messages, message)
end

function get_debug_messages()
    local copy = {}
    for index, message in ipairs(debug_messages) do copy[index] = message end
    return copy
end

function clear_debug_messages()
    debug_messages = {}
end

TooltipAgent = {}
TooltipAgent.__index = TooltipAgent

---@param root gui.View
---@param renderer SoulSearchTooltip
---@param debug_logger? fun(message: string)
---@return TooltipAgent
function TooltipAgent.new(root, renderer, debug_logger)
    assert(root, 'TooltipAgent requires a pointer root.')
    assert(renderer, 'TooltipAgent requires a tooltip renderer.')
    return setmetatable({
        pointer_context=pointer.PointerContext.new(root),
        renderer=renderer,
        debug_logger=debug_logger,
        debug_sample=0,
        debug_signature=nil,
    }, TooltipAgent)
end

local function get_tooltip(target)
    if not target then return nil end
    local value = target.tooltip
    if value == nil or value == '' then return nil end
    assert(type(value) == 'string',
        'tooltip must be a string, nil, or an empty string; got ' .. type(value) .. '.')
    return value
end

local function rect_text(rect)
    if not rect then return '-' end
    local x2 = rect.x2 or (rect.x1 and rect.width and rect.x1 + rect.width - 1)
    local y2 = rect.y2 or (rect.y1 and rect.height and rect.y1 + rect.height - 1)
    return ('%s,%s..%s,%s clip=%s,%s..%s,%s'):format(
        tostring(rect.x1), tostring(rect.y1), tostring(x2), tostring(y2),
        tostring(rect.clip_x1), tostring(rect.clip_y1),
        tostring(rect.clip_x2), tostring(rect.clip_y2))
end

local function view_identity(view)
    if not view then return '-' end
    local name = view.view_id or view.widget_kind or view.frame_title or 'view'
    return tostring(name) .. '@' .. tostring(view)
end

local function find_path(view, wanted, path)
    if not view or not wanted then return nil end
    path = path or {'root'}
    if view == wanted then return table.concat(path, '/') end
    for index, child in ipairs(view.subviews or {}) do
        local label = child.view_id or child.widget_kind or tostring(index)
        local child_path = {}
        for i, part in ipairs(path) do child_path[i] = part end
        child_path[#child_path + 1] = tostring(label) .. '[' .. index .. ']'
        local result = find_path(child, wanted, child_path)
        if result then return result end
    end
end

local function emit_debug(agent, x, y, result, text, previous)
    if not agent.debug_logger then return end
    agent.debug_sample = agent.debug_sample + 1
    local hit = result.target or result.blocker
    local root = agent.pointer_context.root
    local identity = view_identity(hit)
    local path = find_path(root, hit) or '-'
    local body = rect_text(hit and hit.frame_body)
    local signature = table.concat({
        tostring(x), tostring(y), result.kind, identity, path, body,
        tostring(text), rect_text(root.frame_body),
    }, '|')
    if signature == agent.debug_signature then return end
    agent.debug_signature = signature
    local message = ('[SoulSearch tooltip resolver] sample=%d mouse=%s,%s ' ..
        'result=%s previous=%s hit=%s path=%s body={%s} tooltip=%q ' ..
        'root_body={%s}'):format(
        agent.debug_sample, tostring(x), tostring(y), result.kind,
        view_identity(previous), identity, path, body, text or '',
        rect_text(root.frame_body))
    retain_debug_message(message)
    agent.debug_logger(message)
end

---@return table pointer result
function TooltipAgent:update()
    -- One read feeds both hit testing and renderer placement for this root.
    local x, y = dfhack.screen.getMousePos()
    local previous = self.pointer_context.target
    local result = pointer.PointerDispatcher.sample(self.pointer_context, x, y)
    local text = result.kind == 'target' and get_tooltip(result.target) or nil
    emit_debug(self, x, y, result, text, previous)
    self.renderer:set_tooltip(
        text, x, y, self.pointer_context.root.frame_parent_rect)
    return result
end

return {
    TooltipAgent=TooltipAgent,
    get_debug_messages=get_debug_messages,
    clear_debug_messages=clear_debug_messages,
}
