local soulsearch_env = require('support.soulsearch_env')

local function token_texts(tokens)
    local texts = {}
    for _, token in ipairs(tokens) do
        table.insert(texts, type(token) == 'table' and token.text or token)
    end
    return texts
end

return function(test, repo_root)
    local format = soulsearch_env.load_ui_format(repo_root)
    local result_presenter = soulsearch_env.load_result_presenter(repo_root)
    local filter_presenter = soulsearch_env.load_filter_presenter(repo_root)

    test.case('Result presenter: snapshots empty and sorted result displays', function()
        local empty = result_presenter.present({}, nil, false)
        test.assert_equal('Results (0)', empty.title)
        test.assert_sequence({}, empty.choices)
        local display = result_presenter.present({{
            name='Urist', profession='Miner', unit_id=7,
        }}, 'name', true)
        test.assert_equal('Results (1)', display.title)
        test.assert_equal('Urist', display.choices[1].result.name)
        test.assert_equal('Name ' .. string.char(25), display.columns:sub(1, 6))
    end)

    test.case('Filter presenter: selected, grouped, filtered, and empty choices', function()
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
        test.assert_equal('Strength', active[1].descriptor.label)
        local available = filter_presenter.present_available(descriptors, filters,
            'min', 'No matching attributes.')
        test.assert_equal('Mining', available[1].descriptor.label)
        local selected = filter_presenter.present_available(descriptors, filters,
            'str', 'No matching attributes.')
        test.assert_true(selected[1].selected)
        test.assert_sequence({string.char(16) .. '  ', 'Strength'},
            token_texts(selected[1].text))
        local skills = filter_presenter.present_skills(descriptors, filters,
            '', {'Labor'})
        test.assert_equal('Labor', skills[1].search_key)
        test.assert_equal('Mining', skills[2].descriptor.label)
        test.assert_true(skills[2].selected)
        local races = filter_presenter.present_races({descriptors[3], descriptors[4]}, filters, '')
        test.assert_equal('', races[2].text)
        test.assert_true(races[3].selected)
        test.assert_equal('No matching attributes.', filter_presenter.present_available(
            descriptors, filters, 'zzz', 'No matching attributes.')[1].text)
    end)

    test.case('Filter presenter: preset sections and selected scope are stable', function()
        local presets = filter_presenter.present_presets({'Saved'},
            {{id='miner', label='Miner'}}, {{id='soldier', label='Soldier'}},
            {{id='skill:mine', label='Mining'}}, '')
        test.assert_sequence({'Custom presets', '  Saved', 'Role presets', '  Miner',
            'Combat presets', '  Soldier', 'Skill presets', '  Mining'},
            (function() local texts = {}; for _, choice in ipairs(presets) do
                table.insert(texts, choice.text) end; return texts end)())
        local _, selected, label = filter_presenter.present_scopes({
            {label='Residents', value='residents'}, {label='Visitors', value='visitors'},
        }, 'visitors')
        test.assert_equal(2, selected)
        test.assert_equal('Visitors', label)
    end)

    test.case('UI format: result row snapshot preserves widths', function()
        local text = format.format_result_choice{
            name=('A'):rep(50),
            unit_id=12345,
            profession='Stoneworker',
        }
        test.assert_equal(('A'):rep(32) .. '... Stoneworker' ..
            (' '):rep(7) .. ' #12345' .. (' '):rep(3), text)
        test.assert_equal(64, #text)
        test.assert_equal('Name' .. (' '):rep(31) .. ' Profession' ..
            (' '):rep(8) .. ' Unit ID' .. (' '):rep(2),
            format.format_result_columns())
        test.assert_equal('Name ' .. string.char(24),
            format.format_result_columns('name', false):sub(1, 6))
        test.assert_equal('Unit ID ' .. string.char(25),
            format.format_result_columns('unit_id', true):sub(56, 64))
        test.assert_equal('Search for: Visitors',
            format.format_unit_scope_control('Visitors'))
        test.assert_equal(string.char(16) .. ' Residents',
            format.format_unit_scope_choice('Residents', true))
        test.assert_equal('  Visitors',
            format.format_unit_scope_choice('Visitors', false))
    end)

    test.case('UI format: tooltip text wraps without truncation', function()
        test.assert_sequence({
            'Difference from the',
            'attribute average.',
        }, format.wrap_text('Difference from the attribute average.', 20))
        test.assert_sequence({''}, format.wrap_text('', 20))
    end)

    test.case('UI format: active filter snapshot uses metadata labels', function()
        local tokens = format.format_active_filter_choice(
            {label='Mining', kind='skill'},
            'low',
            2,
            3)
        test.assert_sequence(
            {'Mining', (' '):rep(15), '[+]', '[-]', '[' .. string.char(30) .. ']',
             '[' .. string.char(31) .. ']', '[x]'},
            token_texts(tokens))
        test.assert_equal('lightred', tokens[4].pen)
        test.assert_equal('white', tokens[5].pen)
        test.assert_equal('white', tokens[6].pen)
    end)

    test.case('UI format: picker snapshots preserve CP437 and category pens', function()
        local filter = format.format_available_filter_choice{
            label='Strength', kind='physical_attribute'}
        local skill = format.format_available_skill_choice{
            label='Mining', kind='skill'}
        local category = format.format_skill_category_choice('Mining Skills')
        test.assert_sequence({'   ', 'Strength'}, token_texts(filter))
        test.assert_sequence({'   ', 'Mining'}, token_texts(skill))
        test.assert_sequence({'Mining Skills'}, token_texts(category))
        test.assert_equal('darkgrey', filter[1].pen)
        test.assert_equal('yellow', skill[2].pen)
        local selected_filter = format.format_available_filter_choice({
            label='Strength', kind='physical_attribute'}, true)
        test.assert_sequence({string.char(16) .. '  ', 'Strength'},
            token_texts(selected_filter))
        test.assert_equal('lightgreen', selected_filter[1].pen)
    end)

    test.case('UI format: race rows reuse plus and minus without movement', function()
        local tokens = format.format_active_filter_choice(
            {label='Humanoids', kind='race'},
            'low',
            nil,
            0)
        test.assert_sequence(
            {'Humanoids', (' '):rep(12), '[+]', '[-]', '   ', '   ', '[x]'},
            token_texts(tokens))
        test.assert_equal('lightcyan', tokens[1].pen)
        test.assert_equal('lightred', tokens[4].pen)
        test.assert_equal('darkgrey', tokens[5].pen)
        test.assert_equal('darkgrey', tokens[6].pen)
    end)

    test.case('UI format: stats header and values preserve glyphs and padding', function()
        local tokens = {}
        format.append_stats_column_header_tokens(tokens, 'value', true)
        test.assert_equal('Stat' .. (' '):rep(22), tokens[1].text)
        test.assert_equal('Delta ' .. string.char(25), tokens[2].text)
        test.assert_equal(string.char(196):rep(23), tokens[4].text)
        test.assert_equal(string.char(196):rep(5), tokens[6].text)
        local record_tokens = {}
        format.append_attribute_record_tokens(record_tokens, {
            label='Strength', deviation=250, tier_distance=2, pen='physical'})
        test.assert_equal('  Strength' .. (' '):rep(16), record_tokens[1].text)
        test.assert_equal('+250', record_tokens[2].text)
        test.assert_equal('lightgreen', record_tokens[2].pen)
        local compact_tokens = {}
        format.append_attribute_record_tokens(compact_tokens, {
            label='Strength', deviation=250, tier_distance=2, pen='physical'},
            {label_width=26, label_inset=0})
        test.assert_equal('Strength' .. (' '):rep(19), compact_tokens[1].text)
        local scrolling_tokens = {}
        format.append_attribute_record_tokens(scrolling_tokens, {
            label='Strength', deviation=250, tier_distance=2, pen='physical'},
            {label_width=24, label_inset=0})
        test.assert_equal('Strength' .. (' '):rep(17), scrolling_tokens[1].text)
    end)

    test.case('UI format: panel title rules use CP437 horizontal lines', function()
        test.assert_equal(string.char(196):rep(7),
            format.get_title_underline('Results'))
    end)

    test.case('UI format: selected filter tokens preserve direction and skill value', function()
        local tokens = format.format_stats_header{
            row={}, name='Urist', profession='Miner',
            filter_criteria={{
                label='Mining', kind='skill', direction='low', value=2.35,
                deviation=2.35, tier_distance=2, matched=false,
            }},
        }
        local texts = token_texts(tokens)
        test.assert_equal('Selected filters', texts[6])
        test.assert_equal('[-] ', texts[11])
        test.assert_equal('   2.3', texts[13])
        test.assert_equal('darkgrey', tokens[11].pen)
    end)

    test.case('UI format: stats empty and fallback copy is generic to units', function()
        local empty = format.format_stats_header(nil)
        test.assert_equal('No unit selected.', empty[1].text)

        local fallback = format.format_stats_header{
            row={}, filter_criteria={},
        }
        test.assert_equal('Unknown unit', fallback[1].text)
    end)
end
