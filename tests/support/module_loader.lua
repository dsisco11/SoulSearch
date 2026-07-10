local M = {}

local function join_path(root, relative_path)
    local separator = package.config:sub(1, 1)
    return root .. separator .. relative_path:gsub('[/\\]', separator)
end

function M.load(repo_root, relative_path, globals)
    local environment = globals or {}
    setmetatable(environment, {__index=_G})

    local path = join_path(repo_root, relative_path)
    local chunk, err = loadfile(path, 't', environment)
    assert(chunk, err)
    chunk()
    return environment
end

return M
