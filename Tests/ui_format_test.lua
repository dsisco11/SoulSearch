local soulsearch_env = require('support.soulsearch_env')

local function token_texts(tokens)
    local texts = {}
    for _, token in ipairs(tokens) do
        table.insert(texts, type(token) == 'table' and token.text or token)
    end
    return texts
end

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local format = soulsearch_env.load_ui_format(repo_root)
    local result_presenter = soulsearch_env.load_result_presenter(repo_root)
    local filter_presenter = soulsearch_env.load_filter_presenter(repo_root)

    add_test('Result presenter: snapshots empty and sorted result displays', function()
        local empty = result_presenter.present({}, nil, false)
        luaunit.assertIs('Results (0)', empty.title)
        luaunit.assertEquals({}, empty.choices)
        local display = result_presenter.present({{
            name='Urist', profession='Miner', unit_id=7,
        }}, 'name', true)
        luaunit.assertIs('Results (1)', display.title)
        luaunit.assertIs('Urist', display.choices[1].result.name)
        luaunit.assertIs('Name ' .. string.char(25), display.columns:sub(1, 6))
    end)

    add_test('Filter presenter: selected, grouped, filtered, and empty choices', function()
        local descriptors = {
            {id='attribute:strength', label='Strength', kind='physical_attribute'},
            {id='skill:mining', label='Mining', kind='skill', category='Labor'},
            {id='race_group:humanoids', label='Humanoids', kind='race'},
            {id='race:dwarf', label='Dwarves', kind='race'},
        }
        local filters = {
            {id='attribute:strength', direction='high'},
            {id='skill:mining', direction='high'},
            {id='race:dwarf', direction='high'},
        }
        local active = filter_presenter.present_active(descriptors, filters)
        luaunit.assertIs('Strength', active[1].descriptor.label)
        local available = filter_presenter.present_available(descriptors, filters,
            'min', 'No matching attributes.')
        luaunit.assertIs('Mining', available[1].descriptor.label)
        local selected = filter_presenter.present_available(descriptors, filters,
            'str', 'No matching attributes.')
        luaunit.assertEvalToTrue(selected[1].selected)
        luaunit.assertEquals({string.char(16) .. '  ', 'Strength'},
            token_texts(selected[1].text))
        local skills = filter_presenter.present_skills(descriptors, filters,
            '', {'Labor'})
        luaunit.assertIs('Labor', skills[1].search_key)
        luaunit.assertIs('Mining', skills[2].descriptor.label)
        luaunit.assertEvalToTrue(skills[2].selected)
        local races = filter_presenter.present_races({descriptors[3], descriptors[4]}, filters, '')
        luaunit.assertIs('', races[2].text)
        luaunit.assertEvalToTrue(races[3].selected)
        luaunit.assertIs('No matching attributes.', filter_presenter.present_available(
            descriptors, filters, 'zzz', 'No matching attributes.')[1].text)
    end)

    add_test('Filter presenter: candidate filters do not consume ranking priority', function()
        local descriptors = {
            {id='unit_scope:citizens', label='Citizens', kind='unit_scope', behavior='candidate'},
            {id='race_group:humanoids', label='Humanoids', kind='race', behavior='candidate'},
            {id='skill:mining', label='Mining', kind='skill', behavior='ranking'},
        }
        local active = filter_presenter.present_active(descriptors, {
            {id='unit_scope:citizens', direction='high'},
            {id='race_group:humanoids', direction='low'},
            {id='skill:mining', direction='high'},
        })
        luaunit.assertEquals({'   ', '   '}, {
            token_texts(active[1].text)[5], token_texts(active[1].text)[6],
        })
        luaunit.assertEquals({'   ', '   '}, {
            token_texts(active[2].text)[5], token_texts(active[2].text)[6],
        })
        luaunit.assertEvalToFalse(token_texts(active[3].text)[5] == '   ')
        luaunit.assertEvalToFalse(token_texts(active[3].text)[6] == '   ')
        local scopes = filter_presenter.present_available({descriptors[1]}, {
            {id='unit_scope:citizens', direction='high'},
        }, 'cit', 'No matching unit scopes.')
        luaunit.assertEvalToTrue(scopes[1].selected)
        luaunit.assertIs(string.char(16) .. '  ', token_texts(scopes[1].text)[1])
    end)

    add_test('Filter presenter: preset sections are stable', function()
        local presets = filter_presenter.present_presets({'Saved'},
            {{id='miner', label='Miner'}}, {{id='soldier', label='Soldier'}},
            {{id='skill:mine', label='Mining'}}, '')
        luaunit.assertEquals({'Custom presets', '  Saved', 'Role presets', '  Miner',
            'Combat presets', '  Soldier', 'Skill presets', '  Mining'},
            (function() local texts = {}; for _, choice in ipairs(presets) do
                table.insert(texts, choice.text) end; return texts end)())
    end)

    add_test('UI format: result row snapshot preserves widths', function()
        local text = format.format_result_choice{
            name=('A'):rep(50),
            unit_id=12345,
            profession='Stoneworker',
        }
        luaunit.assertIs(('A'):rep(32) .. '... Stoneworker' ..
            (' '):rep(7) .. ' #12345' .. (' '):rep(3), text)
        luaunit.assertIs(64, #text)
        luaunit.assertIs('Name' .. (' '):rep(31) .. ' Profession' ..
            (' '):rep(8) .. ' Unit ID' .. (' '):rep(2),
            format.format_result_columns())
        luaunit.assertIs('Name ' .. string.char(24),
            format.format_result_columns('name', false):sub(1, 6))
        luaunit.assertIs('Unit ID ' .. string.char(25),
            format.format_result_columns('unit_id', true):sub(56, 64))
    end)

    add_test('UI format: tooltip text wraps without truncation', function()
        luaunit.assertEquals({
            'Difference from the',
            'attribute average.',
        }, format.wrap_text('Difference from the attribute average.', 20))
        luaunit.assertEquals({''}, format.wrap_text('', 20))
    end)

    add_test('UI format: active filter snapshot uses metadata labels', function()
        local tokens = format.format_active_filter_choice(
            {label='Mining', kind='skill'},
            'low',
            2,
            3)
        luaunit.assertEquals(
            {'Mining', (' '):rep(15), '[+]', '[-]', '[' .. string.char(30) .. ']',
             '[' .. string.char(31) .. ']', '[x]'},
            token_texts(tokens))
        luaunit.assertIs('lightred', tokens[4].pen)
        luaunit.assertIs('white', tokens[5].pen)
        luaunit.assertIs('white', tokens[6].pen)
    end)

    add_test('UI format: picker snapshots preserve CP437 and category pens', function()
        local filter = format.format_available_filter_choice{
            label='Strength', kind='physical_attribute'}
        local skill = format.format_available_skill_choice{
            label='Mining', kind='skill'}
        local category = format.format_skill_category_choice('Mining Skills')
        luaunit.assertEquals({'   ', 'Strength'}, token_texts(filter))
        luaunit.assertEquals({'   ', 'Mining'}, token_texts(skill))
        luaunit.assertEquals({'Mining Skills'}, token_texts(category))
        luaunit.assertIs('darkgrey', filter[1].pen)
        luaunit.assertIs('yellow', skill[2].pen)
        local selected_filter = format.format_available_filter_choice({
            label='Strength', kind='physical_attribute'}, true)
        luaunit.assertEquals({string.char(16) .. '  ', 'Strength'},
            token_texts(selected_filter))
        luaunit.assertIs('lightgreen', selected_filter[1].pen)
    end)

    add_test('UI format: candidate rows reuse plus and minus without movement', function()
        local tokens = format.format_active_filter_choice(
            {label='Humanoids', kind='race', behavior='candidate'},
            'low',
            nil,
            0)
        luaunit.assertEquals(
            {'Humanoids', (' '):rep(12), '[+]', '[-]', '   ', '   ', '[x]'},
            token_texts(tokens))
        luaunit.assertIs('lightcyan', tokens[1].pen)
        luaunit.assertIs('lightred', tokens[4].pen)
        luaunit.assertIs('darkgrey', tokens[5].pen)
        luaunit.assertIs('darkgrey', tokens[6].pen)
    end)

    add_test('UI format: unit scopes use the candidate color and action model', function()
        local available = format.format_available_filter_choice({
            label='Visitors', kind='unit_scope', behavior='candidate',
        }, true)
        luaunit.assertIs('cyan', available[2].pen)
        local active = format.format_active_filter_choice({
            label='Visitors', kind='unit_scope', behavior='candidate',
        }, 'high', nil, 0)
        luaunit.assertEquals({'Visitors', (' '):rep(13), '[+]', '[-]', '   ', '   ', '[x]'},
            token_texts(active))
    end)

    add_test('UI format: stats header and values preserve glyphs and padding', function()
        local tokens = {}
        format.append_stats_column_header_tokens(tokens, 'value', true)
        luaunit.assertIs('Stat' .. (' '):rep(22), tokens[1].text)
        luaunit.assertIs('Delta ' .. string.char(25), tokens[2].text)
        luaunit.assertIs(string.char(196):rep(23), tokens[4].text)
        luaunit.assertIs(string.char(196):rep(5), tokens[6].text)
        local record_tokens = {}
        format.append_attribute_record_tokens(record_tokens, {
            label='Strength', deviation=250, tier_distance=2, pen='physical'})
        luaunit.assertIs('  Strength' .. (' '):rep(16), record_tokens[1].text)
        luaunit.assertIs('+250', record_tokens[2].text)
        luaunit.assertIs('lightgreen', record_tokens[2].pen)
        local compact_tokens = {}
        format.append_attribute_record_tokens(compact_tokens, {
            label='Strength', deviation=250, tier_distance=2, pen='physical'},
            {label_width=26, label_inset=0})
        luaunit.assertIs('Strength' .. (' '):rep(19), compact_tokens[1].text)
        local scrolling_tokens = {}
        format.append_attribute_record_tokens(scrolling_tokens, {
            label='Strength', deviation=250, tier_distance=2, pen='physical'},
            {label_width=24, label_inset=0})
        luaunit.assertIs('Strength' .. (' '):rep(17), scrolling_tokens[1].text)
    end)

    add_test('UI format: panel title rules use CP437 horizontal lines', function()
        luaunit.assertIs(string.char(196):rep(7),
            format.get_title_underline('Results'))
    end)

    add_test('UI format: selected filter tokens preserve direction and skill value', function()
        local tokens = format.format_stats_header{
            row={}, name='Urist', profession='Miner',
            filter_criteria={{
                label='Mining', kind='skill', direction='low', value=2.35,
                deviation=2.35, tier_distance=2, matched=false,
            }},
        }
        local texts = token_texts(tokens)
        luaunit.assertIs('Selected filters', texts[6])
        luaunit.assertIs('[-] ', texts[11])
        luaunit.assertIs('   2.3', texts[13])
        luaunit.assertIs('darkgrey', tokens[11].pen)
    end)

    add_test('UI format: stats empty and fallback copy is generic to units', function()
        local empty = format.format_stats_header(nil)
        luaunit.assertIs('No unit selected.', empty[1].text)

        local fallback = format.format_stats_header{
            row={}, filter_criteria={},
        }
        luaunit.assertIs('Unknown unit', fallback[1].text)
    end)

return native_tests
