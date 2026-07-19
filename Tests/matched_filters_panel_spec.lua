local env = require('support.soulsearch_env')

local function token_texts(tokens)
    local texts = {}
    for _, token in ipairs(tokens) do
        if token.text then table.insert(texts, token.text) end
    end
    return texts
end

local function contains(texts, expected)
    for _, text in ipairs(texts) do
        if text == expected then return true end
    end
    return false
end

local root = require('support.repo_root')

describe('matched filters panel', function()

    it('matched filters panel: owns the selected-filter title and criteria list', function()
        local MatchedFiltersPanel = env.load_matched_filters_panel(root)
        local panel = MatchedFiltersPanel{subject={row={}, filter_criteria={{
            label='Mining', kind='skill', direction='high', value=2.35,
            deviation=2.35, tier_distance=2, matched=true,
        }}}}

        local texts = token_texts(panel.subviews.filters.text)
        assert.are.equal('Selected filters', texts[1])
        assert.is_truthy(contains(texts, '[+] '))
        assert.are.equal(0, panel.subviews.filters.frame.b)
        assert.are.equal(1, panel:get_height())

        panel:set_subject({row={}, filter_criteria={}})
        assert.are.equal(0, panel:get_height())
    end)

end)
