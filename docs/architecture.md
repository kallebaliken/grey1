# Runtime architecture

See the root [architecture record](../GREYHAVEN_ARCHITECTURE.md) for invariants and [`phase2-runtime-audit.md`](phase2-runtime-audit.md) for the previous prototype assessment.

```text
map + object/creature definitions -> registries -> chunked World <- WorldState
                                          |
                movement / pathfinding / interaction / transitions
                                          |
                                 render commands
                                          |
                          Defold manager -> GUI adapter
```

The world API (`get_chunk`, `get_tile`, `get_objects`, `get_actor_at`, `is_walkable`) and every simulation module are pure Lua. A* queries these APIs without flattening chunks or moving Actors. `game_manager.script` is a composition/lifecycle adapter: it does not decide collision, door rules, stair destinations, roof membership, path routes, or save schema. Interaction handlers are registered by kind, avoiding an object-type conditional in the manager.

Creature composition is also pure Lua: an immutable definition registry supplies Actor type and optional combat, attack, and prototype render policy; the creature service creates the generic Actor and delegates to existing runtime services. The player remains explicitly composed, and definitions never become mutable Actor state or autonomous behavior.

Faction composition is query-only pure Lua. A validated registry owns faction definitions and directional relationship edges; a separate runtime maps Actor IDs to faction IDs. Missing authored edges between valid factions resolve neutral, unaffiliated Actors resolve neutral in Actor-to-Actor queries, and no result is consumed automatically by movement, combat, interaction, dialogue, or rendering.

Dialogue is explicit and pure Lua: validated immutable graphs describe text and next/close choices, while a separate single-session runtime tracks speaker and node. The interaction registry begins a session only for the adjacent facing Actor. The Defold adapter presents the session and locks player controls; definitions and choices have no gameplay side effects.

Persistent boolean flags extend the existing WorldState rather than creating another store. The generic condition evaluator validates and recursively evaluates flag, all, any, and not forms without mutation. Dialogue filters current choices through this evaluator; future consumers must depend on the same query boundary rather than embedding their own flag logic.

Validated world actions form the corresponding mutation boundary. The sole current action sets a stable boolean WorldState flag. Dialogue validates action lists during content registration and invokes the generic executor only for an explicit selected choice; conditions remain read-only, and actions contain no callbacks, item/quest effects, combat, movement, or AI.

Quest definitions and mutable QuestState are separate pure-Lua boundaries. The registry owns copied authored metadata; the runtime owns only canonical status and bounded integer objective counters, changes them solely through explicit APIs, and emits deterministic lifecycle events. Quests cause no rewards or other gameplay mutations and dialogue does not start or progress them.

The single Condition evaluator also supports validated `quest_status` and `quest_objective` queries. It receives QuestDefinition registry and QuestState dependencies explicitly, delegates runtime semantics to public QuestState APIs, and remains read-only. Dialogue filters choices through that generic interface without learning quest rules.

The manager publishes an engine-neutral frame into adapter-local `main.view_model`, then posts a payload-free redraw message. This avoids Defold message payload limits and keeps render data out of authoritative state. Render command generation is bounded to the camera viewport plus a two-tile margin; graphical extents, rather than collision footprints, decide whether an object overlaps that viewport.

The current GUI box-node world presentation is a prototype/debug adapter. It reuses a small dynamic-node pool and the GUI scene temporarily allows 1024 total nodes for playtesting. Semantic stack values sort the engine-neutral command list but are never used as GUI Z coordinates: world nodes stay at GUI Z 0, their sorted node order determines overlap, and a separate GUI layer keeps HUD text above them. F1 reports command count, active dynamic nodes, and configured capacity. Production world rendering should replace one-node-per-piece GUI drawing with Defold-appropriate tilemaps, sprites, meshes/batching, or chunk rendering; GUI should primarily become HUD/UI.

Semantic events contain stable actor/object/quest IDs and logical values. Current events include `actor_added`, `actor_removed`, `actor_facing_changed`, `actor_moved`, `actor_interacted`, `actor_z_changed`, `actor_attacked`, `actor_damaged`, `actor_died`, `dialogue_started`, `dialogue_choice_selected`, `dialogue_node_changed`, `dialogue_closed`, `quest_started`, `quest_objective_progressed`, `quest_objective_completed`, `quest_completed`, `door_opened`, `door_closed`, `object_state_changed`, `player_entered_interior`, and `player_left_interior`. Rendering does not subscribe to or occur inside event producers.
