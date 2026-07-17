local module_loader = require('support.module_loader')
local widget_harness = require('support.widget_harness')

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
    local unit_scope_catalog = M.load_unit_scope_catalog(repo_root, {
        units={
            isCitizen=function() return false end,
            isResident=function() return false end,
            isFortControlled=function() return false end,
            isVisitor=function() return false end,
            isMerchant=function() return false end,
            isDiplomat=function() return false end,
        },
    })
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
            if name == 'internal/soulsearch/unit_scope_catalog' then
                return unit_scope_catalog
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

function M.load_unit_scope_catalog(repo_root, dfhack_stub)
    local filter_constants = M.load_filter_constants(repo_root)
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/unit_scope_catalog.lua', {
            dfhack=dfhack_stub,
            reqscript=function(name)
                assert(name == 'internal/soulsearch/filter_constants',
                    'unexpected reqscript: ' .. tostring(name))
                return filter_constants
            end,
        })
end

function M.load_active_unit_provider(repo_root, df_stub, dfhack_stub)
    local candidate_provider = M.load_candidate_provider(repo_root)
    local availability = M.load_availability(repo_root, dfhack_stub)
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/active_unit_provider.lua', {
            df=df_stub, dfhack=dfhack_stub,
            reqscript=function(name)
                if name == 'internal/soulsearch/candidate_provider' then
                    return candidate_provider
                end
                if name == 'internal/soulsearch/availability' then return availability end
                error('unexpected reqscript: ' .. tostring(name))
            end,
        })
end

function M.load_candidate_filter_family_provider(repo_root, descriptors_override)
    local candidate_provider = M.load_candidate_provider(repo_root)
    local descriptors = descriptors_override or M.load_descriptors(repo_root)
    local filter_constants = M.load_filter_constants(repo_root)
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/candidate_filter_family_provider.lua', {
            reqscript=function(name)
                if name == 'internal/soulsearch/candidate_provider' then
                    return candidate_provider
                end
                if name == 'internal/soulsearch/descriptors' then return descriptors end
                if name == 'internal/soulsearch/filter_constants' then
                    return filter_constants
                end
                error('unexpected reqscript: ' .. tostring(name))
            end,
        })
end

function M.load_race_filter_provider(repo_root, df_stub)
    local descriptors = M.load_descriptors(repo_root, df_stub)
    local race_catalog = M.load_race_catalog(repo_root, df_stub)
    local candidate_filter_family_provider =
        M.load_candidate_filter_family_provider(repo_root, descriptors)
    local filter_constants = M.load_filter_constants(repo_root)
    local globals = {
        reqscript=function(name)
            if name == 'internal/soulsearch/candidate_filter_family_provider' then
                return candidate_filter_family_provider
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

function M.load_unit_scope_filter_provider(repo_root, dfhack_stub)
    local unit_scope_catalog = M.load_unit_scope_catalog(repo_root, dfhack_stub)
    local descriptors = M.load_descriptors(repo_root)
    local candidate_filter_family_provider =
        M.load_candidate_filter_family_provider(repo_root, descriptors)
    local filter_constants = M.load_filter_constants(repo_root)
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/unit_scope_filter_provider.lua', {
            reqscript=function(name)
                if name == 'internal/soulsearch/candidate_filter_family_provider' then
                    return candidate_filter_family_provider
                end
                if name == 'internal/soulsearch/unit_scope_catalog' then
                    return unit_scope_catalog
                end
                if name == 'internal/soulsearch/filter_constants' then
                    return filter_constants
                end
                error('unexpected reqscript: ' .. tostring(name))
            end,
        })
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
    local stats_layout = M.load_stats_layout(repo_root)
    local globals = {
        reqscript=function(name)
            if name == 'internal/soulsearch/ui_glyphs' then return glyphs end
            if name == 'internal/soulsearch/stats_layout' then return stats_layout end
            error('unexpected reqscript: ' .. tostring(name))
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
        DEFAULT_NIL=widget_harness.default_nil(),
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
        COLOR_CYAN='cyan',
        COLOR_LIGHTCYAN='lightcyan',
        COLOR_LIGHTMAGENTA='lightmagenta',
    }
end

function M.load_ui_format(repo_root)
    local layout = M.load_ui_layout(repo_root)
    local stats_layout = M.load_stats_layout(repo_root)
    local glyphs = M.load_ui_glyphs(repo_root)
    local filter_constants = M.load_filter_constants(repo_root)
    local globals = make_presentation_globals()
    globals.reqscript=function(name)
        if name == 'internal/soulsearch/ui_layout' then return layout end
        if name == 'internal/soulsearch/ui_glyphs' then return glyphs end
        if name == 'internal/soulsearch/stats_layout' then return stats_layout end
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

function M.load_result_presenter(repo_root)
    local ui_format = M.load_ui_format(repo_root)
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/result_presenter.lua', {
        reqscript=function(name)
            assert(name == 'internal/soulsearch/ui_format')
            return ui_format
        end,
    })
end

function M.load_filter_presenter(repo_root)
    local ui_format = M.load_ui_format(repo_root)
    local constants = M.load_filter_constants(repo_root)
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/filter_presenter.lua', {
        reqscript=function(name)
            if name == 'internal/soulsearch/ui_format' then return ui_format end
            if name == 'internal/soulsearch/filter_constants' then return constants end
            error('unexpected reqscript: ' .. tostring(name))
        end,
    })
end

function M.load_search_session(repo_root)
    local filters = M.load_filter_state(repo_root)
    local search = M.load_search(repo_root)
    local sort_state = M.load_sort_state(repo_root)
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/search_session.lua', {
        reqscript=function(name)
            if name == 'internal/soulsearch/filter_state' then return filters end
            if name == 'internal/soulsearch/search' then return search end
            if name == 'internal/soulsearch/sort_state' then return sort_state end
            error('unexpected reqscript: ' .. tostring(name))
        end,
    })
end

function M.load_stats_layout(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/stats_layout.lua')
end

function M.load_sort_state(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/sort_state.lua')
end

function M.load_stats_subject(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/stats_subject.lua')
end

function M.load_unit_stats_list(repo_root)
    local stats_layout = M.load_stats_layout(repo_root)
    local sort_state = M.load_sort_state(repo_root)
    local widgets = widget_harness.widgets()
    local globals={COLOR_WHITE='white', COLOR_GREY='grey', DEFAULT_NIL=nil,
        defclass=widget_harness.defclass}
    globals.require=function() return widgets end
    globals.reqscript=function(name)
        if name == 'internal/soulsearch/ui/widget_extensions' then return {} end
        if name == 'internal/soulsearch/stats_layout' then return stats_layout end
        if name == 'internal/soulsearch/sort_state' then return sort_state end
        if name == 'internal/soulsearch/ui/sortable_header' then return {
            new=function(info)
                local on_cycle = info.on_cycle
                info.on_change = function() on_cycle() end
                return widgets.CycleHotkeyLabel(info)
            end,
            set_sort=function(control, active, reverse)
                control:setOption(not active and 0 or reverse and 2 or 1, false)
            end,
        } end
        if name == 'internal/soulsearch/ui_glyphs' then
            return {CP437_HORIZONTAL_LINE=string.char(196)}
        end
        if name == 'internal/soulsearch/attribute_descriptions' then
            return {get_tooltip=function(kind, key) return kind .. ':' .. key end}
        end
        if name == 'internal/soulsearch/stats_presenter' then return {
            body=function() return 'one\ntwo' end,
            get_display_records=function() return {{kind='trait', key='PATIENCE'}} end,
        } end
        error('unexpected reqscript: ' .. name)
    end
    local loaded = module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui/unit_stats_list.lua', globals)
    return loaded.UnitStatsList
end

function M.load_unit_identity(repo_root)
    local widgets = widget_harness.widgets()
    local globals={COLOR_WHITE='white', COLOR_DARKGREY='darkgrey', DEFAULT_NIL=nil,
        defclass=widget_harness.defclass}
    globals.require=function() return widgets end
    globals.reqscript=function(name)
        assert(name == 'internal/soulsearch/ui/widget_extensions',
            'unexpected reqscript: ' .. tostring(name))
        return {}
    end
    local loaded = module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui/unit_identity.lua', globals)
    return loaded.UnitIdentity
end

function M.load_matched_filters_panel(repo_root)
    local ui_format = M.load_ui_format(repo_root)
    local widgets = widget_harness.widgets()
    local globals={DEFAULT_NIL=nil, defclass=widget_harness.defclass}
    globals.require=function() return widgets end
    globals.reqscript=function(name)
        if name == 'internal/soulsearch/ui/widget_extensions' then return {} end
        if name == 'internal/soulsearch/ui_format' then return ui_format end
        error('unexpected reqscript: ' .. tostring(name))
    end
    local loaded = module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui/matched_filters_panel.lua', globals)
    return loaded.MatchedFiltersPanel
end

function M.load_stats_panel(repo_root)
    local stats_layout = M.load_stats_layout(repo_root)
    local sort_state = M.load_sort_state(repo_root)
    local widgets = widget_harness.widgets()
    local globals={COLOR_WHITE='white', COLOR_GREY='grey', DEFAULT_NIL=nil}
    globals.defclass=widget_harness.defclass
    globals.require=function() return widgets end
    globals.reqscript=function(name)
        if name == 'internal/soulsearch/ui/widget_extensions' then return {} end
        if name == 'internal/soulsearch/stats_layout' then return stats_layout end
        if name == 'internal/soulsearch/sort_state' then return sort_state end
        if name == 'internal/soulsearch/ui/unit_identity' then return {
            UnitIdentity=function(info)
                function info:set_subject(subject)
                    self.subject = subject
                    self.has_subject = subject and subject.row and true or false
                end
                function info:get_height() return self.has_subject and 3 or 1 end
                info:set_subject(info.subject)
                return info
            end,
        } end
        if name == 'internal/soulsearch/ui/matched_filters_panel' then return {
            MatchedFiltersPanel=function(info)
                function info:set_subject(subject)
                    self.subject = subject
                    self.has_filters = subject and subject.filter_criteria and
                        #subject.filter_criteria > 0 or false
                end
                function info:get_height() return self.has_filters and 1 or 0 end
                info:set_subject(info.subject)
                return info
            end,
        } end
        if name == 'internal/soulsearch/ui/unit_stats_list' then return {
            UnitStatsList=function(info)
                info.subviews = {body={start_line_num=1}, columns={}, value_column={}}
                info.sort = {key=info.sort.key, reverse=info.sort.reverse, phase=info.sort.phase}
                function info:get_sort()
                    return {key=self.sort.key, reverse=self.sort.reverse, phase=self.sort.phase}
                end
                function info:set_subject(subject) self.subject = subject end
                function info:set_sort(sort)
                    self.sort = {key=sort.key, reverse=sort.reverse, phase=sort.phase}
                end
                function info:reset_view_state(sort)
                    self:set_sort(sort)
                    self.subviews.body.start_line_num = 1
                end
                function info:cycle_sort(column)
                    self.sort = {key=column, reverse=false, phase=1}
                    self.on_sort_change(self:get_sort())
                end
                function info:set_header_height(height) self.header_height = height end
                return info
            end,
        } end
        if name == 'internal/soulsearch/ui/sortable_header' then return {
            new=function(info)
                local on_cycle = info.on_cycle
                info.on_change = function() on_cycle() end
                return widgets.CycleHotkeyLabel(info)
            end,
            set_sort=function(control, active, reverse)
                control:setOption(not active and 0 or reverse and 2 or 1, false)
            end,
        } end
        if name == 'internal/soulsearch/attribute_descriptions' then
            return {get_tooltip=function(kind, key) return kind .. ':' .. key end}
        end
        error('unexpected reqscript: ' .. name)
    end
    local loaded = module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/stats_panel.lua', globals)
    return loaded.UnitInfoPanel
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

local function load_ui_leaf_module(repo_root, relative_path)
    local layout = M.load_ui_layout(repo_root)
    local descriptions = M.load_attribute_descriptions(repo_root)
    local constants = M.load_filter_constants(repo_root)
    local widgets = widget_harness.widgets({
        Window={onInput=function(self)
                self.super_input_calls = (self.super_input_calls or 0) + 1
                return self.super_input_result or false
            end},
        List={onInput=function(self)
                self.super_input_calls = (self.super_input_calls or 0) + 1
                return self.super_input_result or false
            end,
            setChoices=function(self, choices, selected)
                self.base_choices = choices
                self.base_selected = selected
                return self.base_set_choices_result
            end},
    })
    local globals = make_presentation_globals()
    globals.defclass=widget_harness.defclass
    globals.require=function(name)
        assert(name == 'gui.widgets', 'unexpected require: ' .. tostring(name))
        return widgets
    end
    globals.reqscript=function(name)
        if name == 'internal/soulsearch/ui_layout' then return layout end
        if name == 'internal/soulsearch/attribute_descriptions' then
            return descriptions
        end
        if name == 'internal/soulsearch/filter_constants' then return constants end
        if name == 'internal/soulsearch/ui/widget_extensions' then
            return extension
        end
        error('unexpected reqscript: ' .. tostring(name))
    end
    extension = module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui/widget_extensions.lua', globals)
    return module_loader.load(repo_root, relative_path, globals)
end

function M.load_modal_panel(repo_root)
    return load_ui_leaf_module(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui/modal_panel.lua')
end

function M.load_pointer_dispatcher(repo_root, dfhack_stub)
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui/pointer_dispatcher.lua', {
            dfhack=dfhack_stub or {screen={getMousePos=function() return nil end}},
        })
end

function M.load_filter_action_list(repo_root)
    return load_ui_leaf_module(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui/filter_action_list.lua')
end

function M.load_filter_panel(repo_root, get_mouse_pos)
    local layout = M.load_ui_layout(repo_root)
    local ui_format = M.load_ui_format(repo_root)
    local descriptions = M.load_attribute_descriptions(repo_root)
    local constants = M.load_filter_constants(repo_root)
    local widgets = widget_harness.widgets()
    local globals = make_presentation_globals()
    globals.defclass=widget_harness.defclass
    globals.dfhack={screen={getMousePos=get_mouse_pos or function() return nil end}}
    globals.require=function(name)
        assert(name == 'gui.widgets', 'unexpected require: ' .. tostring(name))
        return widgets
    end
    local modules = {}
    modules['internal/soulsearch/ui_layout'] = layout
    modules['internal/soulsearch/ui_format'] = ui_format
    modules['internal/soulsearch/attribute_descriptions'] = descriptions
    modules['internal/soulsearch/filter_constants'] = constants
    globals.reqscript=function(name)
        return assert(modules[name], 'unexpected reqscript: ' .. tostring(name))
    end
    local function load(relative_path)
        local environment = {}
        for key, value in pairs(globals) do environment[key] = value end
        return module_loader.load(repo_root, relative_path, environment)
    end
    modules['internal/soulsearch/ui/widget_extensions'] = load(
        'src/scripts_modinstalled/internal/soulsearch/ui/widget_extensions.lua')
    modules['internal/soulsearch/ui/modal_panel'] = load(
        'src/scripts_modinstalled/internal/soulsearch/ui/modal_panel.lua')
    modules['internal/soulsearch/ui/filter_action_list'] = load(
        'src/scripts_modinstalled/internal/soulsearch/ui/filter_action_list.lua')
    modules['internal/soulsearch/ui/searchable_picker'] = load(
        'src/scripts_modinstalled/internal/soulsearch/ui/searchable_picker.lua')
    modules['internal/soulsearch/ui/preset_picker'] = load(
        'src/scripts_modinstalled/internal/soulsearch/ui/preset_picker.lua')
    return load('src/scripts_modinstalled/internal/soulsearch/ui/filter_panel.lua'), modules
end

function M.load_results_panel(repo_root)
    local layout = M.load_ui_layout(repo_root)
    local ui_format = M.load_ui_format(repo_root)
    local widgets = widget_harness.widgets()
    local globals = make_presentation_globals()
    globals.defclass=widget_harness.defclass
    globals.require=function(name)
        assert(name == 'gui.widgets', 'unexpected require: ' .. tostring(name))
        return widgets
    end
    globals.reqscript=function(name)
        if name == 'internal/soulsearch/ui/widget_extensions' then
            return extension
        end
        if name == 'internal/soulsearch/ui_layout' then return layout end
        if name == 'internal/soulsearch/ui_format' then return ui_format end
        if name == 'internal/soulsearch/ui/sortable_header' then return {
            new=function(info)
                local on_cycle = info.on_cycle
                info.on_change = function() on_cycle() end
                return widgets.CycleHotkeyLabel(info)
            end,
            set_sort=function(control, active, reverse)
                control:setOption(not active and 0 or reverse and 2 or 1, false)
            end,
        } end
        error('unexpected reqscript: ' .. tostring(name))
    end
    extension = module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui/widget_extensions.lua', globals)
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui/results_panel.lua', globals)
end

function M.load_residents(repo_root, df_enums_override, dfhack_override)
    local df_enums = df_enums_override or M.load_df_enums(repo_root)
    local dfhack = dfhack_override or {
        isMapLoaded=function() return true end,
        world={isFortressMode=function() return true end},
    }
    local availability = M.load_availability(repo_root, dfhack)
    local globals = {
        df=M.make_df_stub(),
        dfhack=dfhack,
        reqscript=function(name)
            if name == 'internal/soulsearch/df_enums' then return df_enums end
            if name == 'internal/soulsearch/availability' then return availability end
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

function M.load_window_settings(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/window_settings.lua')
end

function M.load_window_config(repo_root)
    local filter_state = M.load_filter_state(repo_root)
    local filter_constants = M.load_filter_constants(repo_root)
    local window_settings = M.load_window_settings(repo_root)
    local ui_layout = M.load_ui_layout(repo_root)
    local sort_state = M.load_sort_state(repo_root)
    local modules = {
        ['internal/soulsearch/filter_state']=filter_state,
        ['internal/soulsearch/filter_constants']=filter_constants,
        ['internal/soulsearch/window_settings']=window_settings,
        ['internal/soulsearch/ui_layout']=ui_layout,
        ['internal/soulsearch/sort_state']=sort_state,
    }
    local config = module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/window_config.lua', {
            reqscript=function(name)
                local module = modules[name]
                assert(module, 'unexpected reqscript: ' .. tostring(name))
                return module
            end,
        })
    return config, window_settings
end

function M.load_screen_registry(repo_root)
    return module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/screen_registry.lua')
end

---Loads ui.lua with only the interfaces needed to characterize open() rejecting
---an unavailable context. The screen constructor deliberately fails if it is
---reached, proving the guard runs before any DFHack UI construction.
---@param repo_root string
---@param unavailable_reason string|nil
---@return table ui_environment, table screen_registry, table ui_state
function M.load_ui_open_guard(repo_root, unavailable_reason)
    local function class()
        local result = {}
        function result.ATTRS() end
        return result
    end

    local filter_constants = {
        FILTER_CONSTANTS={
            direction={HIGH='high', LOW='low'},
            kind={RACE='race'},
            race={group_id_prefix='race:group:'},
        },
    }
    local layout = {
        WINDOW_FRAME={w=150, h=45},
        WINDOW_RESIZE_MIN={w=1, h=1},
        copy_dimensions=function(frame) return frame end,
    }
    local residents = {
        get_unavailable_reason=function() return unavailable_reason end,
    }
    local screen_registry = M.load_screen_registry(repo_root)
    local ui_state = {}
    local window_config = {
        resolve=function(options)
            ui_state.options = options
            return {
                settings_id=(options and options.settings_id) or 'default',
                explicit={},
                frame={l=1, t=2, w=110, h=45},
            }
        end,
    }
    local window_settings = {update=function() end}
    local empty_module = {}
    local screen_constructor = {construct=function()
        error('SoulSearchScreen was constructed for an unavailable context')
    end}
    setmetatable(screen_constructor, {__call=function(self, attributes)
        return self.construct(attributes)
    end})
    local modules = {
        ['internal/soulsearch/residents']=residents,
        ['internal/soulsearch/filter_constants']=filter_constants,
        ['internal/soulsearch/ui_layout']=layout,
        ['internal/soulsearch/ui_tooltip']={
            SoulSearchTooltip=function(info) return info end,
        },
        ['internal/soulsearch/ui/tooltip_agent']={
            TooltipAgent={new=function() return {update=function() end} end},
        },
        ['internal/soulsearch/screen_registry']=screen_registry,
        ['internal/soulsearch/window_config']=window_config,
        ['internal/soulsearch/window_settings']=window_settings,
        ['internal/soulsearch/ui/main_screen']={
            SoulSearchScreen=screen_constructor,
        },
    }
    local widgets = {
        Window=class(),
    }
    local globals = {
        COLOR_DARKGREY='darkgrey',
        COLOR_BLACK='black',
        COLOR_WHITE='white',
        DEFAULT_NIL=nil,
        defclass=function() return class() end,
        dfhack={
            pen={parse=function(value) return value end},
            screen={
                getMousePos=function() return nil end,
                getWindowSize=function() return 150, 45 end,
            },
        },
        require=function(name)
            if name == 'gui' then return {FRAME_THIN='thin'} end
            if name == 'gui.dialogs' then return {} end
            if name == 'gui.widgets' then return widgets end
            error('unexpected require: ' .. tostring(name))
        end,
        reqscript=function(name)
            return modules[name] or empty_module
        end,
    }
    local environment = module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui.lua', globals)
    return environment, screen_registry, ui_state, screen_constructor
end

function M.load_availability(repo_root, dfhack_stub)
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/availability.lua', {
            dfhack=dfhack_stub,
        })
end

---Loads the composed UI with deterministic pure-Lua collaborators. This keeps
---the characterization boundary on the real ui.lua methods while avoiding a
---dependency on a running DFHack graphical context.
---@param repo_root string
---@return table ui, fun(settings: table|nil): table new_window, table state
function M.load_ui_characterization(repo_root)
    local filter_state = M.load_filter_state(repo_root)
    local ui_format = M.load_ui_format(repo_root)
    local ui_layout = M.load_ui_layout(repo_root)
    local ui_refresh = M.load_ui_refresh(repo_root)
    local screen_registry = M.load_screen_registry(repo_root)
    local state = {
        settings_updates={}, revealed={}, screen_registry=screen_registry,
    }
    local filter_panel = M.load_filter_panel(repo_root, function()
        return state.mouse_x, state.mouse_y
    end)
    local results_panel = M.load_results_panel(repo_root)
    local search_session = {
        SEARCH_QUERY_KIND={
            RESULT='result', ATTRIBUTE='attribute', SKILL='skill', RACE='race',
            UNIT_SCOPE='unit_scope', PRESET='preset',
        },
        new=function(settings)
            local session = {
                filter_state=filter_state.new(settings.filters),
                result_sort={key=settings.result_sort.key,
                    reverse=settings.result_sort.reverse,
                    phase=settings.result_sort.phase},
                query='', attribute_query='', skill_query='', race_query='',
                unit_scope_query='', preset_query='', rows={}, selected_index=1,
            }
            function session:get_filters() return filter_state.get_filters(self.filter_state) end
            function session:get_candidate_filters()
                return filter_state.get_candidate_filters(self.filter_state)
            end
            function session:filter_count() return filter_state.count(self.filter_state) end
            function session:get_filter_priority(id) return filter_state.get_priority(self.filter_state, id) end
            function session:contains_filter(id) return filter_state.contains(self.filter_state, id) end
            function session:set_query(kind, value)
                local field = kind == 'attribute' and 'attribute_query' or kind == 'skill' and 'skill_query' or
                    kind == 'race' and 'race_query' or kind == 'unit_scope' and 'unit_scope_query' or
                    kind == 'preset' and 'preset_query' or 'query'
                if self[field] == value then return false end
                self[field] = value
                return true
            end
            function session:set_selected_result(result, index)
                self.selected_unit_id = result and result.unit_id or nil
                self.selected_index = index or self.selected_index
            end
            function session:recompute_results()
                local results = state.results or {}
                state.last_sort = {results=results, key=self.result_sort.key,
                    reverse=self.result_sort.reverse}
                local index = math.max(1, math.min(self.selected_index, #results))
                for i, result in ipairs(results) do
                    if result.unit_id == self.selected_unit_id then index = i break end
                end
                return results, index
            end
            function session:get_result_sort()
                return {key=self.result_sort.key, reverse=self.result_sort.reverse,
                    phase=self.result_sort.phase}
            end
            function session:cycle_sort(column)
                local sort = self.result_sort
                if sort.key == column then sort.phase = sort.phase + 1
                else sort.key, sort.phase = column, 1 end
                if sort.phase >= 3 then sort.key, sort.reverse, sort.phase = nil, false, 0
                else sort.reverse = sort.phase == 2 end
                return self:get_result_sort()
            end
            function session:add_filter(id) return filter_state.add(self.filter_state, id) end
            function session:remove_filter(id) return filter_state.remove(self.filter_state, id) end
            function session:clear_filters() return filter_state.clear(self.filter_state) end
            function session:replace_filters(filters) return filter_state.replace(self.filter_state, filters) end
            function session:set_filter_direction(id, direction)
                return filter_state.set_direction(self.filter_state, id, direction)
            end
            function session:move_filter(id, delta) return filter_state.move(self.filter_state, id, delta) end
            function session:replace_rows(rows) self.rows = rows end
            return session
        end,
    }
    local widgets = widget_harness.widgets()
    local gui = {FRAME_THIN='thin', ZScreen={}}
    local modules = {
        ['internal/soulsearch/residents']={
            get_unavailable_reason=function() return nil end,
            collect_from_provider=function() return state.rows or {} end,
        },
        ['internal/soulsearch/active_unit_provider']={new=function() return {} end},
        ['internal/soulsearch/unit_scope_filter_provider']={
            new=function(provider) return provider end,
        },
        ['internal/soulsearch/race_filter_provider']={
            new=function(provider) return provider end,
        },
        ['internal/soulsearch/search']={
            apply=function() return state.results or {} end,
            sort_results=function(results, key, reverse)
                state.last_sort = {results=results, key=key, reverse=reverse}
            end,
        },
        ['internal/soulsearch/search_session']=search_session,
        ['internal/soulsearch/descriptors']={
            get_catalog=function()
                return {by_id={}, groups={
                    physical_attributes={}, mental_attributes={}, traits={},
                    skills={}, races={}, unit_scopes={},
                }}
            end,
        },
        ['internal/soulsearch/filter_state']=filter_state,
        ['internal/soulsearch/window_settings']={
            update=function(id, changes)
                table.insert(state.settings_updates, {id=id, changes=changes})
            end,
        },
        ['internal/soulsearch/window_config']={
            resolve=function() error('explicit settings expected in characterization') end,
        },
        ['internal/soulsearch/screen_registry']=screen_registry,
        ['internal/soulsearch/filter_defaults']={get=function() end, get_all=function() return {} end},
        ['internal/soulsearch/role_presets']={
            get=function() end,
            get_role_presets=function() return {} end,
            get_combat_presets=function() return {} end,
        },
        ['internal/soulsearch/filter_presets']={list=function() return {} end},
        ['internal/soulsearch/skill_categories']={
            get_category=function() end,
            get_order=function() return {} end,
        },
        ['internal/soulsearch/text_match']=M.load_text_match(repo_root),
        ['internal/soulsearch/ui/filter_panel']=filter_panel,
        ['internal/soulsearch/ui/results_panel']=results_panel,
        ['internal/soulsearch/ui_format']=ui_format,
        ['internal/soulsearch/filter_presenter']={
            present_active=function() return {{text='Use Add attribute, Add skill, or Add race.'}} end,
            present_available=function(_, _, _, text) return {{text=text}} end,
            present_skills=function() return {{text='No matching skills.'}} end,
            present_races=function() return {{text='No matching races.'}} end,
            present_presets=function() return {{text='No matching presets.'}} end,
        },
        ['internal/soulsearch/result_presenter']={present=function(results, key, reverse)
            local choices = {}
            for _, result in ipairs(results) do table.insert(choices, {
                text=ui_format.format_result_choice(result), result=result,
                search_key=result.name}) end
            local title = ('Results (%d)'):format(#choices)
            return {choices=choices, title=title,
                underline=ui_format.get_title_underline(title),
                columns=ui_format.format_result_columns(key, reverse)}
        end},
        ['internal/soulsearch/ui_layout']=ui_layout,
        ['internal/soulsearch/ui_refresh']=ui_refresh,
        ['internal/soulsearch/stats_panel']={
            UnitInfoPanel=function(info)
                info.widget_kind = 'UnitInfoPanel'
                function info:set_subject(subject) self.subject = subject end
                return info
            end,
        },
        ['internal/soulsearch/ui_tooltip']={
            SoulSearchTooltip=function(info)
                info.widget_kind = 'SoulSearchTooltip'
                return info
            end,
        },
        ['internal/soulsearch/ui/tooltip_agent']={
            TooltipAgent={new=function() return {update=function() end} end},
        },
        ['internal/soulsearch/ui_glyphs']={CP437_VERTICAL_LINE=179},
        ['internal/soulsearch/filter_constants']={FILTER_CONSTANTS={
            direction={HIGH='high', LOW='low'},
            kind={RACE='race', UNIT_SCOPE='unit_scope'},
            race={group_id_prefix='race:group:'},
        }},
    }
    local globals = make_presentation_globals()
    globals.defclass = widget_harness.defclass
    globals.dfhack = {
        pen={parse=function(value) return value end},
        screen={
            getMousePos=function() return state.mouse_x, state.mouse_y end,
            getWindowSize=function() return 150, 45 end,
        },
        units={getPosition=function(unit) return unit.position end},
        gui={revealInDwarfmodeMap=function(pos)
            table.insert(state.revealed, pos)
        end},
    }
    globals.require = function(name)
        if name == 'gui' then return gui end
        if name == 'gui.dialogs' then return {showInputPrompt=function() end} end
        if name == 'gui.widgets' then return widgets end
        error('unexpected require: ' .. tostring(name))
    end
    globals.reqscript = function(name)
        local module = modules[name]
        assert(module, 'unexpected reqscript: ' .. tostring(name))
        return module
    end
    modules['internal/soulsearch/ui/widget_extensions'] = module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui/widget_extensions.lua',
        globals)

    local main_window = module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui/main_window.lua', globals)
    modules['internal/soulsearch/ui/main_window'] = main_window
    local main_screen = module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui/main_screen.lua', globals)
    modules['internal/soulsearch/ui/main_screen'] = main_screen
    local ui = module_loader.load(
        repo_root,
        'src/scripts_modinstalled/internal/soulsearch/ui.lua', globals)

    local function new_window(settings)
        settings = settings or {
            settings_id='default', explicit={},
            frame={l=1, t=2, w=110, h=45},
            filters={},
            result_sort={key=nil, reverse=false, phase=0},
            stats_sort={key='value', reverse=true},
        }
        local window = setmetatable(
            {settings=settings, subviews={}, visible=true},
            {__index=main_window.SoulSearchWindow})
        function window:addviews(views)
            self.subviews = views
            for _, child in ipairs(views) do
                if child.view_id then self.subviews[child.view_id] = child end
                widget_harness.attach_recursive(child, self, self.subviews)
            end
        end
        main_window.SoulSearchWindow.init(window)
        return window
    end

    return ui, new_window, state, main_window, main_screen
end

function M.load_stats_popover(repo_root, options)
    options = options or {}
    local registry = M.load_screen_registry(repo_root)
    local layout = M.load_stats_layout(repo_root)
    local config = module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/stats_popover_config.lua', {
            reqscript=function(name)
                assert(name == 'internal/soulsearch/stats_layout')
                return layout
            end,
        })
    local units = options.units or {}
    local state = {
        collects=0, resets=0, raises=0, printed={}, position_logs={}, widget_lookups=0,
    }
    local base = {
        addviews=function(self, views) self.subviews=views end,
        onShow=function() end,
        onResize=function() end,
        show=function(self) self.shown=true; self:onShow(); return self end,
        dismiss=function(self) self.dismissed=true; self:onDismiss() end,
        isActive=function(self) return self.shown and not self.dismissed end,
        raise=function(self) state.raises=state.raises+1 end,
    }
    local function class(parent)
        local result = {super=parent or base}
        function result.ATTRS() end
        return setmetatable(result, {
            __index=parent or base,
            __call=function(cls, info)
                local instance=info or {}
                setmetatable(instance, {__index=cls})
                if cls.init then cls.init(instance, info or {}) end
                return instance
            end,
        })
    end
    local function window(info)
        local subviews={}
        for _, view in ipairs(info.subviews or {}) do subviews[view.view_id]=view end
        info.subviews=subviews
        function info.updateLayout() end
        return info
    end
    local panel = function(info)
        local body={start_line_num=1}
        local result={view_id=info.view_id, subject=info.subject, sort=info.sort,
            subviews={body=body}}
        function result:set_subject(subject) self.subject=subject end
        function result:reset_view_state(sort)
            self.sort=sort; self.subviews.body.start_line_num=1
            state.resets=state.resets+1
        end
        return result
    end
    local residents = {
        get_unavailable_reason=function() return options.unavailable_reason end,
        validate_unit_reference=function(unit)
            if type(unit) ~= 'table' or type(unit.id) ~= 'number' then
                return nil, 'SoulSearch requires a valid unit.'
            end
            return unit.id
        end,
        collect_unit=function(unit)
            state.collects=state.collects+1
            if options.collect_error then return nil, options.collect_error end
            return {unit=unit, unit_id=unit.id}, nil
        end,
    }
    local modules={
        ['internal/soulsearch/residents']=residents,
        ['internal/soulsearch/stats_subject']={
            from_row=function(row) return {unit=row.unit, unit_id=row.unit_id, row=row} end,
        },
        ['internal/soulsearch/stats_popover_config']=config,
        ['internal/soulsearch/ui/unit_stats_list']={UnitStatsList=panel},
        ['internal/soulsearch/ui/widget_extensions']={},
        ['internal/soulsearch/ui_tooltip']={SoulSearchTooltip=function(info) return info end},
        ['internal/soulsearch/ui/tooltip_agent']={
            TooltipAgent={new=function() return {update=function() end} end},
        },
        ['internal/soulsearch/screen_registry']=registry,
    }
    local globals={
        DEFAULT_NIL=nil,
        defclass=function(_, parent) return class(parent) end,
        print=function(text) table.insert(state.printed, text) end,
        df={
            unit={find=function(id) return units[id] end},
            global={game={main_interface={view_sheets={}}}},
        },
        dfhack={
            screen={getWindowSize=function() return options.width or 80, options.height or 25 end},
            gui={getWidget=function(_, name)
                state.widget_lookups=state.widget_lookups+1
                if name == 'Tabs' and options.unit_card_rect then
                    return {rect=options.unit_card_rect}
                end
                return nil
            end},
            println=function(text) table.insert(state.position_logs, text) end,
        },
        require=function(name)
            if name == 'gui' then return {ZScreenModal=base, FRAME_BOLD='bold'} end
            if name == 'gui.widgets' then return {
                Window=setmetatable({}, {__call=function(_, info) return window(info) end}),
                TextButton=setmetatable({}, {__call=function(_, info) return info end}),
            } end
            error('unexpected require: ' .. name)
        end,
        reqscript=function(name)
            return assert(modules[name], 'unexpected reqscript: ' .. name)
        end,
    }
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/internal/soulsearch/stats_popover.lua', globals),
        config, registry, state
end

function M.load_stats_overlay(repo_root, options)
    options = options or {}
    local state = {opens=0, lookups=0, errors={}}
    local base = {
        addviews=function(self, views)
            self.subviews={}
            for _, view in ipairs(views) do
                if view.view_id then self.subviews[view.view_id]=view end
            end
        end,
        onInput=function() return false end,
        onRenderFrame=function() end,
        render=function() end,
        updateLayout=function() end,
    }
    local function class(parent)
        local result = {super=parent or base, attrs={}}
        function result.ATTRS(attrs)
            for key, value in pairs(attrs) do result.attrs[key]=value end
        end
        return setmetatable(result, {
            __index=parent or base,
            __call=function(cls, info)
                local instance=info or {}
                local parent_metatable = parent and getmetatable(parent)
                if parent_metatable and parent_metatable.__call then
                    instance = parent(instance)
                end
                for key, value in pairs(cls.attrs) do
                    if instance[key] == nil then instance[key] = value end
                end
                setmetatable(instance, {__index=cls})
                if cls.init then cls.init(instance, info or {}) end
                return instance
            end,
        })
    end
    local active_unit_id = options.active_unit_id or
        (options.unit and options.unit.id) or -1
    local view_sheets = {active_id=active_unit_id}
    local config = {
        COLLAPSE_BUTTON_WIDTH=3,
        DEFAULT_SORT={key=nil, reverse=false, phase=0},
        OVERLAY_DEFAULT_SORT={key='value', reverse=true, phase=1},
        BUTTON_PLACEMENT={
            OUTSIDE_LEFT='outside-left',
            OUTSIDE_RIGHT='outside-right',
            INSIDE_LEFT='inside-left',
            INSIDE_RIGHT='inside-right',
        },
        DIRECTION={LEFT='left', RIGHT='right', UP='up', DOWN='down'},
        LOG_POSITIONING=false,
        resolve=function(width, height, rect, placements, positioned_panel)
            state.placements=placements
            state.unit_card_rect=rect
            state.positioned_panel=positioned_panel
            return state.layout or options.layout or {
                panel={l=43, t=12, w=32, h=12},
                button={l=72, t=11, w=3, h=1},
                direction=placements[1].direction,
            }
        end,
    }
    local popover = {get_subject=function(unit)
        state.lookups=state.lookups+1
        if options.subject_error then return nil, options.subject_error end
        return {unit=unit, unit_id=unit.id}, nil
    end}
    local function window(info)
        local subviews={}
        for _, view in ipairs(info.subviews or {}) do subviews[view.view_id]=view end
        info.subviews=subviews
        return info
    end
    local function label(info)
        info.widget_kind='Label'
        function info:setText(text) self.text=text end
        return info
    end
    local function stats_panel(info)
        function info:set_subject(subject)
            self.subject=subject
            state.subjects=(state.subjects or 0)+1
        end
        return info
    end
    local globals = {
        DEFAULT_NIL=nil,
        defclass=function(_, parent) return class(parent) end,
        df={
            global={game={main_interface={view_sheets=view_sheets}}},
            unit={find=function(id)
                if options.unit and id == options.unit.id then return options.unit end
                return nil
            end},
        },
        dfhack={
            gui={
                getCurViewscreen=function() return options.screen or {} end,
                getFocusStrings=function(screen)
                    return (options.focuses_by_screen or {})[screen] or options.focuses or {}
                end,
                getWidget=function(_, name)
                    if name == 'Tabs' and options.unit_card_rect then
                        return {rect=options.unit_card_rect}
                    end
                end,
                getWidgetChildren=function(container)
                    if container == view_sheets then return options.unit_card_children or {} end
                    return (options.nested_widget_children or {})[container] or {}
                end,
            },
            screen={
                getWindowSize=function() return options.width or 120, options.height or 40 end,
                readTile=function(x, y)
                    local row = (options.screen_rows or {})[y] or ''
                    return {ch=row:byte(x + 1) or 32}
                end,
            },
            printerr=function(error) table.insert(state.errors, error) end,
            println=function(text) table.insert(state.position_logs or {}, text) end,
        },
        require=function(name)
            if name == 'plugins.overlay' then return {OverlayWidget=base} end
            if name == 'gui' then return {FRAME_INTERIOR='interior'} end
            if name == 'gui.widgets' then return {
                Window=setmetatable({}, {__call=function(_, info) return window(info) end}),
                Label=setmetatable({}, {__call=function(_, info) return label(info) end}),
                TextButton=setmetatable({}, {__call=function(_, info) return info end}),
            } end
            error('unexpected require: ' .. name)
        end,
        reqscript=function(name)
            if name == 'internal/soulsearch/ui/widget_extensions' then return {} end
            if name == 'internal/soulsearch/stats_popover_config' then return config end
            if name == 'internal/soulsearch/stats_popover' then return popover end
            if name == 'internal/soulsearch/ui_glyphs' then
                return {CP437_ARROW_RIGHT=string.char(16), CP437_ARROW_LEFT=string.char(17),
                    CP437_ARROW_UP=string.char(24), CP437_ARROW_DOWN=string.char(25),
                    CP437_HORIZONTAL_LINE=string.char(196)}
            end
            if name == 'internal/soulsearch/ui/unit_stats_list' then
                return {UnitStatsList=stats_panel}
            end
            if name == 'internal/soulsearch/ui_tooltip' then
                return {SoulSearchTooltip=function(info) return info end}
            end
            if name == 'internal/soulsearch/ui/tooltip_agent' then
                return {TooltipAgent={new=function() return {update=function()
                    state.tooltip_updates=(state.tooltip_updates or 0)+1
                end} end}}
            end
            error('unexpected reqscript: ' .. name)
        end,
    }
    return module_loader.load(repo_root,
        'src/scripts_modinstalled/soulsearch-stats-overlay.lua', globals), state, config
end

return M
