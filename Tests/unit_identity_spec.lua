local env = require('support.soulsearch_env')
local root = require('support.repo_root')

describe('unit identity', function()

    it('unit identity: owns the unit name and title labels', function()
        local UnitIdentity = env.load_unit_identity(root)
        local identity = UnitIdentity{subject={row={}, name='Urist', profession='Miner'}}

        assert.are.equal('Urist', identity.subviews.name.text)
        assert.are.equal('Miner', identity.subviews.title.text)
        assert.are.equal(3, identity:get_height())

        identity:set_subject(nil)
        assert.are.equal('No unit selected.', identity.subviews.name.text)
        assert.are.equal('', identity.subviews.title.text)
        assert.are.equal(1, identity:get_height())
    end)

end)
