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

The manager publishes an engine-neutral frame into adapter-local `main.view_model`, then posts a payload-free redraw message. This avoids Defold message payload limits and keeps render data out of authoritative state.

Semantic events contain stable actor/object IDs and logical positions. Current events include `actor_added`, `actor_removed`, `actor_facing_changed`, `actor_moved`, `actor_interacted`, `actor_z_changed`, `door_opened`, `door_closed`, `object_state_changed`, `player_entered_interior`, and `player_left_interior`. Rendering does not subscribe to or occur inside event producers.
