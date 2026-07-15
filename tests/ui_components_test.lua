local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local components = soulsearch_env.load_ui_components(repo_root)
    local noop = function() end

    test.case('UI components: root close control remains available', function()
        test.assert_equal('close_button', components.create_close_button(noop).view_id)
    end)
end
