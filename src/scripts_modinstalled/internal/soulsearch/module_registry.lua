--@ module=true

---@class SoulSearchModuleSpec
---@field name string
---@field contract string

---Dependencies precede consumers so an explicit environment clear/reload
---cannot leave local reqscript references pointing at mixed generations.
---@type SoulSearchModuleSpec[]
MODULES = {
    {name='internal/soulsearch/df_enums', contract='entries'},
    {name='internal/soulsearch/skill_categories', contract='get_category'},
    {name='internal/soulsearch/text_match', contract='contains'},
    {name='internal/soulsearch/attribute_descriptions', contract='get_tooltip'},
    {name='internal/soulsearch/ui_glyphs', contract='get_glyph'},
    {name='internal/soulsearch/ui_layout', contract='get_frame'},
    {name='internal/soulsearch/attributes', contract='evaluate'},
    {name='internal/soulsearch/race_catalog', contract='get_descriptors'},
    {name='internal/soulsearch/descriptors', contract='get_catalog'},
    {name='internal/soulsearch/candidate_provider', contract='new'},
    {name='internal/soulsearch/unit_scope_provider', contract='new'},
    {name='internal/soulsearch/filter_state', contract='get_filters'},
    {name='internal/soulsearch/race_filter_provider', contract='new'},
    {name='internal/soulsearch/filter_defaults', contract='get_all'},
    {name='internal/soulsearch/role_presets', contract='get_all'},
    {name='internal/soulsearch/filter_presets', contract='list'},
    {name='internal/soulsearch/search', contract='apply'},
    {name='internal/soulsearch/ui_format', contract='format_result_choice'},
    {name='internal/soulsearch/stats_presenter', contract='build_records'},
    {name='internal/soulsearch/ui_components', contract='create_filter_panel'},
    {name='internal/soulsearch/ui_refresh', contract='apply'},
    {name='internal/soulsearch/residents', contract='collect_from_provider'},
    {name='internal/soulsearch/lifecycle', contract='prepare_for_world'},
    {name='internal/soulsearch/ui', contract='open'},
}

local REGISTRY_SCRIPT = 'internal/soulsearch/module_registry'

---@param loader fun(name: string): table
---@return table<string, table>
function load_all(loader)
    local loaded = {}
    for _, spec in ipairs(MODULES) do
        local module = loader(spec.name)
        assert(type(module[spec.contract]) == 'function',
            ('SoulSearch module %s is missing %s()'):format(
                spec.name, spec.contract))
        loaded[spec.name] = module
    end
    return loaded
end

---@return string[]
function get_script_names()
    -- Include this registry itself so an explicit reload cannot retain stale
    -- module names or contracts from an earlier development generation.
    local names = {REGISTRY_SCRIPT}
    -- Clear consumers before dependencies; load_all() rebuilds forward.
    for index = #MODULES, 1, -1 do
        table.insert(names, MODULES[index].name)
    end
    return names
end
