-- Print retained Creatures navigation diagnostics to the DFHack console.
--@ module=false

local navigator =
    reqscript('internal/soulsearch/creatures_menu_navigator')
local messages = navigator.get_log_messages()

if #messages == 0 then
    dfhack.println('[SoulSearch Creatures Navigator] no captured events')
    return
end

for _, message in ipairs(messages) do dfhack.println(message) end
