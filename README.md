# SoulSearch

SoulSearch is a DFHack mod that searches fortress units by race, personality
traits, attributes, and skills. Race filters define the candidate set; the
other filters are ordered relevance criteria, so partial matches remain visible
while units matching more and higher-priority criteria rank first.

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
- Unit-scope and race-filter candidate providers choose units before snapshots;
  `search.apply()` receives only ranking filters and returns relevance-ranked
  results.
- `ui.lua` composes the window and coordinates events; formatting, layout,
  components, refresh dispatch, and Stats presentation have dedicated modules.
- `soulsearch` opens the panel with name search, race Include/Exclude scope
  filters, ordered high/low ranking filters, JSON-backed filter presets,
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
`soulsearch reload` clears runtime modules in reverse dependency order, runs
them again in dependency order, then validates the rebuilt set so a UI does not
retain mixed module generations. Close the SoulSearch window before reloading.

## Usage

After DFHack can see the script path, run:

```text
soulsearch
```

The first manual SoulSearch launch in a DFHack session adds the default
`Ctrl-F@dwarfmode/Default` binding when no existing binding runs a SoulSearch
command. Use `gui/keybinds` to change or remove it, then save from that screen
to persist your choice across DFHack restarts.

The command opens the SoulSearch panel in fortress mode. By default, its
unit scope is **Citizens** and its candidate race scope is **Humanoids**. Use
the **Search** dropdown to choose between Citizens, Residents, Visitors, and
All units. The active scope is marked in the dropdown list. Use **Add race filter** to
include another race or creature type, or
exclude a race from the included candidates. Race filters use `[+]` to Include
and `[-]` to Exclude and do not participate in ranking order. Use the Search
filters list to add traits, attributes, and skills such as `Agility`; set their
high/low directions and priorities with the controls beside each selected
filter. Click a result-list column header (Name, Unit ID, or Profession) to
sort it ascending, click again for descending, and click a third time to
restore relevance ranking. Arrows indicate the active column and direction.
The search field filters result names only. Press `z` or Enter on a selected
result to center and highlight that unit on the fortress map.

Select **Filter presets** in the Search filters panel to open the preset menu.
Choose **Save preset** and enter a name in the prompt to save the current race
scope, ranking-filter order, and directions; select a saved name and press
Enter to load it. Presets
are stored as individual JSON files under DFHack's mod-state directory,
`dfhack-config/mods/soulsearch/presets/`, so they survive mod updates.
Custom presets are listed first. The same menu also includes role presets and skill presets;
these are shipped configurations, not JSON files, with one preset for every current row in the
Dwarf Fortress Wiki's primary (A), secondary (B), and tertiary (C)
associated-attribute table; see
[`docs/preset-defaults.md`](docs/preset-defaults.md) for the mappings.
Use the preset menu's Search field to find a built-in skill or saved preset.

See [`docs/race-filtering.md`](docs/race-filtering.md) for the compound creature
types and implementation notes on candidate scope.

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
