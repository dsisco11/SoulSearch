# SoulSearch

SoulSearch is a DFHack mod that provides an in-game panel for searching fortress
residents by personality traits, attributes, and skills. Search filters are
ordered relevance criteria: partial matches remain visible, while residents who
match more and higher-priority criteria rank first.

SoulSearch is implemented as the Lua-only DFHack command `soulsearch`. Native
C++ plugin code remains out of scope unless profiling later identifies a real
performance requirement.

## Status

The current implementation includes:

- `info.txt` contains Dwarf Fortress/DFHack mod metadata.
- `scripts_modinstalled/soulsearch.lua` defines the public DFHack command.
- `scripts_modinstalled/internal/soulsearch/` contains private support modules.
- Resident collection reads stable DFHack APIs into compact snapshots of names,
  professions, traits, attributes, and skills. Position is intentionally read
  live only when zooming.
- The immutable descriptor catalog owns filter metadata; `filter_state.lua`
  owns ordered `{id, direction}` state for the loaded script session.
- `search.apply()` accepts rows, a name query, and ordered selected filters,
  then returns relevance-ranked results.
- `ui.lua` composes the window and coordinates events; formatting, layout,
  components, refresh dispatch, and Stats presentation have dedicated modules.
- `soulsearch` opens the panel with name search, ordered high/low filters,
  ranked results, Stats, refresh, zoom, and close controls.

The command currently validates fortress mode and opens the resident search
panel.

## Installation

Copy the contents of `src/` into a Dwarf Fortress mod folder, for example
`mods/SoulSearch/`. DFHack will discover scripts from
`scripts_modinstalled/` when the mod is installed.

Dwarf Fortress does not load mods directly from zip files in `mods/`. The final
installed path must look like this:

```text
mods/SoulSearch/info.txt
mods/SoulSearch/scripts_modinstalled/soulsearch.lua
```

If you extract the release zip, make sure the extraction tool does not add an
extra wrapper folder such as `mods/SoulSearch-0.1.0/SoulSearch/info.txt`.

## Development Setup

For local development without repeatedly copying files, add this line to
`dfhack-config/script-paths.txt`:

```text
+D:/CODE/DFHack/SoulSearch/src/scripts_modinstalled
```

The leading `+` tells DFHack to search this development copy before other script
directories.

## Validation and publishing

Run the syntax-only Lua build check with:

```powershell
.\tools\Build.ps1
```

The build checks every `.lua` file under `src/scripts_modinstalled/` for syntax
errors using `luac -p`, or `lua` with `loadfile()` if `luac` is not available.
Install Lua on PATH or pass a specific executable path:

```powershell
.\tools\Build.ps1 -LuaPath "C:\path\to\luac.exe"
.\tools\Build.ps1 -LuaPath "C:\path\to\lua.exe" -LuaMode Lua
```

This checks Lua syntax only. It does not exercise DFHack APIs, widgets, or game
state.

Run pure Lua tests with:

```powershell
.\tools\Test.ps1
```

The tests cover domain rules, filter transitions, ranking, formatting, layout,
module lifecycle, resident snapshot transformation, and package-independent
logic. They do not replace an in-game smoke pass.

Create a distributable zip with:

```powershell
.\tools\Publish.ps1
```

`Publish.ps1` creates `dist/SoulSearch-<version>.zip` and `dist/SoulSearch/`,
then verifies both contain exactly the payload under `src/`: root `info.txt`,
the public command, and every runtime Lua module, with no tests or docs. The
expanded folder can be copied directly into the Dwarf Fortress `mods/` folder.

Run the interactive fortress-mode smoke checklist separately in
[`docs/ui-baseline.md`](docs/ui-baseline.md). That is the gate for visual
layout, focus, mouse handling, refresh, and live zoom behavior.

For development reloads, use:

```text
soulsearch reload
```

Normal `soulsearch` execution validates the retained internal-module contracts.
`soulsearch reload` clears internal script environments in reverse dependency
order, then reloads and validates them forward so a UI does not retain mixed
module generations.

## Usage

After DFHack can see the script path, run:

```text
soulsearch
```

The command opens the SoulSearch panel in fortress mode. Use the Search filters
list to add traits, attributes, and skills such as `Agility`; set their high/low
directions and priorities with the controls beside each selected filter.
The search field filters resident names only. Press `z` or Enter on a selected
result to center and highlight that resident on the fortress map.

## Troubleshooting

If DFHack says `soulsearch` is not a recognized command, DFHack has not added
the mod's `scripts_modinstalled/` directory to its script paths yet.

For development, the most reliable fix is to add this line to
`dfhack-config/script-paths.txt` and restart DFHack:

```text
+D:/CODE/DFHack/SoulSearch/src/scripts_modinstalled
```

For a packaged install, verify the installed folder is extracted like this and
then restart DFHack:

```text
mods/SoulSearch/info.txt
mods/SoulSearch/scripts_modinstalled/soulsearch.lua
```

Do not leave the mod only as `mods/SoulSearch-0.1.0.zip`, and avoid nested
extraction paths like `mods/SoulSearch-0.1.0/SoulSearch/info.txt`.

## Roadmap

The product roadmap is [`docs/project.todo`](docs/project.todo). Architecture
cleanup analysis and its historical implementation checklist are in
[`docs/cleanup-report.md`](docs/cleanup-report.md) and
[`docs/cleanup.todo`](docs/cleanup.todo).
