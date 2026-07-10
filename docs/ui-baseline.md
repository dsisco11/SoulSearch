# SoulSearch UI Baseline

Recorded: 2026-07-10

This document freezes the pre-cleanup UI contract used by
`docs/cleanup.todo`. Geometry, labels, colors, and input behavior below were
recorded from the current source. The manual smoke checklist must be executed in
Dwarf Fortress before the Phase 0 in-game baseline item can be marked complete.

## Validation record

| Gate | Result | Evidence |
| --- | --- | --- |
| Lua syntax build | Pass | `tools/Build.ps1`, 5 files checked with Lua 5.4.6 `luac`, 2026-07-10 |
| Pure characterization tests | Pass | `tools/Test.ps1`, 38 tests, 0 failures, 2026-07-10 |
| Live environment query | Pass | DF v0.53.15 win64 STEAM; DFHack 53.15-r1; fortress map loaded; 245x68 graphics mode; development script found in this checkout |
| In-game smoke baseline | Pending | Requires an interactive fortress-mode run |

## Window and panel geometry

Coordinates are widget-local unless stated otherwise.

- Main window title: `SoulSearch`.
- Default window frame: width 150, height 45, centered horizontally and
  vertically.
- Minimum resize frame: width 120, height 30.
- Main section divider columns: x=39 and x=105, drawn from y=2 through the
  bottom of the body with `COLOR_DARKGREY` `|` characters.
- Left Search filters panel content: l=1, width 38.
- Middle Results panel content: l=41, width 64.
- Right Stats panel content: l=107, r=1.
- Panel title row: t=2.
- Panel title underline row: t=3.
- Close control: r=1, t=0, width 16, height 1.

### Search filters panel

- `Add attribute filter`: l=1, t=4, width 25.
- `Add skill filter`: l=1, t=5, width 25.
- `Clear filters`: l=1, t=6, width 20.
- Active filter list: l=1, t=8, width 38, bottom-aligned.
- Attribute/trait picker: l=1, t=7, width 38, bottom-aligned.
- Skill picker: l=1, t=7, width 38, bottom-aligned.
- Picker close button: r=0, t=0, width 3, label `[X]`.
- Picker search field: l=0, t=0, r=4, height 1.
- Picker list: l=0, t=2, r=0, b=0.

### Results panel

- Name search field: l=41, t=4, width 64, height 1, label `Search: `.
- Results list: l=41, t=6, width 64, bottom-aligned.
- Result row format: resident name padded/truncated to 45 columns, followed by
  profession padded/truncated to 18 columns.

### Stats panel

- Static `Stats` title: l=107, t=2, r=1.
- Dynamic resident/filter header begins at l=107, t=4, r=1.
- Stats body begins at l=107 and is dynamically positioned below the resident
  header.
- Stat label width: 24.
- Stats value column begins at x=27.
- Stats value header hit width: 7.
- Stat-name header mouse range: x=2 through x=25 inclusive, y=0.
- Delta header mouse range: x=27 through x=33 inclusive, y=0.
- Default unsorted grouping order: physical attributes, mental attributes,
  personality traits.

## Filter action row and hitboxes

- Visible stat label space ends before x=21.
- The action area begins at x=21.
- Each action is exactly 3 columns wide (`FILTER_ACTION_WIDTH = 3`).
- Total action area is 15 columns.

| Local x range | Label | Action | Tooltip |
| --- | --- | --- | --- |
| 21-23 | `[+]` | Prefer high | `Prefer high` |
| 24-26 | `[-]` | Prefer low | `Prefer low` |
| 27-29 | `[▲]` via CP437 byte 30 | Move up | `Move up` |
| 30-32 | `[▼]` via CP437 byte 31 | Move down | `Move down` |
| 33-35 | `[x]` | Remove | `Remove` |

- x<21 and x>=36 have no filter action.
- The active filter label is truncated to 20 columns.
- Mouse activation first selects the row under the cursor, then resolves the
  action from the local x coordinate.
- Move-up is disabled visually for the first filter; move-down is disabled for
  the last filter. Disabled actions retain their 3-column geometry.

## CP437 glyph baseline

| Purpose | Byte | Source expression |
| --- | ---: | --- |
| Filter move up | 30 | `string.char(30)` |
| Filter move down | 31 | `string.char(31)` |
| Skill child row prefix | 16 | `string.char(16)` |
| Stats ascending marker | 24 | `string.char(24)` |
| Stats descending marker | 25 | `string.char(25)` |

The glyph bytes, surrounding brackets/spaces, and resulting widths are part of
the UI contract.

## Color baseline

### Stat categories

- Skill: `COLOR_YELLOW`.
- Physical attribute: `COLOR_LIGHTGREEN`.
- Mental attribute: `COLOR_LIGHTBLUE`.
- Personality trait: `COLOR_LIGHTMAGENTA`.

### Direction and deviation

- Selected high direction: `COLOR_LIGHTGREEN`.
- Selected low direction: `COLOR_LIGHTRED`.
- Unselected/disabled filter actions: `COLOR_DARKGREY`.
- Remove action: `COLOR_LIGHTRED`.
- Negative deviation, tier distance below 2: `COLOR_RED`.
- Negative deviation, tier distance at least 2: `COLOR_LIGHTRED`.
- Positive deviation, tier distance below 2: `COLOR_GREEN`.
- Positive deviation, tier distance at least 2: `COLOR_LIGHTGREEN`.
- Unmatched selected-filter values: `COLOR_DARKGREY`.

### General presentation

- Panel titles and skill category rows: `COLOR_WHITE`.
- Title underlines and stats headers: `COLOR_GREY`.
- Section dividers, secondary labels, and skill child prefixes:
  `COLOR_DARKGREY`.
- Tooltip text: white foreground on black background.
- Tooltip background: black foreground/background with space character 32.

## Keyboard and mouse behavior baseline

- `CUSTOM_F`: focus/open the Results name search field through its widget key.
- `CUSTOM_A`: toggle the attribute/trait picker.
- `CUSTOM_S`: toggle the skill picker.
- `CUSTOM_C`: clear all active filters.
- `CUSTOM_T`: focus the attribute picker search field.
- `CUSTOM_K`: focus the skill picker search field.
- Backspace closes either open picker before parent input handling.
- Mouse left-click on an active filter action changes direction, reorders, or
  removes according to the fixed x ranges above.
- Mouse left-click on a Stats column header cycles that column's sort state.
- `CUSTOM_R`: refresh resident snapshots.
- `CUSTOM_Z`: zoom to the selected resident using a live unit position read.
- `CUSTOM_U` / `CUSTOM_D`: move the selected filter up/down in priority.
- Cursor up/down move the Results list selection by one.
- Fast cursor up/down move the Results list selection by ten.
- Enter/submit on a result zooms to that resident.
- Result selection immediately refreshes the Stats panel.
- The main window is draggable and resizable; drag begin normalizes its frame to
  absolute l/t/w/h values.
- Closing the screen clears the cached screen reference. Reopening restores the
  saved filter directions and priority order for the current module lifetime.

## Manual in-game smoke checklist

Run this against the pre-cleanup implementation in a loaded fortress. Record the
DF/DFHack version and terminal dimensions with the result.

### Environment

- [x] Record Dwarf Fortress version: v0.53.15 win64 STEAM.
- [x] Record DFHack version: 53.15-r1 (release) x86_64.
- [x] Record terminal/window dimensions and display mode: 245x68, graphics
  mode.
- [x] Confirm the development script path resolves this checkout:
  `D:/CODE/DFHack/SoulSearch/src/scripts_modinstalled/soulsearch.lua`.

### Screen lifecycle and geometry

- [ ] Run `soulsearch` in fortress mode and confirm one centered 150x45 window.
- [ ] Run `soulsearch` again and confirm the existing screen is raised rather
  than duplicated.
- [ ] Confirm all three panel titles, underlines, and divider columns align with
  the geometry above.
- [ ] Drag the window from multiple points and confirm it follows the cursor.
- [ ] Resize the window down to 120x30 and confirm controls remain usable.
- [ ] Confirm the close control and Escape/leave-screen behavior dismiss the
  window.

### Filters and pickers

- [ ] Open/close the attribute picker using the hotkey, button, Backspace, and
  `[X]` control.
- [ ] Open/close the skill picker using the hotkey, button, Backspace, and `[X]`
  control.
- [ ] Confirm opening one picker closes the other.
- [ ] Search each picker and confirm matching, no-match, and cleared-query
  states.
- [ ] Confirm skill categories and child prefixes render in the expected order
  and colors.
- [ ] Add attribute, trait, and skill filters.
- [ ] Click the first and last column of each 3-column filter action range and
  confirm it invokes the expected action.
- [ ] Click x=20 and x=36 and confirm neither invokes a filter action.
- [ ] Confirm disabled priority actions preserve alignment and do nothing.
- [ ] Change high/low direction using mouse controls.
- [ ] Reorder filters using mouse controls and keyboard hotkeys.
- [ ] Remove one filter and clear all filters.
- [ ] Close and reopen SoulSearch and confirm filter order/directions persist.

### Results and ranking

- [ ] Confirm the Results list initially owns arrow-key navigation behavior.
- [ ] Verify normal and fast cursor navigation.
- [ ] Verify empty, matching, case-insensitive, and nonmatching name searches.
- [ ] Select multiple ordered filters and confirm full plus partial matches stay
  visible in relevance order.
- [ ] Confirm resident names and professions align in their columns.
- [ ] Change filter priority and confirm the result order responds.
- [ ] Confirm selection changes refresh the Stats resident immediately.

### Stats, tooltips, refresh, and zoom

- [ ] Confirm selected filters appear in priority order with high/low marker,
  category color, value, and grey unmatched state.
- [ ] Confirm notable physical, mental, and trait rows use the expected colors.
- [ ] Click Stat and Delta header boundaries and verify the three-phase sort
  cycle for each column.
- [ ] Close and reopen SoulSearch during each active Stat/Delta ascending and
  descending mode; confirm the selected column and direction persist.
- [ ] Hover every filter action, Stats header, add/clear/close control, and picker
  close control; confirm tooltip text and placement.
- [ ] Move a selected resident, then zoom and confirm the current live position
  is used.
- [ ] Refresh residents and confirm the list/stats update without errors.

### Invalid context

- [ ] With no map loaded, confirm the command prints the loaded-fortress
  requirement and does not open the UI.
- [ ] Outside fortress mode, confirm the fortress-only message and no UI.

## In-game baseline result

Status: **Pending manual execution**.

Do not mark the Phase 0 in-game baseline or final Phase 0 exit gate complete
until the checklist above has been executed and its environment/result recorded.
