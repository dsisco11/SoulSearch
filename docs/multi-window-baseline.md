# Multi-window refactor baseline

This source-derived baseline records the singleton behavior that the
multi-window refactor must deliberately replace or preserve. It is not a
fortress-mode validation record.

## Current opening and lifetime behavior

- `soulsearch.lua` ensures the default keybinding, prepares world caches, then
  delegates every command invocation to `ui.open(...)`.
- The Ctrl+F default keybinding runs the same `soulsearch` command, so it reaches
  the same UI opening path.
- `ui.open()` first asks `residents.get_unavailable_reason()`. If unavailable,
  it prints the reason and constructs no screen.
- A module-local `view` caches one `SoulSearchScreen`; later opens raise that
  screen instead of creating another. Its `onDismiss()` clears the cache.

## Current session state

- `filter_state.lua` keeps one module-local ordered filter snapshot. Filter
  changes save it immediately, and a later window loads a copy of it.
- `ui.lua` keeps one module-local result-sort record, stats-sort record, and
  window frame. Sort changes save immediately; the frame saves on dismissal.
- A new window resets unit scope to `citizens`, query text, picker queries,
  selected result, result rows, modal visibility, tooltip state, and refresh
  suppression state.
- Existing filter-state validation guarantees at least one positive candidate
  race filter; it restores the positive humanoid filter when none remains.

## Test boundary

Pure-Lua tests characterize command delegation, unavailable-context rejection,
filter validation, and extracted state modules. Actual ZScreen construction,
layering, focus, and dismissal timing require DFHack/live validation.
