local module_loader = require('support.module_loader')

local M = {}

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
    local globals = {
        df=M.make_df_stub(),
        reqscript=function(name)
            assert(name == 'modtools/set-personality', 'unexpected reqscript: ' .. tostring(name))
            return personality
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
    local globals = {
        df=df_override or M.make_df_stub(),
        reqscript=function(name)
            if name == 'internal/soulsearch/df_enums' then
                return df_enums
            end
            if name == 'internal/soulsearch/skill_categories' then
                return skill_categories
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
    local globals = {
        reqscript=function(name)
            if name == 'internal/soulsearch/attributes' then
                return attributes
            end
            if name == 'internal/soulsearch/descriptors' then
                return descriptors
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

return M
