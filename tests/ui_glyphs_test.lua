local soulsearch_env = require('support.soulsearch_env')

local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local native_tests = {}

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end
    local glyphs = soulsearch_env.load_ui_glyphs(repo_root)

    add_test('UI glyphs: CP437 definitions match their byte values', function()
        luaunit.assertIs(string.char(16), glyphs.CP437_ARROW_RIGHT)
        luaunit.assertIs(string.char(24), glyphs.CP437_ARROW_UP)
        luaunit.assertIs(string.char(25), glyphs.CP437_ARROW_DOWN)
        luaunit.assertIs(string.char(30), glyphs.CP437_TRIANGLE_UP)
        luaunit.assertIs(string.char(31), glyphs.CP437_TRIANGLE_DOWN)
        luaunit.assertIs(string.char(179), glyphs.CP437_VERTICAL_LINE)
        luaunit.assertIs(string.char(196), glyphs.CP437_HORIZONTAL_LINE)
    end)

return native_tests
