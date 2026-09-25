# Canary system map

This audit records concepts, not code to port. It sampled the major ownership boundaries in `src/map`, `src/items`, `src/creatures`, `src/game`, `src/lua`, the datapack script categories, persistence, networking, and build/deployment directories.

## Classification key

- **KEEP AS CONCEPT** — the domain idea belongs in Greyhaven, but not necessarily its representation.
- **REIMPLEMENT** — build a small Defold/Lua equivalent behind Greyhaven APIs.
- **NOT NEEDED** — multiplayer/server concern excluded from the game runtime.
- **REVIEW LATER** — potentially useful after core single-player needs are proven.

## World and movement

| Canary area | Decision | Greyhaven treatment |
|---|---|---|
| `Position` and directions | KEEP AS CONCEPT / REIMPLEMENT | Plain value tables, position keys, and explicit Z. No unsigned-coordinate or protocol constraints. |
| `Tile`, down/top item order, creatures | KEEP AS CONCEPT / REIMPLEMENT | A tile has ground, ordered objects, and an actor slot; stable renderer layers replace client stack positions. |
| `Map`, sectors/cache, spectators | REIMPLEMENT | Map loading and grid queries remain. Network spectators, cache synchronization, and server hot-path machinery do not. Chunk streaming can be added from measured need. |
| A* nodes, walk checks, line of sight | KEEP AS CONCEPT / REIMPLEMENT | A* queries authoritative Lua world state; Defold physics is not navigation authority. |
| OTBM/XML maps and house/town loading | NOT NEEDED | Use a documented Greyhaven Lua/JSON schema suitable for an external editor. |
| Teleports, movement events, floor changes | KEEP AS CONCEPT / REIMPLEMENT | Data-driven interactions and explicit Z transitions emit local events. |
| Player-owned online houses | NOT NEEDED | Buildings are ordinary shared-world geometry and persistent object state. |

### Implemented Greyhaven replacements

The current runtime now replaces the relevant `Position`, tile stack, object/type identity, creature occupancy, movement-destination validation, teleport/floor transition, and world-query concepts with pure Lua modules. Bounded deterministic A* uses Manhattan distance and authoritative walkability directly across chunk boundaries. Canary creature route execution maps to a separate Greyhaven path controller that feeds supplied steps through shared movement and interpolation; it has no creature think loop, scheduler, autonomous goal selection, or network coupling. Door and stair notifications are semantic local events rather than Canary spectator/protocol updates.

## Objects and items

| Canary area | Decision | Greyhaven treatment |
|---|---|---|
| `Thing`/`Cylinder` ownership hierarchy | KEEP AS CONCEPT | Preserve containment and destination validation, not deep polymorphism. Use tables plus focused functions. |
| `ItemType`, `Item`, typed/custom attributes | REIMPLEMENT | Immutable definitions plus small instance-state tables and schema validation. Avoid an unrestricted attribute bag for core fields. |
| `Container` and safe nested traversal | KEEP AS CONCEPT / REIMPLEMENT | Reusable bounded container model for bags, chests, corpses, and furniture, independent of UI. |
| Weapons, decay, beds, doors, fields | REVIEW LATER | Implement only mechanics demanded by Greyhaven content, through interactions/components. |
| Depot, inbox, mailbox, store/reward containers | NOT NEEDED | Online delivery and account services have no single-player role. |

## Actors and gameplay

| Canary area | Decision | Greyhaven treatment |
|---|---|---|
| Creature/player/monster/NPC common state | KEEP AS CONCEPT / REIMPLEMENT | Shallow composition for position, health, movement, conditions, inventory, faction, and AI. |
| Monster targeting/pathfinding/spawns | REIMPLEMENT | Deterministic local AI and map-authored spawn rules; no online relevance scheduler. |
| Combat, conditions, spells | KEEP AS CONCEPT / REIMPLEMENT | Minimal data-driven formulas, local time, events, and explicit condition lifecycle. |
| Zones | KEEP AS CONCEPT / REIMPLEMENT | Named map areas for triggers, ambience, AI, and rules—not PvP/server policy. |
| Party, guild, VIP, waitlist, bans, highscores, livestream | NOT NEEDED | Multiplayer community/account features. |
| Vocations, achievements, crafting/imbuements | REVIEW LATER | Add original progression only when game design requires it. |

## Scripting and content

| Canary area | Decision | Greyhaven treatment |
|---|---|---|
| Lua-driven actions, movement, creatures, NPCs | KEEP AS CONCEPT | Continue data/script-driven authoring because Lua is native in Defold. |
| C++ Lua binding layer and userdata | NOT NEEDED | Greyhaven modules communicate as Lua values and messages. |
| Server scheduler/global events/raids | NOT NEEDED | Defold update/timers and a session event bus cover local gameplay. Long-lived work will use stable IDs and cancellation. |
| Canary/OTServBR datapack content | NOT NEEDED | Do not ship copied maps, lore, creatures, scripts, or proprietary-derived assets. Author Greyhaven content. |
| Quests, doors, actions as script categories | KEEP AS CONCEPT / REIMPLEMENT | Small registries subscribe to semantic events and use stable IDs. |

Door, stair, and placeholder chest actions now use the registered interaction dispatcher. This validates the category/registration concept without adopting the C++ Lua binding layer or `Cylinder` hierarchy.

Canary `Creature` health/change/death concepts now map to a composed Greyhaven CombatState and deterministic explicit-damage API. Formula calculation, schedulers, conditions, PvP policy, experience, loot, network messages, and server death processing are not part of this foundation.

Canary creature attack execution now maps to an explicit deterministic Actor attack service that validates a caller-supplied target and delegates fixed damage to CombatState. It does not retain Canary weapon/skill formulas, attack scheduling, PvP, conditions, spells, critical hits, imbuements, networking, or combat messages; attack capability is not decision-making AI.

Canary `ItemType` weapon/combat concepts map only to validated Greyhaven item `weapon.damage` metadata, explicit main-hand damage resolution, and the existing CombatState mutation path. The equipped logical item keeps its normal stable identity; skills, hit/defense formulas, weapon speed, imbuements, ammo, charges, critical hits, PvP modifiers, and server scheduling are not carried over.

Canary equipment/defense concepts map to positive-integer Greyhaven `armor.defense` metadata, a deterministic equipped-item mitigation resolver, and the same CombatState damage path. Shielding skills, block chance, random/formula reduction, PvP modifiers, elemental resistance, conditions, imbuements, and durability remain excluded.

## Infrastructure

| Canary area | Decision | Greyhaven treatment |
|---|---|---|
| Protocols, sockets, login/account/auth/security | NOT NEEDED | No multiplayer transport or account boundary. |
| SQL, migrations, KV, online persistence | NOT NEEDED | Versioned local save files store deltas from static maps. |
| Docker server deployment, metrics, website integration | NOT NEEDED | Defold desktop/mobile bundles replace server operations. |
| Dispatcher and multithreaded server scheduling | NOT NEEDED | Use Defold's frame loop and narrowly scoped workers only if profiling later justifies them. |
| Logging/configuration/test concepts | REVIEW LATER | Add Greyhaven-specific diagnostics, preferences, and CI rather than carrying server frameworks. |

## Architectural lesson

Canary places authoritative simulation, persistence, scripting integration, and client synchronization in intertwined server objects. Greyhaven keeps the valuable grid, stacking, definitions, containment, actor, and event concepts but separates pure local domain modules from Defold presentation adapters. This deliberately trades MMO concurrency and protocol fidelity for inspectable state, deterministic saves, and editor-friendly content.
