# Deterministic creature perception

CreatureDefinitions may optionally author `{ perception = { sight_range = N } }`, where `N` is a positive integer logical-tile radius. Creature composition associates a copied configuration with each spawned Actor outside the generic Actor model. Configuration and awareness results are derived data and are never saved.

Perception is an omnidirectional, read-only query over current authoritative Actor positions. Targets must be active, living when they have CombatState, on the observer's Z level, and within Manhattan distance. The observer must likewise be active and living. Actors without CombatState are treated as living. Results exclude self and sort by stable Actor ID.

Line of sight traces between logical tile centres. Exact grid-corner ties step diagonally; only visited intervening tiles may block sight. Observer and target endpoints are excluded from blocker checks, and Actors never occlude one another. Object definitions explicitly own `blocks_sight` or `blocks_sight_state`; collision and graphical footprint do not imply visibility blocking. Walls block sight, while an authored door blocks only while closed. Ground, items, Actors, and non-sight-blocking furniture remain transparent.

Awareness entries may include faction identity and the observer-to-target relationship for diagnostics, but faction never filters visibility. Perception does not call pathfinding, movement, attacks, dialogue, or Actions, and it stores no targets, memories, suspicion, or last-seen positions.

```text
Actor                   owns identity and authoritative position
CreatureDefinition      may provide perception capability
Perception              answers who is currently observable
Faction                 answers relationship
Future Target Selection chooses which perceived Actor matters
Future AI               decides what to do
Pathfinding             determines how to travel
Attack Service          performs an explicitly requested attack
```
