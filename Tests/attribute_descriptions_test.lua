local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local descriptions = soulsearch_env.load_attribute_descriptions(repo_root)

    add_test('Attribute descriptions: explain known attributes and traits', function()
        luaunit.assertIs(
            'Muscular power for carrying, melee force, and movement.',
            descriptions.get_tooltip('physical_attribute', 'STRENGTH'))
        luaunit.assertIs(
            'Affects close combat and some labor skills; delays suffocation.',
            descriptions.get_tooltip('physical_attribute', 'TOUGHNESS'))
        luaunit.assertIs(
            'Ability to concentrate on a task.',
            descriptions.get_tooltip('mental_attribute', 'FOCUS'))
        luaunit.assertIs(
            'Willingness to help others without reward.',
            descriptions.get_tooltip('trait', 'ALTRUISM'))
        luaunit.assertIs(
            "Tendency to reject advice and rely on one's own counsel.",
            descriptions.get_tooltip('trait', 'DISDAIN_ADVICE'))
        luaunit.assertIs(
            'Sensitivity to art and natural beauty.',
            descriptions.get_tooltip('trait', 'ART_INCLINED'))
        luaunit.assertIs(
            'Tendency to become angry.',
            descriptions.get_tooltip('trait', 'ANGER_PROPENSITY'))
    end)

    add_test('Attribute descriptions: future enum values receive a fallback', function()
        luaunit.assertIs(
            'A personality trait that shapes behavior and social interaction.',
            descriptions.get_tooltip('trait', 'FUTURE_TRAIT'))
    end)

return native_tests
