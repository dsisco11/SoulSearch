--@ module=true

---Shared protocol values for filter selection, ranking, and unit scope.
---These values are intentionally the serialized strings used by saved presets.
FILTER_CONSTANTS = {}

---@enum SoulSearchFilterDirection
FILTER_CONSTANTS.direction = {
    HIGH='high',
    LOW='low',
}

---@enum SoulSearchFilterBehavior
FILTER_CONSTANTS.behavior = {
    CANDIDATE='candidate',
    RANKING='ranking',
}

---@enum SoulSearchFilterKind
FILTER_CONSTANTS.kind = {
    RACE='race',
}

---@enum SoulSearchUnitScope
FILTER_CONSTANTS.unit_scope = {
    ALL_ACTIVE='all_active',
    FORT_RESIDENTS='fort_residents',
    CITIZENS_AND_PETS='citizens_and_pets',
}
FILTER_CONSTANTS.default_unit_scope =
    FILTER_CONSTANTS.unit_scope.CITIZENS_AND_PETS

FILTER_CONSTANTS.race = {
    group_id_prefix='race:group:',
    raw_id_prefix='race:raw:',
    group={
        HUMANOIDS='HUMANOIDS',
        TAMEABLE_ANIMALS='TAMEABLE_ANIMALS',
        WORK_ANIMALS='WORK_ANIMALS',
        DOMESTIC_ANIMALS='DOMESTIC_ANIMALS',
        WILD_ANIMALS='WILD_ANIMALS',
        MEGABEASTS='MEGABEASTS',
        VERMIN='VERMIN',
    },
}
FILTER_CONSTANTS.default_race_filter_id =
    FILTER_CONSTANTS.race.group_id_prefix .. FILTER_CONSTANTS.race.group.HUMANOIDS
