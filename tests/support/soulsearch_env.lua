local module_loader = require('support.module_loader')

local M = {}

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

local function make_df_stub()
    return {
        physical_attribute_type={'STRENGTH', 'AGILITY'},
        mental_attribute_type={'FOCUS', 'WILLPOWER'},
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
        df=make_df_stub(),
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

function M.load_search(repo_root, attributes)
    local globals = {
        reqscript=function(name)
            assert(name == 'internal/soulsearch/attributes', 'unexpected reqscript: ' .. tostring(name))
            return attributes
        end,
    }
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/search.lua',
        globals)
end

return M
