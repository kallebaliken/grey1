# Greyhaven architecture

Greyhaven is a Defold-native local simulation. The legacy Canary tree is reference-only and is not loaded by the game.

## Implemented layers

1. **Data** — `data/maps/prototype.lua` and `objects/object_defs.lua` declare immutable initial content.
2. **World model** — `world/` owns positions, chunk-addressed tiles, stable object instances, merged object state, Z visibility, and roof queries.
3. **Simulation** — `simulation/` validates movement, resolves explicit transitions, and dispatches interaction handlers.
4. **State** — `state/` owns runtime deltas, validated save snapshots, deterministic diagnostic serialization, and the Defold `sys.save` adapter.
5. **Rendering** — `render/` converts the model into engine-neutral, deterministically ordered draw commands.
6. **Defold adapter/UI** — `main/game_manager.script` routes lifecycle/input and `main/world.gui_script` draws placeholder nodes and debug text. Their adapter-local `view_model` passes frame tables without attempting to serialize nested data through Defold messages.
7. **Items** — `items/` validates immutable item-type definitions, creates independent runtime instances, provides fixed-slot generic containers, and associates an inventory/container with a stable owner ID. It has no Defold dependency and does not yet implement equipment or nested containers.

Dependencies point inward. Only the adapter calls `msg`, `sys`, or GUI APIs; world and simulation modules are ordinary Lua.

## Runtime invariants

- Authoritative actor positions are integer `tile_position` values. `visual_position` is interpolation only.
- A tile owns a sorted stack of logical entries plus one optional actor reservation.
- A logical object has a stable string ID, type, position, variant, immutable initial state, and metadata. Definitions own behavior-neutral traits and graphical patterns.
- Graphical footprint and collision footprint are independent. The test wall draws 2×2 while occupying 1×1.
- Runtime mutation is stored only under `world_state.objects[object_id]`; static placements are not edited.
- Current-Z objects and relevant roofs at Z+1 render. Interaction and collision occur only at the actor's actual Z.
- Roof hiding uses matching `interior_group`/`roof_group` world metadata plus object-authored reveal zones.
- Saves contain player position/facing, object deltas, flags, map identity, and schema version—never static geometry.
- Item definitions and item instances are distinct. Definitions are copied behind a registry boundary; instances own quantity and state, and non-stackable items always have quantity one.
- Containers hold copied item instances in deterministic slot order and expose copied snapshots. Existing stack IDs survive merges; overflow keeps the incoming ID and is returned rather than discarded when no slot is available.
- An inventory is an ownership wrapper around one generic container, not a second storage implementation. Ownership is represented by a stable ID rather than an actor reference, and all storage behavior delegates to the container.

## Scale boundary

Tiles are already addressed through 32×32 chunks, although the engine-test map keeps all chunks resident. Streaming, visible-chunk culling, and spatial roof-group indexes can be added behind existing queries without changing map or simulation APIs.
