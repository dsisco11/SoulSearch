local soulsearch_env = require('support.soulsearch_env')

local repo_root = require('support.repo_root')

describe('UI glyphs', function()

    local glyphs = soulsearch_env.load_ui_glyphs(repo_root)

    it('UI glyphs: CP437 definitions match their byte values', function()
        assert.are.equal(string.char(16), glyphs.CP437_ARROW_RIGHT)
        assert.are.equal(string.char(24), glyphs.CP437_ARROW_UP)
        assert.are.equal(string.char(25), glyphs.CP437_ARROW_DOWN)
        assert.are.equal(string.char(30), glyphs.CP437_TRIANGLE_UP)
        assert.are.equal(string.char(31), glyphs.CP437_TRIANGLE_DOWN)
        assert.are.equal(string.char(179), glyphs.CP437_VERTICAL_LINE)
        assert.are.equal(string.char(196), glyphs.CP437_HORIZONTAL_LINE)
    end)

end)