# Actor foundation

## Decision

Canary's `Creature`, `Player`, `Npc`, and `Monster` hierarchy combines identity, map placement, scheduling, combat, protocol output, and specialized behavior. Greyhaven preserves only the shared gameplay foundation as a small pure-Lua Actor:

| Canary concept | Greyhaven equivalent | Important difference |
| --- | --- | --- |
| `Creature` identity and position | `actors/actor.lua` | Stable string ID, canonical actor type, integer logical position, facing, and active state only. |
| Player/NPC/Monster subclasses | `actors/actor_types.lua` | Canonical metadata values without inheritance or type-specific behavior. |
| Creature lookup/placement | `actors/registry.lua` plus `world/world.lua` occupancy | One registry and one actor reservation per tile for every actor type. |
| Direction/facing helpers | `world/direction.lua` | One world-coordinate definition shared by movement and interaction. |

The player is an Actor explicitly composed at the runtime root with inventory, equipment, CombatState, attack profile, and an external `player` faction association. NPCs and monsters use the same Actor representation but are authored through immutable creature definitions. `creatures/creatures.lua` retains Actor-to-definition associations outside Actor state and composes only optional definition-declared services, including external faction association. Dialogue definition/session state is also external. Pathfinding remains separate, and schedules, autonomous AI, stats, and decision-making remain absent.

## Logical state and presentation runtime

Actor state is authoritative and contains `id`, `type`, integer `position`, `facing`, and `active`. `simulation/movement.lua` separately owns weakly keyed interpolation state: visual position, current movement target, progress, and presentation speed. Rendering reads that movement runtime but never writes logical position. Defold nodes remain disposable presentation output.

Movement accepts any registered Actor. An attempted cardinal move updates facing before collision validation, matching the existing player behavior; it emits `actor_facing_changed` even when blocked. A successful move reserves the destination immediately, updates authoritative position, and emits `actor_moved`. Stairs use the same generic actor teleport path and emit `actor_z_changed`.

Supplied routes are executed by the separate pure-Lua movement controller. Its state is keyed by Actor ID rather than stored on the Actor. It waits for each visual interpolation to finish before asking shared movement to validate and commit the next cardinal same-Z step. Replacement and cancellation discard only remaining steps; an already committed step finishes visually. Stale routes become blocked without automatic replanning.

## Occupancy and lifecycle

The world owns an Actor registry and tile reservations. `place_actor`, `get_actor`, `get_actor_at`, `get_actors`, `move_actor`, and `remove_actor` apply equally to players, NPCs, and monsters. At most one actor occupies a tile, and every actor type blocks movement identically. Registry collections remain private; deterministic queries expose actors without exposing the backing ID table.
