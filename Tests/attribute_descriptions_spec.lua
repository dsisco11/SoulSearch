local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('attribute descriptions', function()

    local descriptions = soulsearch_env.load_attribute_descriptions(repo_root)

    it('Attribute descriptions: explain known attributes and traits', function()
        assert.are.equal(
            'Muscular power for carrying, melee force, and movement.',
            descriptions.get_tooltip('physical_attribute', 'STRENGTH'))
        assert.are.equal(
            'Affects close combat and some labor skills; delays suffocation.',
            descriptions.get_tooltip('physical_attribute', 'TOUGHNESS'))
        assert.are.equal(
            'Ability to concentrate on a task.',
            descriptions.get_tooltip('mental_attribute', 'FOCUS'))
        assert.are.equal(
            'Willingness to help others without reward.',
            descriptions.get_tooltip('trait', 'ALTRUISM'))
        assert.are.equal(
            "Tendency to reject advice and rely on one's own counsel.",
            descriptions.get_tooltip('trait', 'DISDAIN_ADVICE'))
        assert.are.equal(
            'Sensitivity to art and natural beauty.',
            descriptions.get_tooltip('trait', 'ART_INCLINED'))
        assert.are.equal(
            'Tendency to become angry.',
            descriptions.get_tooltip('trait', 'ANGER_PROPENSITY'))
    end)

    it('Attribute descriptions: future enum values receive a fallback', function()
        assert.are.equal(
            'A personality trait that shapes behavior and social interaction.',
            descriptions.get_tooltip('trait', 'FUTURE_TRAIT'))
    end)

end)