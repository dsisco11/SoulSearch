# Built-in filter presets

The built-in job presets are selectable configurations. They are not written as
or loaded from user preset JSON files.

Their filter order follows the Dwarf Fortress Wiki's [Skills by associated
attributes table](https://dwarffortresswiki.org/index.php/Attributes#Skills_by_associated_attributes):
primary `A` attributes first, followed by `B`, then `C`. This matches
SoulSearch's priority-based ranking.

| Preset | Wiki skill rows used | Ordered attributes |
| --- | --- | --- |
| Miner | Miner | Strength, Kinesthetic Sense, Toughness, Spatial Sense, Endurance, Willpower |
| Marksdwarf | Crossbowman | Agility, Spatial Sense, Kinesthetic Sense, Focus |
| Scholar | Critical Thinker, Logician, Mathematician | Analytical Ability, Memory, Intuition |
| Sheriff | Fighter | Agility, Spatial Sense, Kinesthetic Sense, Strength, Willpower, Toughness, Endurance |
| Manager | Organizer | Analytical Ability, Memory, Intuition |

`Scholar`, `Sheriff`, and `Manager` are roles rather than rows in the table, so
each is derived from its defining skill rows. In particular, Sheriff is based
on the Fighter row because the role performs law enforcement through beatings
or imprisonment. The [Sheriff wiki page](https://dwarffortresswiki.org/index.php/Sheriff)
describes that role.
