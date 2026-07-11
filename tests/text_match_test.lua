local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local text_match = soulsearch_env.load_text_match(repo_root)
    test.case('text matching: nil and coercion contract', function()
        test.assert_true(text_match.contains(nil, nil))
        test.assert_true(text_match.contains(123, '23'))
        test.assert_true(text_match.contains('Mining', 'NIN'))
        test.assert_false(text_match.contains(false, 'fal'))
        test.assert_false(text_match.contains(nil, 'x'))
    end)
end
