local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('filter constants', function()

    it('filter constants: preserve serialized filter protocol values', function()
        local constants =
            soulsearch_env.load_filter_constants(repo_root).FILTER_CONSTANTS

        assert.are.equal('high', constants.direction.HIGH)
        assert.are.equal('low', constants.direction.LOW)
        assert.are.equal('candidate', constants.behavior.CANDIDATE)
        assert.are.equal('ranking', constants.behavior.RANKING)
        assert.are.equal('unit_scope', constants.kind.UNIT_SCOPE)
        assert.are.equal('citizens', constants.unit_scope.CITIZENS)
        assert.are.equal('livestock', constants.unit_scope.LIVESTOCK)
        assert.are.equal('pets', constants.unit_scope.PETS)
        assert.are.equal('visitors', constants.unit_scope.VISITORS)
        assert.are.equal('wildlife', constants.unit_scope.WILDLIFE)
        assert.are.equal('unit_scope:', constants.unit_scope.id_prefix)
        assert.are.equal('race:group:HUMANOIDS',
            constants.default_race_filter_id)
        assert.are.equal('race:raw:', constants.race.raw_id_prefix)
    end)

end)
