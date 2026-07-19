# SoulSearch pure Lua tests

Run the suites from the repository root with:

```powershell
.\tools\Run-UnitTests.ps1
```

Lua and LuaRocks must be available on PATH. The entrypoint bootstraps Busted
2.3.0-1 and its required `luasystem 0.3.0-2` into the ignored repository-local
`.luarocks/` tree when absent. `.busted` discovers sorted `*_spec.lua` files
and runs cases in deterministic order. All remaining arguments pass directly to
Busted. For example, run one selected case with:

```powershell
.\tools\Run-UnitTests.ps1 --filter="resolves the repository"
```

The complete suite currently reports 328 successes and four known search-ranking
failures. Busted prints the case name, expected/actual context, and traceback;
any failure produces a nonzero process result after the runner restores its
temporary `LUA_PATH` and `LUA_CPATH` values.

To exercise the opt-in runner-failure path, set the neutral smoke variable and
target the setup spec. This intentionally reports one failure and returns a
nonzero result:

```powershell
$env:UNIT_TEST_SMOKE_FORCE_FAILURE = '1'
try {
    .\tools\Run-UnitTests.ps1 --filter=propagates
} finally {
    Remove-Item Env:UNIT_TEST_SMOKE_FORCE_FAILURE -ErrorAction SilentlyContinue
}
```

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
- Resident row tests use plain snapshot fixtures; collection fixtures cover
  missing souls, personalities, attributes, translations, and unknown skills.
  Expected absence is handled explicitly, while unexpected DFHack API errors
  remain visible instead of being converted into missing data.
- Lifecycle fixtures prove descriptor, race-median, and skill-name caches are
  reused within a world and reset only at the explicit world boundary.
- The production module registry validates real module contracts and defines a
  complete dependency-safe clear/reload order for development reloads.

The tests do not emulate DFHack widget behavior or claim to validate in-game
behavior. Visual layout, focus, mouse handling, live unit access, refresh, and
zoom remain covered by the manual checklist in `docs/ui-baseline.md`.

The `Tests/` tree is outside `src/`; `tools/Publish.ps1` packages only `src/`, so
test code is not included in the shipped mod payload.

Run `Tests/package_tools_test.ps1` with PowerShell to exercise the reusable
publisher and verifier against an isolated fixture. It covers absolute and
repository-relative paths, flat zip layout, manifest diagnostics, non-live
custom-source builds, tampered packages, and temporary-directory cleanup.
