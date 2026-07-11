local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local descriptions = soulsearch_env.load_attribute_descriptions(repo_root)

    test.case('Attribute descriptions: explain known attributes and traits', function()
        test.assert_equal(
            'Muscular power for carrying, melee force, and movement.',
            descriptions.get_tooltip('physical_attribute', 'STRENGTH'))
        test.assert_equal(
            'Ability to concentrate on a task.',
            descriptions.get_tooltip('mental_attribute', 'FOCUS'))
        test.assert_equal(
            'Willingness to help others without reward.',
            descriptions.get_tooltip('trait', 'ALTRUISM'))
        test.assert_equal(
            'Tendency to reject advice and rely on one’s own counsel.',
            descriptions.get_tooltip('trait', 'DISDAIN_ADVICE'))
        test.assert_equal(
            'Sensitivity to art and natural beauty.',
            descriptions.get_tooltip('trait', 'ART_INCLINED'))
        test.assert_equal(
            'Tendency to become angry.',
            descriptions.get_tooltip('trait', 'ANGER_PROPENSITY'))
    end)

    test.case('Attribute descriptions: future enum values receive a fallback', function()
        test.assert_equal(
            'A personality trait that shapes behavior and social interaction.',
            descriptions.get_tooltip('trait', 'FUTURE_TRAIT'))
    end)
end
