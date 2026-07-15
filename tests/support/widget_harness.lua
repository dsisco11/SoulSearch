local M = {}

local BASE_METHODS = {
    onInput=function() return false end,
    onDragBegin=function() end,
    onRenderBody=function() end,
    setFocus=function(self, value) self.focused = value end,
    setText=function(self, value) self.text = value end,
    setChoices=function(self, choices, selected)
        self.choices, self.selected = choices, selected
    end,
    getSelected=function(self)
        return self.selected, self.choices and self.choices[self.selected]
    end,
    setSelected=function(self, index) self.selected = index end,
    moveCursor=function(self, delta) self.cursor_delta = delta end,
    getMousePos=function(self) return self.mouse_x, self.mouse_y end,
    getIdxUnderMouse=function(self) return self.mouse_index end,
    getMouseFramePos=function(self) return self.frame_mouse_x, self.frame_mouse_y end,
    getTextHeight=function(self)
        local count = 1
        for _ in tostring(self.text or ''):gmatch('\n') do count = count + 1 end
        return count
    end,
    setOption=function(self, value) self.option = value end,
}

local function addviews(self, views)
    self.subviews = self.subviews or {}
    for _, view in ipairs(views) do
        table.insert(self.subviews, view)
        if view.view_id then self.subviews[view.view_id] = view end
    end
end

local function constructor(kind, methods)
    local prototype = {widget_kind=kind}
    for key, value in pairs(BASE_METHODS) do prototype[key] = value end
    for key, value in pairs(methods or {}) do prototype[key] = value end
    return setmetatable(prototype, {__call=function(self, info)
        info = info or {}
        info.widget_kind = self.widget_kind
        for key, value in pairs(self) do
            if type(value) == 'function' and info[key] == nil then info[key] = value end
        end
        return info
    end})
end

---Returns a deliberately small DFHack widget model for UI unit tests.
---@param overrides table<string, table>|nil
---@return table widgets
function M.widgets(overrides)
    local widgets = {}
    local names = {'Window', 'Panel', 'Widget', 'Divider', 'Label', 'TextButton', 'EditField', 'List',
        'HotkeyLabel', 'CycleHotkeyLabel'}
    for _, name in ipairs(names) do
        local methods = overrides and overrides[name] or nil
        if name == 'Window' or name == 'Panel' then
            methods = methods or {}
            if not methods.addviews then
                local copied = {}
                for key, value in pairs(methods) do copied[key] = value end
                copied.addviews = addviews
                methods = copied
            end
        end
        widgets[name] = constructor(name, methods)
    end
    return widgets
end

---Creates a defclass-compatible constructor with explicit superclass dispatch.
---@param _ string
---@param parent table
---@return table
function M.defclass(_, parent)
    local class = {super=parent}
    function class.ATTRS(attrs) class.attrs = attrs end
    return setmetatable(class, {
        __index=parent,
        __call=function(_, info)
            local instance = parent(info or {})
            -- Widget constructors expose their methods directly on plain leaf
            -- instances. Class instances must instead resolve them through the
            -- class table so an override (for example `onInput`) wins.
            for key, value in pairs(parent) do
                if type(value) == 'function' and instance[key] == value then
                    instance[key] = nil
                end
            end
            setmetatable(instance, {__index=class})
            if class.init then class.init(instance, info or {}) end
            return instance
        end,
    })
end

function M.attach_recursive(view, parent, root_subviews)
    view.parent_view = parent
    if view.visible == nil then view.visible = true end
    view.subviews = view.subviews or {}
    for key, value in pairs(BASE_METHODS) do
        if view[key] == nil then view[key] = value end
    end
    for _, child in ipairs(view.subviews) do
        if child.view_id then
            view.subviews[child.view_id] = child
            root_subviews[child.view_id] = child
        end
        M.attach_recursive(child, view, root_subviews)
    end
end

return M
