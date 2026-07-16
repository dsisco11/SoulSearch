# DFHack widget audit

Audited against the installed DFHack 53.15-r1 `gui.widgets` implementation on
2026-07-16. The main conclusion is that SoulSearch already uses the native
widgets that match its ordinary controls. The remaining custom code owns
behaviour that the library does not provide, so there is no behaviour-preserving
widget-only replacement to make now.

## Native widgets already used

SoulSearch uses `Window`/`Panel` for framed containers, `TextButton` for its
button-like actions, `EditField` and `List` for editing and choice selection,
`CycleHotkeyLabel` for sortable headers, and `Divider` for the visual split
between results and Stats. `List` also supplies the native scrollbar used by
results and picker lists. These are appropriate direct uses rather than local
reimplementations.

## Custom patterns evaluated

| SoulSearch pattern | Closest native widget | Decision |
| --- | --- | --- |
| Search field plus picker list | `FilteredList` | Do not replace. `FilteredList` owns its own tokenized subword search, resets its edit text when choices are set, and filters individual rows. SoulSearch requires literal-substring queries, dynamic selected markers, no-match rows, and skill/preset section headers that remain meaningful after filtering. |
| Searchable and scope popouts | `Pages`, `Window` | Do not replace. `Pages` only selects one child; it does not open/close a focus scope, consume clicks within a popup, or implement SoulSearch's right-click close. `ModalPanelWindow` is the small shared behaviour layer that supplies those semantics. |
| Per-row `+`, `-`, move, and remove controls | `List`, `ButtonGroup` | Do not replace. `List` has one mouse action per row, while `ButtonGroup` represents one cycling value. `FilterActionList` needs five independently clickable zones for the particular row under the pointer. |
| Dynamic mouse tooltips | `TooltipLabel` | Do not replace. `TooltipLabel` is a wrapped static label whose visibility follows `show_tooltip`; it does not resolve a hovered descendant, anchor itself to the mouse, or remove/redraw on pointer exit. `TooltipAgent` and `SoulSearchTooltip` provide those missing behaviours. |
| Unit Stats body and fixed sortable headers | `List` | Do not replace. The present composition deliberately keeps `CycleHotkeyLabel` headers outside the scrolling body, supports column-specific tooltips, and calculates the overlay column around the native scrollbar. A bare `List` would not preserve this geometry or interaction. |
| Child layout that fills a resizable main window | `ResizingPanel` | Do not replace. `ResizingPanel` grows to the minimum bounds of its children; it does not distribute newly available parent space. `UnitInfoPanel:layout_contents()` is the correct mechanism for the variable-height identity/filter sections followed by a filling stats list. |

## Roadmap correction: `Divider`

`widgets.Divider` is purely a drawing widget: its implementation renders a
one-cell-thick line and T-junctions and declares no mouse or drag handling.
It cannot make adjacent panels resizable. Keep the existing divider for its
visual junction. If independent panel resizing is desired, implement a
SoulSearch splitter interaction (drag hit-testing, a clamped split position,
and layout recalculation) and continue to use `Divider` only to draw it.

## Future opportunities, if requirements change

- A simple, ungrouped picker that accepts DFHack's tokenized search semantics
  could use `FilteredList` directly.
- A screen with mutually exclusive full-size views could use `Pages` plus
  `TabBar`; neither shape matches the attached popouts or current filter flow.

No production Lua changes are recommended from this audit.
