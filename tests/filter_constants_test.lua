local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    test.case('filter constants: preserve serialized filter protocol values', function()
        local constants =
            soulsearch_env.load_filter_constants(repo_root).FILTER_CONSTANTS

        test.assert_equal('high', constants.direction.HIGH)
        test.assert_equal('low', constants.direction.LOW)
        test.assert_equal('candidate', constants.behavior.CANDIDATE)
        test.assert_equal('ranking', constants.behavior.RANKING)
        test.assert_equal('citizens_and_pets', constants.default_unit_scope)
        test.assert_equal('race:group:HUMANOIDS',
            constants.default_race_filter_id)
        test.assert_equal('race:raw:', constants.race.raw_id_prefix)
    end)
end
