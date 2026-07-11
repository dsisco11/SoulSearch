local soulsearch_env = require('support.soulsearch_env')

return function(test, repo_root)
    local glyphs = soulsearch_env.load_ui_glyphs(repo_root)

    test.case('UI glyphs: CP437 definitions match their byte values', function()
        test.assert_equal(string.char(16), glyphs.CP437_ARROW_RIGHT)
        test.assert_equal(string.char(24), glyphs.CP437_ARROW_UP)
        test.assert_equal(string.char(25), glyphs.CP437_ARROW_DOWN)
        test.assert_equal(string.char(30), glyphs.CP437_TRIANGLE_UP)
        test.assert_equal(string.char(31), glyphs.CP437_TRIANGLE_DOWN)
        test.assert_equal(string.char(179), glyphs.CP437_VERTICAL_LINE)
        test.assert_equal(string.char(196), glyphs.CP437_HORIZONTAL_LINE)
    end)
end
