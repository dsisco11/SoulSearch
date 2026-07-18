local harness = require('support.script_harness')
local M = {}

function M.load(repo_root, relative_path, globals)
    return harness.load(repo_root, {source_path=relative_path, globals=globals})
end

return M
