# SoulSearch Component Specs

This directory contains live DwarfSpec component tests. DwarfSpec discovers
files named `*.ds.lua` recursively beneath `tests/`.

Component specs exercise behavior that requires a real DFHack widget tree,
renderer, focus system, pointer, screen host, or overlay lifecycle. Pure search,
filtering, sorting, formatting, persistence, and catalog behavior remains in
the ordinary Busted suite.

Reusable fixtures and callback recorders belong in `support/` as ordinary
`.lua` modules. Specs must import those modules explicitly.

Run discovery without loading the specs:

```powershell
dwarfspec list
```

Run the live component suite:

```powershell
dwarfspec run
```
