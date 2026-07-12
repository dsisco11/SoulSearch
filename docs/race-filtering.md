# Race filtering

Race filters select which units are candidates for SoulSearch. They are applied
before unit snapshots and relevance ranking. Attribute, trait, and skill filters
remain ranking criteria and keep their existing high/low directions and order.

The default candidate scope is **Humanoids**. A race filter can be included or
excluded. Included filters are combined; exclusions are then removed from that
combined set. If no valid included race filter remains, SoulSearch restores
Humanoids automatically. The serialized preset values remain `high` and `low`
for compatibility, although the UI presents them as Include and Exclude for
race filters.

## Creature types

The race picker lists these compound creature types before individual creature
raw IDs, which are ordered alphabetically by display label:

- **Humanoids**: a caste with both `CAN_LEARN` and `CAN_SPEAK`.
- **Trainable Animals**: a caste with `PET`, `PET_EXOTIC`,
  `TRAINABLE_HUNTING`, or `TRAINABLE_WAR`.
- **Domestic Animals**: a `COMMON_DOMESTIC` caste with a pet, pack-animal,
  wagon-puller, or mount role.
- **Wild Animals**: a `NATURAL` caste that is not humanoid.
- **Megabeasts**: a caste with `MEGABEAST` or `SEMIMEGABEAST`.
- **Vermin**: a caste with one of Dwarf Fortress's `VERMIN_*` flags.

## Internal candidate scope

SoulSearch currently uses the internal `citizens_and_pets` unit scope: active,
fort-controlled units. The provider layer also supports `fort_residents` and
`all_active` for future internal callers. These are not user-facing settings;
the race picker is the supported way to adjust the candidate set.
