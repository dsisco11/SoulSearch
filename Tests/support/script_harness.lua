local M = {}

local function join_path(root, relative_path)
    local separator = package.config:sub(1, 1)
    return root .. separator .. relative_path:gsub('[/\\]', separator)
end

local function lookup(map, kind, name)
    local value = map and map[name]
    assert(value ~= nil, ('unexpected %s: %s'):format(kind, tostring(name)))
    return value
end

---Loads one script with only the collaborators explicitly supplied by a test.
---@param repo_root string
---@param config table
---@field source_path string
---@field reqscript table<string, any>|nil
---@field require_modules table<string, any>|nil
---@field globals table|nil
---@return table environment
function M.load(repo_root, config)
    assert(type(config) == 'table' and type(config.source_path) == 'string',
        'script harness requires a source_path')
    local environment = {}
    for key, value in pairs(config.globals or {}) do environment[key] = value end
    if config.reqscript then
        environment.reqscript = function(name)
            return lookup(config.reqscript, 'reqscript', name)
        end
    end
    if config.require_modules then
        environment.require = function(name)
            return lookup(config.require_modules, 'require', name)
        end
    end
    setmetatable(environment, {__index=_G})

    local chunk, err = loadfile(join_path(repo_root, config.source_path), 't', environment)
    assert(chunk, err)
    chunk()
    return environment
end

return M
