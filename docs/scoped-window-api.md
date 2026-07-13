# Scoped-window integration API

Future integrations create a new SoulSearch window through the internal UI
module rather than changing a live window or a module global:

```lua
local ui = reqscript('internal/soulsearch/ui')
ui.open{
    settings_id='creatures:miners',
    filters={{id='skill:MINING', direction='high'}},
    unit_scope='fort_residents',
}
```

`ui.open(options)` always constructs a new window. `settings_id` is the stable
identity for that window category; omitting it selects `default`. The identity
is session-only: its saved filters, unit scope, sorts, and geometry live only
while the `window_settings` module remains loaded. A development reload starts
a fresh settings session.

The option fields `filters`, `unit_scope`, `result_sort`, `stats_sort`, and
`frame` are initial values for the new window. Each supplied field replaces only
that field from the identity's saved snapshot; omitted fields retain the saved
value or use normal defaults. Callers must supply an initial scope through
`options`, not by mutating an already-open screen or shared module state.

Filter presets are separate. Custom presets are JSON files intended to survive
DFHack sessions; window identities are not persisted and never select, alter,
or create those preset files.
