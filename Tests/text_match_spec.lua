local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('text match', function()

    local text_match = soulsearch_env.load_text_match(repo_root)
    it('text matching: nil and coercion contract', function()
        assert.is_truthy(text_match.contains(nil, nil))
        assert.is_truthy(text_match.contains(123, '23'))
        assert.is_truthy(text_match.contains('Mining', 'NIN'))
        assert.is_falsy(text_match.contains(false, 'fal'))
        assert.is_falsy(text_match.contains(nil, 'x'))
    end)

end)
