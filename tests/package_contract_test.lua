local luaunit = require('luaunit')
local repo_root = require('support.repo_root')

local separator = package.config:sub(1, 1)
local native_tests = {}

local function source_path(relative_path)
    return repo_root .. separator .. 'src' .. separator ..
        relative_path:gsub('/', separator)
end

local function read_source(relative_path)
    local path = source_path(relative_path)
    local file = assert(io.open(path, 'rb'))
    local text = file:read('*a')
    file:close()
    return text
end

local function source_exists(relative_path)
    local file = io.open(source_path(relative_path), 'rb')
    if not file then return false end
    file:close()
    return true
end

local function add_test(name, callback)
    native_tests['test ' .. name] = callback
end

add_test('package contract: required metadata is present', function()
    local info = read_source('info.txt')
    for _, key in ipairs({'ID', 'NAME', 'NUMERIC_VERSION',
                          'DISPLAYED_VERSION', 'DESCRIPTION'}) do
        luaunit.assertEvalToTrue(
            info:match('%[' .. key .. ':[^%]]+%]') ~= nil,
            'missing required metadata: ' .. key)
    end
end)

add_test('package contract: public commands are present', function()
    luaunit.assertEvalToTrue(source_exists(
        'scripts_modinstalled/soulsearch.lua'))
    luaunit.assertEvalToTrue(source_exists(
        'scripts_modinstalled/gui/soulsearch.lua'))
end)

add_test('package contract: bootstrap annotations and dependency are present',
        function()
    local command = read_source('scripts_modinstalled/soulsearch.lua')
    luaunit.assertEvalToTrue(command:find('--@module=true', 1, true) ~= nil)
    luaunit.assertEvalToTrue(command:find('--@enable=true', 1, true) ~= nil)
    luaunit.assertEvalToTrue(command:find(
        "'internal/soulsearch/keybindings'", 1, true) ~= nil)

    luaunit.assertEvalToTrue(source_exists(
        'scripts_modinstalled/internal/soulsearch/keybindings.lua'))
end)

return native_tests
