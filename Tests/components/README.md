# SoulSearch Component Specs

This directory contains live DwarfSpec component tests. DwarfSpec discovers
files named `*.ds.lua` recursively beneath `tests/`.

Component specs exercise behavior that requires a real DFHack widget tree,
renderer, focus system, pointer, screen host, or overlay lifecycle. Pure search,
filtering, sorting, formatting, persistence, and catalog behavior remains in
the ordinary Busted suite.

Reusable fixtures belong in `support/` as ordinary `.lua` modules. Specs must
import those modules explicitly and use Busted's native spies and mocks for
callback assertions.

Use `ds.get(view_id)` and fluent subjects for traversal and interaction. Call
`subject:raw()` only when the required native state is not exposed by
DwarfSpec, and keep that exception local to the assertion that needs it.

DwarfSpec owns component cleanup after every example. Specs should not perform
manual cleanup unless cleanup behavior itself is under test, and must not
persist settings, stage scripts, or mutate live units as fixture preparation.

DwarfSpec adds the consumer project root to `package.path`, so live specs can
import shared modules directly, for example
`require('tests.components.support.fixtures')`.

Run discovery without loading the specs:

```powershell
dwarfspec list
```

Run the live component suite:

```powershell
dwarfspec run
```
