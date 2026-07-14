# Stats subject contract

Phase 1 defines the data shape shared by the full-window Stats panel and the
future unit-card popover. Phase 2 will make this contract executable through
`stats_subject.lua`; this document intentionally does not add a second runtime
implementation.

## `SoulSearchStatsSubject`

A Stats subject has these fields:

- `unit`: the compatible `df.unit` being presented;
- `unit_id`: a stable, non-negative integer snapshot used for identity;
- `row`: a `SoulSearchResidentRow`-shaped snapshot for that unit;
- `name`: display name;
- `profession`: display profession; and
- `filter_criteria`: an ordered sequence of selected ranking criteria.

Normal `SoulSearchResult` values satisfy this structure: they retain the unit,
unit ID, row, presentation strings, and filter criteria consumed by the current
Stats presenters. A unit-card subject uses the same shape with an empty
`filter_criteria` sequence. Hosts must compare subjects by `unit_id`, not by a
live unit reference.

`SoulSearchResidentRow` remains the historical internal type name. It is a
snapshot shape for any compatible `df.unit`, including a unit without a current
soul, and is not being renamed as part of this refactor.

## Intentional copy correction

The pre-refactor Stats header used resident-specific empty and fallback copy:
`No resident selected.` and `Unknown resident`. Phase 1 changes those shared
strings to `No unit selected.` and `Unknown unit` so both hosts use accurate,
neutral terminology. This is an intentional cross-host correction, not an
extraction regression.
