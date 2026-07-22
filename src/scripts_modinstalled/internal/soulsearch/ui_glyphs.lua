--@ module=true

CP437_ARROW_RIGHT = string.char(16) -- ►
CP437_ARROW_LEFT = string.char(17) -- ◄
CP437_ARROW_UP = string.char(24) -- ↑
CP437_ARROW_DOWN = string.char(25) -- ↓
CP437_TRIANGLE_UP = string.char(30) -- ▲
CP437_TRIANGLE_DOWN = string.char(31) -- ▼
CP437_VERTICAL_LINE = string.char(179) -- │
CP437_HORIZONTAL_LINE = string.char(196) -- ─

---@param name string
---@return string|nil
function get_glyph(name)
    return ({
        arrow_right=CP437_ARROW_RIGHT,
        arrow_left=CP437_ARROW_LEFT,
        arrow_up=CP437_ARROW_UP,
        arrow_down=CP437_ARROW_DOWN,
        triangle_up=CP437_TRIANGLE_UP,
        triangle_down=CP437_TRIANGLE_DOWN,
        vertical_line=CP437_VERTICAL_LINE,
        horizontal_line=CP437_HORIZONTAL_LINE,
    })[name]
end
