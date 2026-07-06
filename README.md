# SoulSearch

SoulSearch is a DFHack mod that will provide an in-game panel for searching
fortress residents by personality traits, soul attributes, and related unit
data. Search filters are relevance criteria: selecting multiple attributes ranks
residents by how many criteria they match instead of excluding partial matches.

The first implementation target is a Lua-only DFHack command named
`soulsearch`. Native C++ plugin code is intentionally out of scope unless Lua
profiling later shows a real performance issue.

## Status

Phases 1-5 are in place:

- `info.txt` contains Dwarf Fortress/DFHack mod metadata.
- `scripts_modinstalled/soulsearch.lua` defines the public DFHack command.
- `scripts_modinstalled/internal/soulsearch/` contains private support modules.
- Resident collection snapshots names, professions, positions, traits, mental
  attributes, and physical attributes such as agility.
- Search descriptors and relevance-ranked results drive the panel.
- `soulsearch` opens an in-game panel with name search, checkbox-driven search
  filters, ranked results, resident details, refresh, zoom, and close controls.

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

## Publishing

Run the local Lua build check with:

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

This catches Lua parse/build errors only. DFHack APIs, UI widgets, and game
state behavior still need in-game validation.

Create a distributable zip with:

```powershell
.\tools\Publish.ps1
```

The archive is written to `dist/SoulSearch-<version>.zip` and contains the mod
payload from `src/`. The script also creates `dist/SoulSearch/`, which can be
copied directly into the Dwarf Fortress `mods/` folder.

## Usage

After DFHack can see the script path, run:

```text
soulsearch
```

At this stage the command opens the SoulSearch panel in fortress mode.
Use the Search filters list to select traits and attributes such as `Agility`.
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

See `docs/SoulSearch.todo` for the implementation checklist.
