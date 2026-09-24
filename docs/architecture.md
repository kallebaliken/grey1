# Runtime architecture

See the root [architecture record](../GREYHAVEN_ARCHITECTURE.md) for invariants and [`phase2-runtime-audit.md`](phase2-runtime-audit.md) for the previous prototype assessment.

```text
map + definitions -> object registry -> chunked World <- WorldState
                                          |
                movement / pathfinding / interaction / transitions
                                          |
                                 render commands
                                          |
                          Defold manager -> GUI adapter
```

The world API (`get_chunk`, `get_tile`, `get_objects`, `get_actor_at`, `is_walkable`) and every simulation module are pure Lua. A* queries these APIs without flattening chunks or moving Actors. `game_manager.script` is a composition/lifecycle adapter: it does not decide collision, door rules, stair destinations, roof membership, path routes, or save schema. Interaction handlers are registered by kind, avoiding an object-type conditional in the manager.

The manager publishes an engine-neutral frame into adapter-local `main.view_model`, then posts a payload-free redraw message. This avoids Defold message payload limits and keeps render data out of authoritative state. Render command generation is bounded to the camera viewport plus a two-tile margin; graphical extents, rather than collision footprints, decide whether an object overlaps that viewport.

The current GUI box-node world presentation is a prototype/debug adapter. It reuses a small dynamic-node pool and the GUI scene temporarily allows 1024 total nodes for playtesting. Semantic stack values sort the engine-neutral command list but are never used as GUI Z coordinates: world nodes stay at GUI Z 0, their sorted node order determines overlap, and a separate GUI layer keeps HUD text above them. F1 reports command count, active dynamic nodes, and configured capacity. Production world rendering should replace one-node-per-piece GUI drawing with Defold-appropriate tilemaps, sprites, meshes/batching, or chunk rendering; GUI should primarily become HUD/UI.

Semantic events contain stable actor/object IDs and logical positions. Current events include `actor_added`, `actor_removed`, `actor_facing_changed`, `actor_moved`, `actor_interacted`, `actor_z_changed`, `actor_damaged`, `actor_died`, `door_opened`, `door_closed`, `object_state_changed`, `player_entered_interior`, and `player_left_interior`. Rendering does not subscribe to or occur inside event producers.
