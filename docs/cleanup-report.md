# SoulSearch Codebase Cleanup Report

Date: 2026-07-10

## Executive summary

SoulSearch is small enough to refactor safely, but most of its complexity is
concentrated in two files: `ui.lua` (1,502 lines and 83 functions) and
`search.lua` (656 lines, including a large skill-category table). The module
boundaries are directionally good—resident collection, stat evaluation,
searching, and UI are already separate—but the UI currently owns presentation,
layout, input routing, filter-state management, persistence, and orchestration.

The recommended cleanup is evolutionary rather than a rewrite:

1. Add characterization tests around ranking, evaluation, and filter-state
   transitions.
2. Build filter descriptors once and expose a catalog with indexed lookup.
3. Extract filter state and update orchestration from the window class.
4. Split UI formatting and picker/stats components without changing geometry.
5. Consolidate small shared utilities and remove unused compatibility shapes.
6. Bring developer documentation and validation tooling in line with the code.

The highest-risk behavior to preserve is the current relevance ranking and the
exact DFHack UI interaction model: filter order, fixed-width action labels and
hitboxes, keyboard focus/navigation, section geometry, colors, and persisted
filters.

## Current architecture

| Area | Current responsibility | Size / signal |
| --- | --- | --- |
| `soulsearch.lua` | Public command, module loading, development reload | 53 lines |
| `attributes.lua` | Race/trait baselines, stat evaluation, direction scoring | 214 lines |
| `residents.lua` | DFHack unit access and resident snapshot construction | 206 lines |
| `search.lua` | Descriptor metadata, skill categories, search, scoring, sorting | 656 lines |
| `ui.lua` | Rendering, formatting, layout, input, state, persistence, orchestration | 1,502 lines |
| `tools/Build.ps1` | Lua parse check only | No behavioral test coverage |

The existing separation between resident collection, evaluation, and search is
worth retaining. Cleanup should make those boundaries narrower and easier to
test instead of merging them into a new all-purpose module.

## Prioritized cleanup opportunities

### P0. Add behavioral safety nets before moving responsibilities

**Evidence**

- The repository has no tracked test/spec files.
- `tools/Build.ps1` only parses Lua files; the README correctly notes that it
  does not validate DFHack APIs, widgets, or game-state behavior.
- Ranking depends on matched count, priority-weighted score, raw score, name,
  and unit ID in that order (`search.lua:624-654`). This is easy to alter
  accidentally during a seemingly mechanical refactor.
- Stat evaluation has distinct rules for traits, skills, and physical/mental
  attributes (`attributes.lua:122-213`).

**How to clean it up**

- Add table-driven tests for `attributes.evaluate()`, `matches_direction()`,
  and `score_direction()` using representative high, neutral, low, missing,
  and race-baseline values.
- Add search characterization fixtures covering partial matches, filter
  priority, name filtering, stable tie-breaks, zero-skill behavior, and mixed
  stat kinds.
- Extract filter-state transitions into pure functions and test add, remove,
  reorder, direction change, validation of stale IDs, and persistence copying.
- Keep a short in-game smoke checklist for behavior that cannot be covered by a
  standalone Lua runner: focus, mouse action zones, dropdown visibility,
  dragging/resizing, tooltip placement, refresh, and zoom.
- Add a `tools/Test.ps1` entry point, or extend `Build.ps1` with an explicit test
  phase, so the expected local validation command is unambiguous.

**Done when**

- Ranking and state-transition behavior can be checked without opening Dwarf
  Fortress.
- The syntax gate and in-game smoke gate are documented separately.

### P1. Replace repeated descriptor construction with one catalog

**Evidence**

- `SoulSearchWindow:init()` calls both `search.get_filter_descriptors()` and
  `search.get_flat_filter_descriptors()` (`ui.lua:702-703`), constructing the
  same descriptor sets twice.
- Every selected-filter lookup calls
  `flatten_descriptors(get_filter_descriptors())` (`search.lua:435-441`). Since
  `selected_filters_to_descriptors()` performs that lookup once per selected
  filter (`search.lua:510-520`), a search rebuilds and sorts the entire catalog
  repeatedly.
- UI lookup independently scans `self.filter_descriptors`
  (`ui.lua:980-987`).

**How to clean it up**

- Introduce a descriptor catalog built once per loaded script environment:
  `groups`, `flat`, and `by_id`.
- Return the same catalog to the UI and search layers instead of regenerating
  equivalent tables through separate APIs.
- Resolve selected filter IDs through `by_id[id]` in constant time.
- Treat descriptor tables as immutable. Copy only the selected-filter wrapper
  that adds `direction`.
- If DFHack enum metadata can change without script reload, expose an explicit
  `rebuild_catalog()` operation and call it on the relevant lifecycle event;
  do not silently rebuild it inside every lookup.

**Done when**

- Opening the window constructs descriptors once.
- Applying a search performs no enum traversal or descriptor sorting.
- UI and search use the same descriptor identities and category ordering.

### P1. Move filter state and transitions out of `SoulSearchWindow`

**Evidence**

- `ui.lua` stores the same logical selection in three forms:
  `selected_filter_modes`, `selected_filter_order`, and `selected_filters`
  (`ui.lua:679-681`, `ui.lua:709-712`, `ui.lua:1130-1135`).
- State validation, persistence, lookup, mutation, and ordering occupy methods
  from `get_selected_filters()` through `move_selected_filter_priority()`
  (`ui.lua:964-1373`).
- Module globals `saved_filter_modes` and `saved_filter_order` are the
  persistence store (`ui.lua:22-23`, `ui.lua:1014-1018`).
- `set_filter_direction()` calls `add_filter()` for an inactive filter, which
  refreshes the UI/results, then changes the direction and refreshes them again
  (`ui.lua:1289-1302`).

**How to clean it up**

- Create a small `filter_state.lua` model with one canonical ordered collection,
  for example `{id, direction}` entries, plus an ID index if profiling shows it
  is useful.
- Implement `add`, `remove`, `clear`, `set_direction`, `move`, `validate`, and
  `copy` as atomic transitions. Each user action should produce one new state
  and one notification/refresh.
- Keep persistence behind explicit `load()` and `save(state)` functions. This
  makes the current session-only behavior clear and keeps module globals out of
  the window.
- Remove the derived `self.selected_filters` field; create the search input from
  canonical state when results are updated.

**Done when**

- The window does not implement collection mutation or persistence rules.
- One state-changing action causes at most one result recomputation.
- Invalid/stale descriptor IDs and duplicate IDs have defined, tested behavior.

### P1. Collapse UI refresh cascades into explicit invalidation paths

**Evidence**

- `update_available_filter_choices()` and
  `update_available_skill_choices()` are each called from eight locations.
- Add/remove/clear/direction/dropdown methods repeat slightly different sets of
  `update_*` calls (`ui.lua:1237-1352`).
- It is difficult to tell which derived views must change for a given state
  mutation, and easy for a future control to become stale.

**How to clean it up**

- Add narrow orchestration methods such as `refresh_filter_views()`,
  `refresh_picker_views()`, and `recompute_results()`.
- Better still, have the filter-state model emit one change event and have the
  controller update all filter-derived views once.
- Separate picker visibility changes from filter-data changes: opening a picker
  should not rebuild unrelated result rows.
- Preserve the currently selected result/filter where possible instead of
  unconditionally selecting the first result in `update_results()`.

**Done when**

- Every user action has one obvious update path.
- View refreshes are not nested inside state transitions.
- Adding another filter control does not require editing several mutation
  methods.

### P2. Split `ui.lua` by responsibility, not by arbitrary line count

**Evidence**

- `ui.lua` contains text formatting (`ui.lua:78-257`), mouse/tooltip helpers
  (`ui.lua:259-382`), stats presentation (`ui.lua:429-644`), layout and drawing
  (`ui.lua:646-660`, `ui.lua:691-887`), filter state/controller behavior
  (`ui.lua:964-1427`), and input/screen lifecycle (`ui.lua:1428-1502`).
- `SoulSearchWindow:init()` alone constructs all three panels and both picker
  overlays (`ui.lua:691-887`).

**How to clean it up**

- Extract pure token/text formatting to `ui_format.lua`.
- Extract stats record construction/sorting to `stats_presenter.lua` so it can
  be tested independently of widgets.
- Create focused picker and panel components only where DFHack widget ownership
  remains clear: `FilterPanel`, `ResultsPanel`, and `StatsPanel` are reasonable
  boundaries.
- Leave `SoulSearchWindow` as the composition root and event coordinator.
- Keep tooltip behavior close to the controls that provide tooltip metadata,
  rather than maintaining a central list of view IDs in
  `get_tooltip_text()` (`ui.lua:944-962`).

**Done when**

- The main window describes layout and coordination, not formatting and data
  transformation.
- Presenter/formatter modules can run with simple Lua tables.
- Component extraction does not change keyboard or mouse ownership.

### P2. Centralize layout geometry while preserving exact hitboxes

**Evidence**

- Panel boundaries are encoded independently as divider positions `{39, 105}`
  (`ui.lua:25`) and widget left edges `41` and `107`
  (`ui.lua:715-880`).
- Stats frames repeat `l=107` during dynamic layout (`ui.lua:1166-1167`).
- Filter action rendering and hit detection depend on coordinated constants
  (`ui.lua:34-47`, `ui.lua:214-285`).

**How to clean it up**

- Define one layout table containing panel edges, gaps, header rows, action
  width, and stats columns; derive widget frames and dividers from it.
- Represent filter actions as ordered metadata
  (`id`, `label`, `width`, `tooltip`, enabled predicate) and use the same table
  for rendering and x-coordinate hit testing.
- Add boundary tests for every filter-action x range and stats-header column.
- Do not replace fixed widths with auto-layout unless in-game behavior is first
  characterized across the supported terminal sizes.

**Done when**

- Moving a panel boundary requires changing one value.
- Rendered filter controls and their mouse targets cannot drift apart.
- Existing `FILTER_ACTION_WIDTH = 3` behavior remains exact.

### P2. Separate skill taxonomy data from search behavior

**Evidence**

- `SKILL_CATEGORY_BY_KEY` occupies most of the first 260 lines of `search.lua`.
- The same category names/order appear separately in `search.lua:59-63` and
  `ui.lua:70-76`.
- The mapping contains compatibility aliases such as `WOODCUTTING` and
  `WOOD_CUTTING`, which are useful data but obscure the ranking implementation.

**How to clean it up**

- Move category names, order, and key mapping into `skill_categories.lua` (or a
  more general descriptor metadata module).
- Export `get_category(key)` and `get_order()` so the picker and catalog share
  one vocabulary.
- Add a validation check that every current `df.job_skill` resolves to a known
  category, reporting fallback assignments during development.
- Keep the fallback to `Other Skills` for forward compatibility.

**Done when**

- `search.lua` reads as search/scoring logic from top to bottom.
- Category order and labels have one source of truth.

### P2. Consolidate enum and string utilities at the owning boundary

**Evidence**

- `enum_keys()` is duplicated verbatim in `residents.lua:19-28` and
  `search.lua:261-270`.
- `contains_text()` exists in both `search.lua:466-472` and `ui.lua:92-98` with
  slightly different nil/type tolerance.
- Enum title formatting in `search.lua:274-295` and stat label formatting in
  `ui.lua:455-456` solve related presentation problems differently.

**How to clean it up**

- Put DF enum traversal/name lookup in one small adapter module used by both
  resident collection and descriptor construction.
- Keep plain text matching in a pure string utility or expose it from the search
  query layer; define one nil/coercion contract.
- Reuse one display-label formatter for enum-backed stats, with explicit
  overrides where DFHack supplies a better localized caption.
- Avoid creating a broad `utils.lua`; group helpers by domain so ownership stays
  clear.

**Done when**

- Shared behavior has one implementation and one tested contract.
- Utility extraction reduces duplication without becoming a miscellaneous
  dependency hub.

### P3. Narrow the internal search API and result model

**Evidence**

- `search.apply()` accepts three mutually exclusive selection shapes:
  `selected_descriptors`, `selected_filters`, and `selected_filter_ids`
  (`search.lua:49-53`, `search.lua:624-630`).
- The current UI uses only `selected_filters` (`ui.lua:1132-1136`).
- `matched_criteria`, `criteria_count`, and `match_label` are populated in each
  result (`search.lua:593-599`) but have no references outside `search.lua`.

**How to clean it up**

- Choose one internal input contract—preferably ordered `{id, direction}`
  filters resolved through the descriptor catalog.
- Remove compatibility inputs if no external script consumes this private
  module. If compatibility is intentional, document precedence and normalize
  through one public helper before `apply()`.
- Remove unused result fields, or add a documented consumer. Keep
  `filter_criteria`, `matched_count`, and score fields only where required for
  rendering or sorting.
- Make sort precedence a named comparator so its contract is directly testable.

**Done when**

- `apply()` has one unsurprising input shape.
- Result rows contain only rendering and ordering data that has a consumer.

### P3. Isolate DFHack reads from resident snapshot construction

**Evidence**

- `residents.lua` mixes defensive DFHack calls, enum traversal, name
  translation, skill-progress calculation, and row construction
  (`residents.lua:34-177`).
- Several `pcall` failures are silently treated as missing data
  (`residents.lua:56-84`, `residents.lua:134-143`). This is safe for users but
  makes compatibility regressions difficult to diagnose.
- Attribute raw parsing and caching similarly combine DF global access with
  evaluation in `attributes.lua:54-97`.

**How to clean it up**

- Introduce narrow adapter functions for DFHack reads and keep row/evaluation
  transformation pure where practical.
- Centralize the "safe read" policy. In normal mode, preserve graceful
  fallback; in a development/debug mode, count or report failed reads once per
  field/API instead of silently discarding all evidence.
- Make cache lifetime explicit. Provide a cache reset tied to script/world
  lifecycle rather than relying only on module reload semantics.
- Verify the skill progress formula and raw attribute-range parsing against the
  supported DF/DFHack version before changing them; these are behavior rules,
  not merely formatting code.

**Done when**

- Snapshot transformation can be tested with fixture units/adapters.
- Compatibility failures are diagnosable without spamming normal users.
- Cache invalidation has a documented owner.

### P3. Remove small redundancies after the structural work

**Evidence and suggested fixes**

- `get_deviation_pen()` returns `COLOR_LIGHTGREEN` for both `tier_distance >= 4`
  and `>= 2` (`ui.lua:158-163`). Collapse the redundant branch unless a
  distinct extreme-value color is intended.
- `update_add_filter_button()` and `update_add_skill_button()` always set static
  labels (`ui.lua:1343-1352`). Set them during construction and remove the
  refresh methods, or make the labels actually reflect open/closed state.
- `copy_selected_descriptors()` copies only the array, not descriptors
  (`search.lua:475-482`). Rename it to make the shallow behavior explicit or
  remove it once descriptor immutability is established.
- `format_position()` is currently unused (`ui.lua:101-109`). Remove it unless
  it is part of a near-term diagnostic/UI feature.
- The entrypoint asks for a `search` field when loading `search.lua`
  (`soulsearch.lua:36`), but that module exports functions such as `apply`, not
  a `search` field. This forces the fallback for `search.lua`, while modules
  whose required fields exist remain cached, so `refresh_scripts()` does not
  reload the module set consistently. Decide whether this function validates or
  reloads: use `apply` if it only validates the loaded search contract, or use
  one explicit DFHack reload path for every internal module if development
  hot-reload is the intended behavior.

These should be handled after tests/catalog/state boundaries land, so small
edits do not become mixed with behavior-sensitive moves.

### P3. Correct documentation and developer-workflow drift

**Evidence**

- README's roadmap points to `docs/SoulSearch.todo`, but the tracked checklist
  is `docs/project.todo` (`README.md:123-125`).
- README says resident collection snapshots positions and describes
  "checkbox-driven" filters (`README.md:17-24`), while position is read live at
  zoom time and the current UI uses ordered high/low filter controls.
- README's status says phases 1-5 are in place even though the checklist has
  evolved into a completed feature list plus one architecture-cleanup item.
- The build reports syntax only, and there is no automated check for stale docs,
  tests, or packaging.

**How to clean it up**

- Update README architecture/status/usage text to match the current modules and
  ordered relevance filters.
- Point the roadmap at `docs/project.todo` and link this report from the open
  architecture-cleanup task when implementation begins.
- Document the validation matrix: parse check, pure tests, packaging check, and
  in-game smoke test.
- Optionally add a publish verification that inspects archive structure and
  confirms `info.txt` plus the public command are present.

## Recommended implementation sequence

### Phase 0: Characterize behavior

- Add evaluation, ranking, and filter-state fixtures.
- Record an in-game UI smoke checklist and current panel/action coordinates.
- Run the current build and smoke test to establish a baseline.

### Phase 1: Clean the data/search core

- Extract skill taxonomy and shared enum traversal.
- Introduce the immutable descriptor catalog and ID index.
- Narrow `search.apply()` and remove unused result fields.
- Re-run ranking fixtures after each step.

### Phase 2: Extract state and orchestration

- Add the filter-state model and migrate one transition at a time.
- Replace repeated refresh cascades with explicit invalidation methods.
- Keep the old window layout and widget tree intact during this phase.

### Phase 3: Split presentation components

- Extract formatters and the stats presenter first because they are mostly pure.
- Centralize layout/action metadata.
- Extract picker/panel widgets only after their inputs and events are stable.
- Perform the full in-game mouse, focus, drag, resize, tooltip, refresh, and zoom
  smoke pass.

### Phase 4: Tooling and documentation

- Wire tests into the standard developer command.
- Refresh README and checklist links.
- Add package-structure verification.

## Changes not recommended without evidence

- Do not rewrite the Lua mod as a native plugin; the README already scopes C++
  out unless profiling demonstrates a need.
- Do not make resident collection lazy or incremental solely for code elegance.
  The snapshot model is simple and supports repeated filtering; profile a large
  fortress before changing it.
- Do not replace fixed UI geometry, CP437 labels, or manual hit testing with a
  new layout model unless the replacement preserves current rendering and
  interaction across supported terminal sizes.
- Do not change relevance weights or attribute/skill normalization during an
  architecture cleanup. Treat those as separate behavior changes with their
  own fixtures and rationale.

## Suggested completion criteria for `Cleanup code architecture`

The open checklist item in `docs/project.todo` can be considered complete when:

- ranking/evaluation/filter-state behavior has automated characterization;
- descriptors and skill taxonomy have one source of truth and indexed lookup;
- filter state is independent of the main window;
- one user action causes one controlled update pass;
- the main window is a composition/orchestration layer rather than a 1,500-line
  owner of every UI concern;
- layout and hitbox constants are centralized and in-game behavior is verified;
- README, checklist links, build/test commands, and package validation match the
  repository's actual workflow.
