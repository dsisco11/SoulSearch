local module_loader = require('support.module_loader')

local M = {}

function M.load_filter_constants(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/filter_constants.lua')
end

local function make_enum(names, values, attrs)
    local enum = {attrs=attrs}
    for index, name in ipairs(names) do
        enum[index] = name
        enum[name] = values and values[name] or index
    end
    return enum
end

local function make_personality_stub()
    return {
        getUnitCasteTraitRange=function(unit, key)
            local baselines = unit and unit.trait_baselines
            local baseline = baselines and baselines[key]
            return baseline and {mid=baseline} or nil
        end,
        getTraitTier=function(value)
            return math.floor(value / 10)
        end,
    }
end

function M.make_df_stub()
    return {
        physical_attribute_type=make_enum(
            {'STRENGTH', 'AGILITY'},
            {STRENGTH=0, AGILITY=3}),
        mental_attribute_type=make_enum(
            {'FOCUS', 'WILLPOWER'},
            {FOCUS=1, WILLPOWER=4}),
        personality_facet_type=make_enum(
            {'PATIENCE', 'BRAVERY'},
            {PATIENCE=2, BRAVERY=7}),
        job_skill=make_enum(
            {'MINING', 'SWORD', 'PERSUASION', 'WRITING', 'SWIMMING', 'UNLISTED_SKILL'},
            {MINING=0, SWORD=4, PERSUASION=8, WRITING=12, SWIMMING=16, UNLISTED_SKILL=20},
            {
                [0]={caption='mining'},
                [4]={caption_noun='swordsman'},
            }),
        global={
            world={
                raws={
                    creatures={
                        all={
                            [1]={
                                raws={
                                    {value='PHYS_ATT_RANGE:STRENGTH:0:0:0:1250'},
                                    {value='MENT_ATT_RANGE:FOCUS:0:0:0:900'},
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end

function M.load_attributes(repo_root)
    local personality = make_personality_stub()
    local filter_constants = M.load_filter_constants(repo_root)
    local globals = {
        df=M.make_df_stub(),
        reqscript=function(name)
            if name == 'modtools/set-personality' then return personality end
            if name == 'internal/soulsearch/filter_constants' then
                return filter_constants
            end
            error('unexpected reqscript: ' .. tostring(name))
        end,
    }
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/attributes.lua',
        globals)
end

function M.load_df_enums(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/df_enums.lua')
end

function M.load_skill_categories(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/skill_categories.lua')
end

function M.load_descriptors(repo_root, df_override)
    local df_enums = M.load_df_enums(repo_root)
    local skill_categories = M.load_skill_categories(repo_root)
    local filter_constants = M.load_filter_constants(repo_root)
    local df = df_override or M.make_df_stub()
    local race_catalog = M.load_race_catalog(repo_root, df)
    local globals = {
        df=df,
        reqscript=function(name)
            if name == 'internal/soulsearch/df_enums' then
                return df_enums
            end
            if name == 'internal/soulsearch/skill_categories' then
                return skill_categories
            end
            if name == 'internal/soulsearch/race_catalog' then
                return race_catalog
            end
            if name == 'internal/soulsearch/filter_constants' then
                return filter_constants
            end
            error('unexpected reqscript: ' .. tostring(name))
        end,
    }
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/descriptors.lua',
        globals), globals.df
end

function M.load_search(repo_root, attributes)
    local descriptors, descriptor_df = M.load_descriptors(repo_root)
    local text_match = M.load_text_match(repo_root)
    local filter_constants = M.load_filter_constants(repo_root)
    local globals = {
        reqscript=function(name)
            if name == 'internal/soulsearch/attributes' then
                return attributes
            end
            if name == 'internal/soulsearch/descriptors' then
                return descriptors
            end
            if name == 'internal/soulsearch/text_match' then
                return text_match
            end
            if name == 'internal/soulsearch/filter_constants' then
                return filter_constants
            end
            error('unexpected reqscript: ' .. tostring(name))
        end,
    }
    local search = module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/search.lua',
        globals)
    return search, descriptors, descriptor_df
end

function M.load_filter_state(repo_root)
    local descriptors = M.load_descriptors(repo_root)
    local filter_constants = M.load_filter_constants(repo_root)
    local globals = {
        reqscript=function(name)
            if name == 'internal/soulsearch/descriptors' then return descriptors end
            if name == 'internal/soulsearch/filter_constants' then
                return filter_constants
            end
            error('unexpected reqscript: ' .. tostring(name))
        end,
    }
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/filter_state.lua',
        globals), descriptors
end

function M.load_race_catalog(repo_root, df_stub)
    local filter_constants = M.load_filter_constants(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/race_catalog.lua',
        {
            df=df_stub or M.make_df_stub(),
            reqscript=function(name)
                assert(name == 'internal/soulsearch/filter_constants',
                    'unexpected reqscript: ' .. tostring(name))
                return filter_constants
            end,
        })
end

function M.load_candidate_provider(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/candidate_provider.lua')
end

function M.load_unit_scope_provider(repo_root, df_stub, dfhack_stub)
    local candidate_provider = M.load_candidate_provider(repo_root)
    local filter_constants = M.load_filter_constants(repo_root)
    local globals = {
        df=df_stub,
        dfhack=dfhack_stub,
        reqscript=function(name)
            if name == 'internal/soulsearch/candidate_provider' then
                return candidate_provider
            end
            if name == 'internal/soulsearch/filter_constants' then
                return filter_constants
            end
            error('unexpected reqscript: ' .. tostring(name))
        end,
    }
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/unit_scope_provider.lua',
        globals)
end

function M.load_race_filter_provider(repo_root, df_stub)
    local descriptors = M.load_descriptors(repo_root, df_stub)
    local race_catalog = M.load_race_catalog(repo_root, df_stub)
    local candidate_provider = M.load_candidate_provider(repo_root)
    local filter_constants = M.load_filter_constants(repo_root)
    local globals = {
        reqscript=function(name)
            if name == 'internal/soulsearch/candidate_provider' then
                return candidate_provider
            end
            if name == 'internal/soulsearch/descriptors' then return descriptors end
            if name == 'internal/soulsearch/race_catalog' then return race_catalog end
            if name == 'internal/soulsearch/filter_constants' then
                return filter_constants
            end
            error('unexpected reqscript: ' .. tostring(name))
        end,
    }
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/race_filter_provider.lua',
        globals)
end

function M.load_ui_refresh(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui_refresh.lua')
end

function M.load_filter_presets(repo_root, json_stub, scriptmanager_stub, dfhack_stub)
    local globals = {
        dfhack=dfhack_stub or {filesystem={listdir=function() return {} end}},
        require=function(name)
            if name == 'json' then return json_stub end
            if name == 'script-manager' then return scriptmanager_stub end
            error('unexpected require: ' .. tostring(name))
        end,
    }
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/filter_presets.lua',
        globals)
end

function M.load_filter_defaults(repo_root)
    local filter_constants = M.load_filter_constants(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/filter_defaults.lua',
        {
            reqscript=function(name)
                assert(name == 'internal/soulsearch/filter_constants',
                    'unexpected reqscript: ' .. tostring(name))
                return filter_constants
            end,
        })
end

function M.load_role_presets(repo_root, descriptors_override)
    local descriptors = descriptors_override or M.load_descriptors(repo_root)
    local filter_defaults = M.load_filter_defaults(repo_root)
    local filter_constants = M.load_filter_constants(repo_root)
    local globals = {
        reqscript=function(name)
            if name == 'internal/soulsearch/descriptors' then return descriptors end
            if name == 'internal/soulsearch/filter_defaults' then return filter_defaults end
            if name == 'internal/soulsearch/filter_constants' then
                return filter_constants
            end
            error('unexpected reqscript: ' .. tostring(name))
        end,
    }
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/role_presets.lua',
        globals)
end

function M.load_text_match(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/text_match.lua')
end

function M.load_ui_layout(repo_root)
    local glyphs = M.load_ui_glyphs(repo_root)
    local globals = {
        reqscript=function(name)
            assert(name == 'internal/soulsearch/ui_glyphs',
                'unexpected reqscript: ' .. tostring(name))
            return glyphs
        end,
    }
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui_layout.lua', globals)
end

function M.load_ui_glyphs(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui_glyphs.lua')
end

function M.load_attribute_descriptions(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/attribute_descriptions.lua')
end

local function make_presentation_globals()
    return {
        NEWLINE='<NL>',
        COLOR_DARKGREY='darkgrey',
        COLOR_GREY='grey',
        COLOR_WHITE='white',
        COLOR_YELLOW='yellow',
        COLOR_GREEN='green',
        COLOR_LIGHTGREEN='lightgreen',
        COLOR_RED='red',
        COLOR_LIGHTRED='lightred',
        COLOR_LIGHTBLUE='lightblue',
        COLOR_LIGHTMAGENTA='lightmagenta',
    }
end

function M.load_ui_format(repo_root)
    local layout = M.load_ui_layout(repo_root)
    local glyphs = M.load_ui_glyphs(repo_root)
    local filter_constants = M.load_filter_constants(repo_root)
    local globals = make_presentation_globals()
    globals.reqscript=function(name)
        if name == 'internal/soulsearch/ui_layout' then return layout end
        if name == 'internal/soulsearch/ui_glyphs' then return glyphs end
        if name == 'internal/soulsearch/filter_constants' then
            return filter_constants
        end
        error('unexpected reqscript: ' .. tostring(name))
    end
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui_format.lua',
        globals)
end

function M.load_stats_presenter(repo_root, attributes)
    local ui_format = M.load_ui_format(repo_root)
    local globals = make_presentation_globals()
    globals.reqscript=function(name)
        if name == 'internal/soulsearch/attributes' then
            return attributes
        end
        if name == 'internal/soulsearch/ui_format' then
            return ui_format
        end
        error('unexpected reqscript: ' .. tostring(name))
    end
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/stats_presenter.lua',
        globals)
end

function M.load_ui_components(repo_root)
    local layout = M.load_ui_layout(repo_root)
    local ui_format = M.load_ui_format(repo_root)
    local function constructor(kind)
        return function(config)
            config.widget_kind = kind
            return config
        end
    end
    local widgets = {
        Label=constructor('Label'),
        HotkeyLabel=constructor('HotkeyLabel'),
        EditField=constructor('EditField'),
        List=constructor('List'),
        Window=constructor('Window'),
    }
    local globals = make_presentation_globals()
    globals.require=function(name)
        assert(name == 'gui.widgets', 'unexpected require: ' .. tostring(name))
        return widgets
    end
    globals.reqscript=function(name)
        if name == 'internal/soulsearch/stats_presenter' then
            return {
            header=function(result) return {'header', result} end,
            column_header=function(key, reverse)
                return {'columns', key, reverse}
            end,
            get_display_records=function() return {} end,
            body=function(result, key, reverse)
                    return {'body', result, key, reverse}
                end,
            }
        end
        if name == 'internal/soulsearch/ui_format' then return ui_format end
        if name == 'internal/soulsearch/ui_layout' then return layout end
        error('unexpected reqscript: ' .. tostring(name))
    end
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui_components.lua',
        globals)
end

function M.load_residents(repo_root, df_enums_override, dfhack_override)
    local df_enums = df_enums_override or M.load_df_enums(repo_root)
    local globals = {
        df=M.make_df_stub(),
        dfhack=dfhack_override,
        reqscript=function(name)
            if name == 'internal/soulsearch/df_enums' then return df_enums end
            error('unexpected reqscript: ' .. tostring(name))
        end,
    }
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/residents.lua',
        globals)
end

function M.load_lifecycle(repo_root, modules, df_stub)
    local globals = {
        df=df_stub or {global={world={}}},
        reqscript=function(name)
            local module = modules[name]
            assert(module, 'unexpected reqscript: ' .. tostring(name))
            return module
        end,
    }
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/lifecycle.lua',
        globals)
end

function M.load_module_registry(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/module_registry.lua')
end

return M
