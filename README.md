# DwarfSearch

DwarfSearch is a DFHack mod that will provide an in-game panel for searching
fortress residents by personality traits, soul attributes, and related unit
data. Search filters are relevance criteria: selecting multiple attributes ranks
residents by how many criteria they match instead of excluding partial matches.

The first implementation target is a Lua-only DFHack command named
`dwarfsearch`. Native C++ plugin code is intentionally out of scope unless Lua
profiling later shows a real performance issue.

## Status

Phase 1 scaffolding is in place:

- `info.txt` contains Dwarf Fortress/DFHack mod metadata.
- `scripts_modinstalled/dwarfsearch.lua` defines the public DFHack command.
- `scripts_modinstalled/internal/dwarfsearch/` contains private support modules.

The command currently validates fortress mode and reports how many residents it
can collect. Search, filters, and UI are planned in later phases.

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

At this stage the command validates fortress mode and reports the number of
residents collected for the future search panel.

## Roadmap

See `docs/DwarfSearch.todo` for the implementation checklist.
