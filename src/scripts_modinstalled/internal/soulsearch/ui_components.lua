--@ module=true

-- Temporary aggregate for root-window controls. Component modules now own
-- their respective UI subtrees; Phase 5 removes this aggregate.
local widgets = require('gui.widgets')
local ui_layout = reqscript('internal/soulsearch/ui_layout')
local filter_panel = reqscript('internal/soulsearch/ui/filter_panel')

-- Temporary compatibility facade for Phase 2. Consumers now import the
-- Filter Panel directly; Phase 5 removes these aliases with this aggregate.
create_filter_panel = filter_panel.create
create_filter_panel_button = filter_panel.create_button
create_active_filter_count = filter_panel.create_active_filter_count

---@param on_close fun()
---@return table
function create_close_button(on_close)
    return widgets.HotkeyLabel{view_id='close_button', frame=ui_layout.get_frame('close'),
        key='LEAVESCREEN', label='Close', on_activate=on_close}
end
