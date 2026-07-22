local soulsearch_env = require('support.soulsearch_env')

local function token_texts(tokens)
    local texts = {}
    for _, token in ipairs(tokens) do
        table.insert(texts, type(token) == 'table' and token.text or token)
    end
    return texts
end

local repo_root = require('support.repo_root')

describe('UI format', function()

    local format = soulsearch_env.load_ui_format(repo_root)
    local result_presenter = soulsearch_env.load_result_presenter(repo_root)
    local filter_presenter = soulsearch_env.load_filter_presenter(repo_root)

    it('Result presenter: snapshots empty and sorted result displays', function()
        local empty = result_presenter.present({}, nil, false)
        assert.are.equal('Results (0)', empty.title)
        assert.are.same({}, empty.choices)
        local display = result_presenter.present({{
            name='Urist', profession='Miner', unit_id=7,
        }}, 'name', true)
        assert.are.equal('Results (1)', display.title)
        assert.are.equal('Urist', display.choices[1].result.name)
        assert.are.equal('Name ' .. string.char(25), display.columns:sub(1, 6))
    end)

    it('Filter presenter: selected, grouped, filtered, and empty choices', function()
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
        assert.are.equal('Strength', active[1].descriptor.label)
        local available = filter_presenter.present_available(descriptors, filters,
            'min', 'No matching attributes.')
        assert.are.equal('Mining', available[1].descriptor.label)
        local selected = filter_presenter.present_available(descriptors, filters,
            'str', 'No matching attributes.')
        assert.is_truthy(selected[1].selected)
        assert.are.same({string.char(16) .. '  ', 'Strength'},
            token_texts(selected[1].text))
        local skills = filter_presenter.present_skills(descriptors, filters,
            '', {'Labor'})
        assert.are.equal('Labor', skills[1].search_key)
        assert.are.equal('Mining', skills[2].descriptor.label)
        assert.is_truthy(skills[2].selected)
        local races = filter_presenter.present_races({descriptors[3], descriptors[4]}, filters, '')
        assert.are.equal('', races[2].text)
        assert.is_truthy(races[3].selected)
        assert.are.equal('No matching attributes.', filter_presenter.present_available(
            descriptors, filters, 'zzz', 'No matching attributes.')[1].text)
    end)

    it('Filter presenter: candidate filters do not consume ranking priority', function()
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
        assert.are.same({'   ', '   '}, {
            token_texts(active[1].text)[5], token_texts(active[1].text)[6],
        })
        assert.are.same({'   ', '   '}, {
            token_texts(active[2].text)[5], token_texts(active[2].text)[6],
        })
        assert.is_falsy(token_texts(active[3].text)[5] == '   ')
        assert.is_falsy(token_texts(active[3].text)[6] == '   ')
        local scopes = filter_presenter.present_available({descriptors[1]}, {
            {id='unit_scope:citizens', direction='high'},
        }, 'cit', 'No matching unit scopes.')
        assert.is_truthy(scopes[1].selected)
        assert.are.equal(string.char(16) .. '  ', token_texts(scopes[1].text)[1])
    end)

    it('Filter presenter: preset sections are stable', function()
        local presets = filter_presenter.present_presets({'Saved'},
            {{id='miner', label='Miner'}}, {{id='soldier', label='Soldier'}},
            {{id='skill:mine', label='Mining'}}, '')
        assert.are.same({'Custom presets', '  Saved', 'Role presets', '  Miner',
            'Combat presets', '  Soldier', 'Skill presets', '  Mining'},
            (function() local texts = {}; for _, choice in ipairs(presets) do
                table.insert(texts, choice.text) end; return texts end)())
    end)

    it('UI format: result row snapshot preserves widths', function()
        local text = format.format_result_choice{
            name=('A'):rep(50),
            unit_id=12345,
            profession='Stoneworker',
        }
        assert.are.equal(('A'):rep(32) .. '... Stoneworker' ..
            (' '):rep(7) .. ' #12345' .. (' '):rep(3), text)
        assert.are.equal(64, #text)
        assert.are.equal('Name' .. (' '):rep(31) .. ' Profession' ..
            (' '):rep(8) .. ' Unit ID' .. (' '):rep(2),
            format.format_result_columns())
        assert.are.equal('Name ' .. string.char(24),
            format.format_result_columns('name', false):sub(1, 6))
        assert.are.equal('Unit ID ' .. string.char(25),
            format.format_result_columns('unit_id', true):sub(56, 64))
    end)

    it('UI format: tooltip text wraps without truncation', function()
        assert.are.same({
            'Difference from the',
            'attribute average.',
        }, format.wrap_text('Difference from the attribute average.', 20))
        assert.are.same({''}, format.wrap_text('', 20))
    end)

    it('UI format: active filter snapshot uses metadata labels', function()
        local tokens = format.format_active_filter_choice(
            {label='Mining', kind='skill'},
            'low',
            2,
            3)
        assert.are.same(
            {'Mining', (' '):rep(15), '[+]', '[-]', '[' .. string.char(30) .. ']',
             '[' .. string.char(31) .. ']', '[x]'},
            token_texts(tokens))
        assert.are.equal('lightred', tokens[4].pen)
        assert.are.equal('white', tokens[5].pen)
        assert.are.equal('white', tokens[6].pen)
    end)

    it('UI format: picker snapshots preserve CP437 and category pens', function()
        local filter = format.format_available_filter_choice{
            label='Strength', kind='physical_attribute'}
        local skill = format.format_available_skill_choice{
            label='Mining', kind='skill'}
        local category = format.format_skill_category_choice('Mining Skills')
        assert.are.same({'   ', 'Strength'}, token_texts(filter))
        assert.are.same({'   ', 'Mining'}, token_texts(skill))
        assert.are.same({'Mining Skills'}, token_texts(category))
        assert.are.equal('darkgrey', filter[1].pen)
        assert.are.equal('yellow', skill[2].pen)
        local selected_filter = format.format_available_filter_choice({
            label='Strength', kind='physical_attribute'}, true)
        assert.are.same({string.char(16) .. '  ', 'Strength'},
            token_texts(selected_filter))
        assert.are.equal('lightgreen', selected_filter[1].pen)
    end)

    it('UI format: candidate rows reuse plus and minus without movement', function()
        local tokens = format.format_active_filter_choice(
            {label='Humanoids', kind='race', behavior='candidate'},
            'low',
            nil,
            0)
        assert.are.same(
            {'Humanoids', (' '):rep(12), '[+]', '[-]', '   ', '   ', '[x]'},
            token_texts(tokens))
        assert.are.equal('lightcyan', tokens[1].pen)
        assert.are.equal('lightred', tokens[4].pen)
        assert.are.equal('darkgrey', tokens[5].pen)
        assert.are.equal('darkgrey', tokens[6].pen)
    end)

    it('UI format: unit scopes use the candidate color and action model', function()
        local available = format.format_available_filter_choice({
            label='Visitors', kind='unit_scope', behavior='candidate',
        }, true)
        assert.are.equal('cyan', available[2].pen)
        local active = format.format_active_filter_choice({
            label='Visitors', kind='unit_scope', behavior='candidate',
        }, 'high', nil, 0)
        assert.are.same({'Visitors', (' '):rep(13), '[+]', '[-]', '   ', '   ', '[x]'},
            token_texts(active))
    end)

    it('UI format: stats header and values preserve glyphs and padding', function()
        local tokens = {}
        format.append_stats_column_header_tokens(tokens, 'value', true)
        assert.are.equal('Stat' .. (' '):rep(22), tokens[1].text)
        assert.are.equal('Delta ' .. string.char(25), tokens[2].text)
        assert.are.equal(string.char(196):rep(23), tokens[4].text)
        assert.are.equal(string.char(196):rep(5), tokens[6].text)
        local record_tokens = {}
        format.append_attribute_record_tokens(record_tokens, {
            label='Strength', deviation=250, tier_distance=2, pen='physical'})
        assert.are.equal('  Strength' .. (' '):rep(16), record_tokens[1].text)
        assert.are.equal('+250', record_tokens[2].text)
        assert.are.equal('lightgreen', record_tokens[2].pen)
        local compact_tokens = {}
        format.append_attribute_record_tokens(compact_tokens, {
            label='Strength', deviation=250, tier_distance=2, pen='physical'},
            {label_width=26, label_inset=0})
        assert.are.equal('Strength' .. (' '):rep(19), compact_tokens[1].text)
        local scrolling_tokens = {}
        format.append_attribute_record_tokens(scrolling_tokens, {
            label='Strength', deviation=250, tier_distance=2, pen='physical'},
            {label_width=24, label_inset=0})
        assert.are.equal('Strength' .. (' '):rep(17), scrolling_tokens[1].text)
    end)

    it('UI format: panel title rules use CP437 horizontal lines', function()
        assert.are.equal(string.char(196):rep(7),
            format.get_title_underline('Results'))
    end)

    it('UI format: selected filter tokens preserve direction and skill value', function()
        local tokens = format.format_stats_header{
            row={}, name='Urist', profession='Miner',
            filter_criteria={{
                label='Mining', kind='skill', direction='low', value=2.35,
                deviation=2.35, tier_distance=2, matched=false,
            }},
        }
        local texts = token_texts(tokens)
        assert.are.equal('Selected filters', texts[6])
        assert.are.equal('[-] ', texts[11])
        assert.are.equal('   2.3', texts[13])
        assert.are.equal('darkgrey', tokens[11].pen)
    end)

    it('UI format: stats empty and fallback copy is generic to units', function()
        local empty = format.format_stats_header(nil)
        assert.are.equal('No unit selected.', empty[1].text)

        local fallback = format.format_stats_header{
            row={}, filter_criteria={},
        }
        assert.are.equal('Unknown unit', fallback[1].text)
    end)

end)