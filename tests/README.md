# SoulSearch pure Lua tests

Run the suites from the repository root with:

```powershell
.\tools\Test.ps1
```

The repository uses a small dependency-free runner in `tests/support/testlib.lua`.
`tests/run.lua` loads a fixed suite list, so test discovery and ordering are
deterministic. Test failures print the case name, expected/actual context, and a
traceback; any failure produces a nonzero process exit code.

Tests load the production Lua files directly with an isolated environment. The
environment stubs only the external APIs needed by the modules under test:

- `reqscript('modtools/set-personality')` supplies deterministic caste trait
  baselines and trait tiers.
- Physical, mental, personality, and job-skill enums contain the small sparse
  subsets exercised by fixtures, including caption metadata and an explicitly
  uncategorized future-skill case.
- `df.global.world.raws.creatures.all` contains one creature raw with physical
  and mental attribute medians.
- `reqscript('internal/soulsearch/attributes')` gives `search.lua` the actual
  production attribute module loaded by the test environment.
- The enum adapter, skill taxonomy, and descriptor catalog are loaded directly
  from their production files; only their DF enum data is supplied by fixtures.
- The production filter-state model is loaded with the real descriptor catalog;
  transition, validation, ordered serialization, and persistence-copy behavior
  are exercised without widget stubs.
- The production UI refresh dispatcher is exercised with a counting owner to
  prove picker-only changes skip results and each result invalidation invokes
  recomputation once.
- Production text matching, formatting, stats presentation, and layout metadata
  run against pure fixtures that preserve exact padding, pens, CP437 bytes,
  sorting, panel boundaries, and filter-action hitboxes.
- UI component factories run with inert widget constructors to verify explicit
  inputs and focus-sensitive child order without pretending to emulate DFHack
  widget behavior.

The tests do not emulate DFHack widget behavior or claim to validate in-game
behavior. Visual layout, focus, mouse handling, live unit access, refresh, and
zoom remain covered by the manual checklist in `docs/ui-baseline.md`.

The `tests/` tree is outside `src/`; `tools/Publish.ps1` packages only `src/`, so
test code is not included in the shipped mod payload.
