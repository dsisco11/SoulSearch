# DwarfSearch

DwarfSearch is a DFHack mod that will provide an in-game panel for searching
fortress residents by personality traits, soul attributes, and related unit
data. Search filters are relevance criteria: selecting multiple attributes ranks
residents by how many criteria they match instead of excluding partial matches.

The first implementation target is a Lua-only DFHack command named
`dwarfsearch`. Native C++ plugin code is intentionally out of scope unless Lua
profiling later shows a real performance issue.

## Status

Phases 1-5 are in place:

- `info.txt` contains Dwarf Fortress/DFHack mod metadata.
- `scripts_modinstalled/dwarfsearch.lua` defines the public DFHack command.
- `scripts_modinstalled/internal/dwarfsearch/` contains private support modules.
- Resident collection snapshots names, professions, positions, traits, and
  mental attributes.
- Search descriptors and relevance-ranked results drive the panel.
- `dwarfsearch` opens an in-game panel with name search, checkbox-driven search
  filters, ranked results, resident details, refresh, zoom, and close controls.

The command currently validates fortress mode and opens the resident search
panel.

## Installation

Copy the contents of `src/` into a Dwarf Fortress mod folder, for example
`mods/DwarfSearch/`. DFHack will discover scripts from
`scripts_modinstalled/` when the mod is installed.

Dwarf Fortress does not load mods directly from zip files in `mods/`. The final
installed path must look like this:

```text
mods/DwarfSearch/info.txt
mods/DwarfSearch/scripts_modinstalled/dwarfsearch.lua
```

If you extract the release zip, make sure the extraction tool does not add an
extra wrapper folder such as `mods/DwarfSearch-0.1.0/DwarfSearch/info.txt`.

## Development Setup

For local development without repeatedly copying files, add this line to
`dfhack-config/script-paths.txt`:

```text
+D:/CODE/DFHack/DwarfSearch/src/scripts_modinstalled
```

The leading `+` tells DFHack to search this development copy before other script
directories.

## Publishing

Create a distributable zip with:

```powershell
.\tools\Publish.ps1
```

The archive is written to `dist/DwarfSearch-<version>.zip` and contains the mod
payload from `src/`. The script also creates `dist/DwarfSearch/`, which can be
copied directly into the Dwarf Fortress `mods/` folder.

## Usage

After DFHack can see the script path, run:

```text
dwarfsearch
```

At this stage the command opens the DwarfSearch panel in fortress mode.
Press `z` or Enter on a selected result to center and highlight that resident on
the fortress map.

## Troubleshooting

If DFHack says `dwarfsearch` is not a recognized command, DFHack has not added
the mod's `scripts_modinstalled/` directory to its script paths yet.

For development, the most reliable fix is to add this line to
`dfhack-config/script-paths.txt` and restart DFHack:

```text
+D:/CODE/DFHack/DwarfSearch/src/scripts_modinstalled
```

For a packaged install, verify the installed folder is extracted like this and
then restart DFHack:

```text
mods/DwarfSearch/info.txt
mods/DwarfSearch/scripts_modinstalled/dwarfsearch.lua
```

Do not leave the mod only as `mods/DwarfSearch-0.1.0.zip`, and avoid nested
extraction paths like `mods/DwarfSearch-0.1.0/DwarfSearch/info.txt`.

## Roadmap

See `docs/DwarfSearch.todo` for the implementation checklist.
