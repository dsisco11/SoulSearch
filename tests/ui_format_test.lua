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

    test.case('UI format: result row snapshot preserves widths', function()
        local text = format.format_result_choice{
            name=('A'):rep(50),
            profession='Stoneworker',
        }
        test.assert_equal(('A'):rep(42) .. '... Stoneworker', text)
        test.assert_equal(57, #text)
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
        test.assert_sequence({'Strength'}, token_texts(filter))
        test.assert_sequence({string.char(16) .. ' ', 'Mining'}, token_texts(skill))
        test.assert_sequence({'Mining Skills'}, token_texts(category))
        test.assert_equal('lightgreen', filter[1].pen)
        test.assert_equal('yellow', skill[2].pen)
    end)

    test.case('UI format: stats header and values preserve glyphs and padding', function()
        local tokens = {}
        format.append_stats_column_header_tokens(tokens, 'value', true)
        test.assert_equal('Stat                       ', tokens[1].text)
        test.assert_equal('Delta ' .. string.char(25), tokens[2].text)
        test.assert_equal(string.char(196):rep(24), tokens[4].text)
        test.assert_equal(string.char(196):rep(5), tokens[6].text)
        local record_tokens = {}
        format.append_attribute_record_tokens(record_tokens, {
            label='Strength', deviation=250, tier_distance=2, pen='physical'})
        test.assert_equal('  Strength                 ', record_tokens[1].text)
        test.assert_equal('+250', record_tokens[2].text)
        test.assert_equal('lightgreen', record_tokens[2].pen)
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
end
