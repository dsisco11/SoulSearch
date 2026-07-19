local repo_root = require('support.repo_root')

local separator = package.config:sub(1, 1)

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

describe('package contract', function()

it('package contract: required metadata is present', function()
    local info = read_source('info.txt')
    for _, key in ipairs({'ID', 'NAME', 'NUMERIC_VERSION',
                          'DISPLAYED_VERSION', 'DESCRIPTION'}) do
        assert.is_truthy(
            info:match('%[' .. key .. ':[^%]]+%]') ~= nil,
            'missing required metadata: ' .. key)
    end
end)

it('package contract: public commands are present', function()
    assert.is_truthy(source_exists(
        'scripts_modinstalled/soulsearch.lua'))
    assert.is_truthy(source_exists(
        'scripts_modinstalled/gui/soulsearch.lua'))
end)

it('package contract: bootstrap annotations and dependency are present',
        function()
    local command = read_source('scripts_modinstalled/soulsearch.lua')
    assert.is_truthy(command:find('--@module=true', 1, true) ~= nil)
    assert.is_truthy(command:find('--@enable=true', 1, true) ~= nil)
    assert.is_truthy(command:find(
        "'internal/soulsearch/keybindings'", 1, true) ~= nil)

    assert.is_truthy(source_exists(
        'scripts_modinstalled/internal/soulsearch/keybindings.lua'))
end)

end)
