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
- `df.physical_attribute_type` and `df.mental_attribute_type` contain the small
  enum subsets exercised by fixtures.
- `df.global.world.raws.creatures.all` contains one creature raw with physical
  and mental attribute medians.
- `reqscript('internal/soulsearch/attributes')` gives `search.lua` the actual
  production attribute module loaded by the test environment.

The tests do not stub DFHack widgets or claim to validate in-game behavior.
Visual layout, focus, mouse handling, live unit access, refresh, and zoom remain
covered by the manual checklist in `docs/ui-baseline.md`.

The `tests/` tree is outside `src/`; `tools/Publish.ps1` packages only `src/`, so
test code is not included in the shipped mod payload.
