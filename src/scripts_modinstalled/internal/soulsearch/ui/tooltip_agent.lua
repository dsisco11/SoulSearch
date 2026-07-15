--@ module=true

local pointer = reqscript('internal/soulsearch/ui/pointer_dispatcher')

TooltipAgent = {}
TooltipAgent.__index = TooltipAgent

---@param root gui.View
---@param renderer SoulSearchTooltip
---@return TooltipAgent
function TooltipAgent.new(root, renderer)
    assert(root, 'TooltipAgent requires a pointer root.')
    assert(renderer, 'TooltipAgent requires a tooltip renderer.')
    return setmetatable({
        pointer_context=pointer.PointerContext.new(root),
        renderer=renderer,
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

---@return table pointer result
function TooltipAgent:update()
    -- One read feeds both hit testing and renderer placement for this root.
    local x, y = dfhack.screen.getMousePos()
    local result = pointer.PointerDispatcher.sample(self.pointer_context, x, y)
    local text = result.kind == 'target' and get_tooltip(result.target) or nil
    self.renderer:set_tooltip(text, x, y)
    return result
end

return {TooltipAgent=TooltipAgent}
