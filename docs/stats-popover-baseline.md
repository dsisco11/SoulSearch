# Stats popover refactor baseline

This source-derived baseline records the current full-window Stats behavior
before the reusable-component extraction. It is not a fortress-mode validation
record. The outstanding live checks remain in Phase 0 of
`docs/stats-popover.todo`.

## Current composition and geometry

- `ui_components.create_stats_panel()` constructs five loose views: the
  `Stats` title, its underline, `stats_header`, `stats_columns`, and `stats`.
- Their main-window placement remains in `ui_layout.lua`: the Stats pane starts
  at column 67, the title begins at row 2, and Stats content begins at row 4.
- `update_stats_panel()` sets header, column, and body text, then lays out the
  latter three views vertically from the current `frame_body`. The body receives
  the remaining height and is the independently scrolling view.
- The fixed column hitboxes are `Stat` at x=0..23 and `Delta` at x=27..33 on
  the first column-header row. Attribute-name tooltip cells are x=2..26; Delta
  tooltip cells are x=27..33.

## Current presentation behavior

- `stats_presenter` includes only meaningful physical, mental, and trait
  deviations. Skills are excluded, and sections with no meaningful records are
  omitted.
- Category pens are light green (physical), light blue (mental), and light
  magenta (traits). Positive/negative deviation pens retain their existing
  tier-sensitive green/red treatment.
- The header renders the selected resident name, profession, and selected
  filters. With no selected result it says `No resident selected.`; missing
  names fall back to `Unknown resident`.
- Default ordering preserves physical, mental, and trait sections, separating
  non-empty sections with blank rows. Sorted ordering is flat.

## Current sorting, input, and persistence behavior

- `stats_columns` is a `SortableHeader` child view. It owns its own click
  hit-test and calls the window-provided sort callback.
- `SoulSearchWindow:onInput()` delegates to its superclass first; global
  fallback handling runs only for input no child consumed. Root-window Stats
  header hit testing is not used.
- `cycle_stats_sort()` uses three states. A new `Stat` sort starts ascending,
  then descending, then unsorted. A new `Delta` sort starts descending, then
  ascending, then unsorted.
- User sort changes update the window identity's session `stats_sort` snapshot
  and refresh Stats. Initialization and ordinary `refresh_stats()` calls do not
  write settings.

## Current tooltip behavior

- `Stat` and `Delta` header tooltips describe their corresponding sort action.
- Every Delta cell exposes the baseline-difference tooltip.
- Attribute tooltips are selected from the visible body row using
  `(stats.start_line_num or 1) + y`; this preserves correct record lookup after
  scrolling.
- The screen-level tooltip aggregator gives unrelated controls and filter
  tooltips priority before Stats header, Delta, attribute, and fallback text.

## Automated evidence

The following baseline commands were run on 2026-07-13 after this document was
added:

- `tools/Build.ps1`
- `tools/Test.ps1`
- `git diff --check`

They passed with 210 pure-Lua tests. The tests cover presentation categories,
meaningful-deviation filtering, section gaps, Stats sort ordering, column and
cell hitbox boundaries, scrolling-record indexing, and current component view
composition.

## Live Phase 0 evidence still required

The following cannot be established from the pure-Lua harness and remain
unchecked in `docs/stats-popover.todo`:

- current fortress visual layout, colors, tooltip rendering, scrolling, and
  keyboard focus/traversal;
- scroll reset/retention for subject and sort changes in a live DFHack UI;
- vanilla unit-card focus strings and selected-unit lookup;
- overlay discovery/default placement/global-enable behavior; and
- `gui.ZScreenModal` pause and input-restoration behavior at the supported UI
  scales and minimum tile-grid dimensions.

## Live-probe status

On 2026-07-13, the running local DFHack instance was queried through
`dfhack-run.exe`. The initial no-argument `getFocusStrings()` probe returned an
empty set; this DFHack version requires the current viewscreen argument, so the
Phase 0 checklist now uses `getFocusStrings(getCurViewscreen(true))`.

The corrected probe recorded:

- focus: `dwarfmode/ViewSheets/UNIT/Overview`;
- selected unit: `24043`;
- map and site loaded: `true`;
- current tile grid: `245x68`;
- current pause state: `true`; and
- global overlay framework: enabled (`overlay: on`).

This validates one practical unit-card entry route and selected-unit capture.
It does not validate other unit-card routes, visual layout/tooltip behavior,
overlay-widget discovery or placement, or modal pause/input restoration. Those
remain required before Phase 0 can be marked complete.
