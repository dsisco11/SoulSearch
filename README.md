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

## Development Setup

For local development without repeatedly copying files, add this line to
`dfhack-config/script-paths.txt`:

```text
+D:/CODE/DFHack/DwarfSearch/src/scripts_modinstalled
```

The leading `+` tells DFHack to search this development copy before other script
directories.

## Usage

After DFHack can see the script path, run:

```text
dwarfsearch
```

At this stage the command opens the DwarfSearch panel in fortress mode.
Press `z` or Enter on a selected result to center and highlight that resident on
the fortress map.

## Roadmap

See `docs/DwarfSearch.todo` for the implementation checklist.
