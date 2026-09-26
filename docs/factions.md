# Authored faction relationships

Greyhaven factions are pure authored identity and relationship data. `factions/faction_defs.lua` defines the minimal `player`, `townsfolk`, and `vermin` records. Each definition has only a stable ID and display name. `factions/faction_registry.lua` owns validated copies and returns isolated snapshots.

The canonical relationship vocabulary in `factions/relationships.lua` is `friendly`, `neutral`, and `hostile`. Relationships are directional: the registry never mirrors an authored edge. An unconfigured pair of valid, different factions is `neutral`; a faction implicitly regards itself as `friendly` unless an explicit self-edge overrides that default. Unknown faction IDs are rejected.

`factions/factions.lua` separately associates registered Actor instance IDs with faction IDs. The player is explicitly associated with `player`; creature composition inherits `townsfolk` or `vermin` from the creature definition. An Actor may remain unaffiliated, in which case Actor-to-Actor queries involving it return `neutral`. Placement overrides are deliberately deferred, so authored placement data cannot silently change definition faction identity in this slice.

The boundary is strict:

- Factions answer **“What is the relationship?”**
- Future AI decides **“What should I do about it?”**
- Future combat policy decides **“Am I allowed to attack?”**
- Future dialogue decides **“How should I speak?”**
- Future reputation decides **“Has this relationship changed?”**

Queries never move, target, attack, speak, recolor, or otherwise mutate Actors. Existing explicit attacks remain allowed regardless of relationship. Definitions and associations reconstruct from authored player/creature composition and are not saved; there is no dynamic reputation state.

Canary skull, party, guild, and creature-hostility concepts are only loose architectural references. Greyhaven does not import PvP skulls, guild wars, parties, player-killing policy, crime, or reputation mechanics.
