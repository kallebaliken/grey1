# Health and death foundation

## Decision

Canary's `Creature` health and `changeHealth`/death flow are coupled to combat formulas, conditions, scheduling, loot, experience, PvP rules, and network messages. Greyhaven preserves only the underlying concept as a composed pure-Lua `CombatState` plus deterministic damage registry:

```text
Canary Creature health/death
→ Greyhaven composed CombatState + deterministic damage API
```

`combat/health.lua` owns the invariant `0 <= health <= max_health` for positive integer maximum health. `combat/registry.lua` associates copied health state with known world Actor IDs, rejects non-positive or fractional damage, applies the exact supplied amount, clamps overkill to zero, and emits `actor_damaged` followed once by `actor_died`. Damage against a dead Actor returns `actor_dead` without mutation or events. Registry queries return snapshots, and `remove` explicitly clears both combat state and its Actor capability policies.

## Death policy

A dead Actor remains registered, rendered, identifiable, and occupying its tile. It cannot begin movement or ordinary interaction. The shared capability policy defaults to allowing Actors without combat state, preserving existing fixtures and incremental migration. A supplied path stops as `blocked` when its next shared-movement step is rejected after death; there is no replanning.

The player starts with 100 health and Save Format v4 persists the player's current/max health and dead flag. The authored `monster_test_rat` starts with 20 health after every session construction or F8 reset. Static NPC/monster combat persistence is deferred until Actor persistence has a general delta model.

Attacks, weapons, armor, formulas, critical hits, range, projectiles, cooldowns, mana, spells, conditions, healing, regeneration, death animation, corpses, loot, XP, respawn, combat AI, and target selection are explicitly absent.
