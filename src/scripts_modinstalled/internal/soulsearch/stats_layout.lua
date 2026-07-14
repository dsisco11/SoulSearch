--@ module=true

-- Geometry owned by the reusable Stats panel. These coordinates are relative
-- to the panel, never to the main SoulSearch window.
LABEL_WIDTH = 24
VALUE_COLUMN_X = 27
VALUE_HEADER_WIDTH = 7
CONTENT_TOP = 2
MIN_CONTENT_WIDTH = VALUE_COLUMN_X + VALUE_HEADER_WIDTH
MIN_CONTENT_HEIGHT = 4 -- header, two column-header rows, and one body row

---@param source table
---@return table
function copy_frame(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

---@param x integer|nil
---@param y integer|nil
---@return string|nil
function get_header_column(x, y)
    if not x or y ~= 0 then return nil end
    if x >= 0 and x < LABEL_WIDTH then return 'label' end
    if x >= VALUE_COLUMN_X and x < VALUE_COLUMN_X + VALUE_HEADER_WIDTH then
        return 'value'
    end
    return nil
end

---@param x integer|nil
---@param y integer|nil
---@return boolean
function is_value_cell(x, y)
    return x and y and y >= 0 and x >= VALUE_COLUMN_X and
        x < VALUE_COLUMN_X + VALUE_HEADER_WIDTH
end

---@param x integer|nil
---@param y integer|nil
---@return boolean
function is_label_cell(x, y)
    return x and y and y >= 0 and x >= 2 and x < VALUE_COLUMN_X
end

---@param content_height integer|nil
---@param header_height integer|nil
---@param columns_height integer|nil
---@return table
function get_content_frames(content_height, header_height, columns_height)
    local height = math.max(MIN_CONTENT_HEIGHT, content_height or MIN_CONTENT_HEIGHT)
    local available = height - CONTENT_TOP
    header_height = math.min(header_height or 1, math.max(1, available - 3))
    columns_height = math.min(columns_height or 2,
        math.max(1, available - header_height - 1))
    local columns_top = CONTENT_TOP + header_height
    return {
        header={l=0, t=CONTENT_TOP, r=0, h=header_height},
        columns={l=0, t=columns_top, r=0, h=columns_height},
        body={l=0, t=columns_top + columns_height, r=0, b=0},
    }
end
