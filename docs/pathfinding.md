# Pathfinding

## Architecture

Canary combines creature path requests with server creature state, tile queries, scheduling, and think loops. Greyhaven keeps only the reusable concepts—authoritative positions, walkability, Actor occupancy, and bounded route search—as `simulation/pathfinding.lua`. It is a synchronous pure-Lua A* query and never moves an Actor, schedules work, or emits movement events.

`find_path(world, actor_id, goal, options)` derives its start from the registered Actor and returns a structured result:

```lua
{ success = true, path = { ... }, cost = 6, visited = 9 }
-- or
{ success = false, reason = "no_path", visited = 12 }
```

The successful path excludes the start and includes the goal. Every cardinal step currently costs one. The heuristic is Manhattan distance, and neighbors are considered in canonical `north`, `east`, `south`, `west` order. The binary heap breaks equal `f` values by lower heuristic and then insertion sequence, making equal-cost results deterministic.

## World agreement

The pathfinder derives the Actor start from the world registry and calls `world:is_walkable` for every candidate. Doors use their current state, all Actor types block equally, world items inherit their definition's blocking behavior, logical collision footprints remain independent from graphical footprints, and chunk boundaries are invisible behind world queries. The requesting Actor is ignored only as the occupant of its own tile.

Occupied goals are rejected by default. `allow_occupied_goal = true` permits a route to be calculated to an otherwise traversable occupied goal, but does not make actual movement enter that occupied tile. Movement remains authoritative and must validate every consumed step.

## Deliberate limits

- Search stays on the Actor's current Z; a different-Z goal returns `different_z`. Stairs may become explicit graph edges later.
- `max_nodes` defaults to 2048 and returns `search_limit` when exhausted.
- Paths are snapshots. Door, object, or Actor changes can invalidate the next step; the movement controller stops when shared movement rejects it and does not replan automatically.
- No path or goal state is stored on Actor.
- This subsystem does not implement NPC/monster AI, chasing, patrols, schedules, combat targeting, multi-floor planning, asynchronous searches, or automatic recalculation.

## Route execution

Canary creature route execution combines route state with server scheduling, think loops, and network output. Greyhaven replaces only the reusable concept with `simulation/movement_controller.lua`: a pure-Lua controller keyed by stable Actor ID that consumes a supplied path through shared movement. It never chooses a goal or calculates a route.

`set_path` validates copied integer, cardinal, same-Z steps against the Actor's authoritative current position. Assignment replaces the previous remaining route. If a previous step is already visually interpolating, that committed step finishes before the replacement starts. Cancellation likewise discards the remaining route while allowing a committed tile step to finish visually. Each next step is revalidated by `movement.begin`; rejection marks the route `blocked`, emits one lifecycle event, and never triggers A* automatically. Controller state and statuses (`idle`, `moving`, `completed`, `blocked`, `cancelled`) remain outside Actor state.

The **H** development key explicitly calculates a route for `npc_test_villager` to `(14,7,7)`, assigns it, and visibly executes it tile by tile. This remains a developer action, not autonomous behavior.
