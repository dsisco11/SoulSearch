-- Print resolver diagnostics captured after gui/soulsearch returned.
--@ module=false

local tooltip_agent = reqscript('internal/soulsearch/ui/tooltip_agent')
local messages = tooltip_agent.get_debug_messages()

if #messages == 0 then
    dfhack.println('[SoulSearch tooltip resolver] no captured transitions')
    return
end

for _, message in ipairs(messages) do dfhack.println(message) end
