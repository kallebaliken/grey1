# Phase 2 runtime audit

## What the prototype already did well

Commit `a697af2` established a Defold entry point, kept grid walkability outside Defold physics, separated definitions from map placements, interpolated visual movement, generated deterministic draw commands, and stored mutable values outside static map data. Those choices remain.

## Weaknesses found

- Placements doubled as object instances and used numeric IDs; mutable identity and initial/runtime state were ambiguous.
- Tiles split `ground` from `objects` and did not expose removal or a complete deterministic stack.
- The world was one flat key table rather than chunk-addressed storage.
- Player movement lived in the player type and represented position as parallel scalar fields.
- Roof reveal used rectangles attached directly to every roof and had no reusable building identity.
- Z support was presentation-only. There were no transitions or playable lower floors.
- The Defold manager knew too much domain behavior, while save, interaction, actor occupancy, and registered actions did not exist.
- Structural Python checks searched source strings rather than exercising Lua behavior.

## Hardening performed

The runtime now has stable object instances, merged initial/runtime state, chunk-owned tiles, complete tile stacks, actor occupancy, registered interactions, explicit transitions, group-based roofs, pure movement/save transforms, and a Defold-only persistence adapter. A deterministic engine-test map exercises a door, chest placeholder, roof, basement, and return stair. `tests/run.lua` exercises the domain without Defold.

## Temporary code retained intentionally

The GUI uses colored box nodes and rebuilds visible nodes after state changes. The tiny map is a Lua module, all loaded chunks remain resident, roof groups are discovered by scanning the small object set, and interaction is cardinal-only. These are acceptable test adapters, not scaling claims.

## Canary concepts still relevant

Canary's position values, tile stacks, thing/type separation, creature occupancy, destination validation, path-query boundary, and teleport/floor-change concepts remain useful. Greyhaven expresses them as small Lua data modules rather than `Cylinder`, inheritance, spectators, dispatcher tasks, protocol stack positions, or network notifications.
