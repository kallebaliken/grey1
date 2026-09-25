# Greyhaven architecture

Greyhaven is a Defold-native local simulation. The legacy Canary tree is reference-only and is not loaded by the game.

## Implemented layers

1. **Data** — `data/maps/prototype.lua` and `objects/object_defs.lua` declare immutable initial content.
2. **World model** — `world/` owns positions/directions, chunk-addressed tiles, stable object and world-item placements, the shared Actor registry/occupancy, Z visibility, and roof queries.
3. **Simulation** — `simulation/` owns actor interpolation runtime, deterministic bounded A*, generic movement validation, transitions, item transfers, and interaction dispatch.
4. **State** — `state/` owns runtime object deltas, inventory/equipment snapshots, static-item overrides, dynamic world-item snapshots, deterministic diagnostic serialization, and the Defold `sys.save` adapter.
5. **Rendering** — `render/` converts the model into engine-neutral, deterministically ordered, camera-culled draw commands. Culling uses graphical extents and a small viewport margin, never gameplay collision footprints.
6. **Defold adapter/UI** — `main/game_manager.script` routes lifecycle/input and `main/world.gui_script` draws placeholder nodes and debug text. Their adapter-local `view_model` passes frame tables without attempting to serialize nested data through Defold messages.
7. **Items** — `items/` validates immutable item-type definitions, creates runtime instances, provides generic containers/inventories, and transfers instances through data-driven equipment slots. It has no Defold dependency and does not implement nested containers or combat effects.
8. **Combat state** — `combat/` composes validated health/death records with known Actor IDs. Capability policies prevent dead Actors from beginning movement or interaction without placing combat logic on Actor.
9. **Explicit attacks** — `combat/attacks.lua` privately owns fixed-damage melee profiles and deterministic cooldown runtime, validates authoritative Actor positions, and delegates all health mutation to the combat registry.

Dependencies point inward. Only the adapter calls `msg`, `sys`, or GUI APIs; world and simulation modules are ordinary Lua.

## Runtime invariants

- Authoritative actor positions are integer `position` values; visual interpolation exists only in movement runtime.
- Actors share stable identity, canonical player/NPC/monster types, integer logical `position`, facing, and active state. Movement interpolation is separate weak runtime state rather than Actor data.
- A tile owns a sorted stack of logical entries plus one optional actor reservation.
- A logical object has a stable string ID, type, position, variant, immutable initial state, and metadata. Definitions own behavior-neutral traits and graphical patterns.
- Graphical footprint and collision footprint are independent. The test wall draws 2×2 while occupying 1×1.
- Runtime mutation is stored only under `world_state.objects[object_id]`; static placements are not edited.
- Current-Z objects and relevant roofs at Z+1 render. Interaction and collision occur only at the actor's actual Z.
- Roof hiding uses matching `interior_group`/`roof_group` world metadata plus object-authored reveal zones.
- Saves contain player position/facing, object deltas, flags, inventory ownership, static-item overrides, dynamic world items, map identity, and schema version—never unchanged static geometry.
- Item definitions and item instances are distinct. Definitions are copied behind a registry boundary; instances own quantity and state, and non-stackable items always have quantity one.
- Containers hold copied item instances in deterministic slot order and expose copied snapshots. Existing stack IDs survive merges; overflow keeps the incoming ID and is returned rather than discarded when no slot is available.
- An inventory is an ownership wrapper around one generic container, not a second storage implementation. Ownership is represented by a stable ID rather than an actor reference, and all storage behavior delegates to the container.
- Equipment is another exclusive owner of the same item-instance model. Canonical slot data and per-definition compatibility policy govern transfers; occupied slots reject replacement and full inventories reject unequip.
- World placements contain the same item instances used by inventories. Pickup/drop are explicit transfers: only accepted quantities change owner, item IDs survive, and tile placement does not require walkability.
- Save restoration constructs the authored world first, applies static item deltas, restores inventory and dynamic placements through public APIs, then restores player state. Validation rejects item IDs owned by more than one location.
- One Actor registry and one-per-tile reservation policy serve players, NPCs, and monsters; rendering consumes Actor state and never owns occupancy.
- A* derives starts from registered Actors and queries authoritative walkability with canonical cardinal directions. It is same-Z, uniformly costed, bounded, deterministic, and separate from movement or AI state.
- The pure-Lua movement controller owns supplied route progress by Actor ID outside Actor state. It advances only through shared movement after each interpolation completes; stale steps block without replanning, while cancellation/replacement preserve an already committed visual step.
- Combat registries privately own integer health state. Death is one-way in this foundation: health clamps to zero, the Actor remains registered and occupying its tile, and shared capabilities reject new movement and interaction.
- Attack profiles/cooldowns remain outside Actor and save state. Explicit attacks require living same-Z Actors one cardinal tile apart, emit deterministic lifecycle events, and never choose targets, move, or replan paths.
- Attack damage resolves from the exact `main_hand` equipment instance through public item APIs: validated weapon metadata replaces profile fallback damage, while empty/non-weapon hands remain unarmed. Derived damage is never persisted.
- Target mitigation sums validated armor metadata from public equipped-item snapshots and applies `max(1, raw - defense)` before the one CombatState mutation path. Armor sources and totals are derived, deterministic, and unsaved.
- Creature definitions are immutable registry data, separate from generic Actor instances. A pure composition service maps stable Actor IDs to definition IDs externally and delegates optional health/attack setup to existing services; definitions grant capabilities but never make decisions.
- Faction definitions, directional authored relationships, and Actor associations live outside Actor state. Queries default valid unconfigured pairs to neutral and never trigger targeting, movement, combat, dialogue, or other behavior.
- Dialogue definitions are immutable validated graphs; one external runtime session advances only through explicit adjacent Actor interaction and choice input. Dialogue conditions are read-only, while optional choice actions delegate only stable boolean flag writes to the generic world-action executor. Dialogue never mutates Actors, combat, inventory, or factions.
- WorldState owns persistent boolean flags; the generic recursive condition evaluator reads them without side effects. Dialogue hides choices whose validated conditions fail, and an explicitly selected choice may set flags only through a fully prevalidated authored action list.

## Scale boundary

Tiles are already addressed through 32×32 chunks, although the engine-test map keeps all chunks resident. Streaming, visible-chunk culling, and spatial roof-group indexes can be added behind existing queries without changing map or simulation APIs.

The current GUI box-node world adapter is temporary prototype presentation. It pools nodes and uses a 1024-node playtest capacity, but the long-term renderer should use tilemaps, sprites, meshes/batching, or chunked rendering and reserve GUI primarily for UI/HUD.
