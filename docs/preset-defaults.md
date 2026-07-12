# Skill presets

Skill presets are selectable configurations. They are not written as or loaded
from custom preset JSON files.

SoulSearch includes one skill preset for each of the table's 137 current
skill rows. There are no inferred occupation or role presets. Their filter
order follows the table's primary `A` attributes first, followed by `B`, then
`C`, which matches SoulSearch's priority-based ranking.

The canonical source data is the compact `WIKI_ROWS` table in
`filter_defaults.lua`. Its `marks` column maps directly to the 17 Wiki
attribute columns, preventing the mapping from drifting through manual
interpretation.
