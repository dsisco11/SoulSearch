local env = require('support.soulsearch_env')
return function(test, root)
    test.case('unit identity: owns the unit name and title labels', function()
        local UnitIdentity = env.load_unit_identity(root)
        local identity = UnitIdentity{subject={row={}, name='Urist', profession='Miner'}}

        test.assert_equal('Urist', identity.subviews.name.text)
        test.assert_equal('Miner', identity.subviews.title.text)
        test.assert_equal(3, identity:get_height())

        identity:set_subject(nil)
        test.assert_equal('No unit selected.', identity.subviews.name.text)
        test.assert_equal('', identity.subviews.title.text)
        test.assert_equal(1, identity:get_height())
    end)
end
