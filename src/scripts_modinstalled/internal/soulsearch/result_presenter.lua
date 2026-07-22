--@ module=true

local ui_format = reqscript('internal/soulsearch/ui_format')

---@param results SoulSearchResult[]
---@param sort_key string|nil
---@param sort_reverse boolean
---@return {choices: table[], title: string, underline: string, columns: string}
function present(results, sort_key, sort_reverse)
    local choices = {}
    for _, result in ipairs(results) do
        table.insert(choices, {text=ui_format.format_result_choice(result),
            result=result, search_key=result.name})
    end
    local title = ('Results (%d)'):format(#choices)
    return {choices=choices, title=title,
        underline=ui_format.get_title_underline(title),
        columns=ui_format.format_result_columns(sort_key, sort_reverse)}
end
