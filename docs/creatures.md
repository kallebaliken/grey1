# Creature definitions and authored spawning

`creatures/creature_defs.lua` contains immutable authored kinds; `creatures/creature_registry.lua` validates and owns copies. A definition has a stable `id`, an `actor_type`, optional validated faction/dialogue references, an optional display name, optional `combat.max_health`, optional fixed `attack` metadata, and optional prototype `render` color/size. Attack metadata requires combat metadata. Callers receive copies from `get` and `get_all`, so they cannot mutate canonical definitions.

`creatures/creatures.lua` is a pure-Lua composition service. Given a definition-backed map placement, it creates the generic Actor, places it through world occupancy, associates Actor instance ID to definition ID externally, and delegates optional health and attack setup to the existing combat registry and attack service. Definitions never become Actor fields. Multiple instances may share one definition while retaining independent positions, health, cooldowns, and death state.

```lua
{ id = "monster_test_rat", creature = "rat", x = 14, y = 10, z = 7, facing = "west" }
```

The player remains explicitly composed because it additionally owns inventory/equipment and persisted player state. `test_villager` inherits `townsfolk` and references the one test dialogue, but intentionally has no CombatState or attack profile. `rat` inherits `vermin`, has 20 health and a fixed attack profile, but has no dialogue and remains inert: capability, relationship, and dialogue data are not AI or decision-making.

Creature render metadata feeds the temporary Actor renderer. Actors without a creature association retain canonical Actor-type fallback colors. Immutable definitions are not saved; only supported runtime state is eligible for snapshots, and general NPC/monster persistence remains deferred.

Canary `MonsterType`/NPC configuration concepts map only to Greyhaven CreatureDefinition plus composed optional runtime systems. XML content, think loops, spells, loot, summons, voices, target switching, and server scheduling are not imported.
