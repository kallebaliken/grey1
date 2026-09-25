# Greyhaven migration plan

Greyhaven is an independent, Defold-native single-player RPG. The retained Canary tree is reference material during the incremental migration; existing notices and the repository license remain intact. New files are original implementations and do not mechanically translate Canary code or use proprietary game assets.

## Principles and boundaries

- Keep a launchable Defold project at repository root and land vertical slices rather than subsystem dumps.
- Treat the `(x, y, z)` grid as authoritative. Rendering and interpolation consume world state; they never define collision.
- Keep immutable map input separate from mutable, versioned world/save state.
- Represent one logical placement once even when it has several visual cells or occupies several gameplay cells.
- Use composition and small Lua modules. Defold game objects and GUI nodes are adapters at the boundary, not domain objects.
- Retire the C++ server only after the useful concept inventory and replacement coverage can be reviewed. It is not part of the Greyhaven runtime.

## Incremental phases

### 1 — Audit and runnable shell (complete)

Document Canary's transferable concepts and rejected server infrastructure. Add a standard Defold project, input, collection, event bus, runtime world state, and a small original map.

### 2 — World walking slice (complete)

Load Lua map data into `(x,y,z)` tiles; resolve object definitions; determine walkability in the logical world; interpolate player motion; build deterministic draw commands; and follow the player with a presentation camera.

### 3 — Stateful world-engine slice (complete)

Support independent visual/gameplay footprints, ordered stacks, grouped roofs, registered door/chest/stair interactions, playable Z transitions, chunk-addressed tiles, actor occupancy, debugging, and versioned local save/load. Fading and editor-authored schema tooling remain later work.

### 4 — Items and inventory (in progress)

Add immutable item definitions and per-instance state; reusable containers; inventory/equipment policies; world pickup/drop actions; events; and serialization tests. No GUI dependency belongs in these modules.

Completed slices: validated item definitions and instances, containers, inventory/world transfers, save-v2 item ownership, data-driven equipment with save-v3 exclusive ownership, and save-v4 player combat state. Nested containers, combat-derived equipment effects, and item use remain out of scope.

### 5 — Actors, navigation, and combat (in progress)

Compose player/NPC/monster actors from health, movement, inventory, faction, and condition data. Implement A* over `world.is_walkable`, then minimal data-driven damage, cooldown, armor, conditions, and death.

Completed slices: shared Actor identity/type/position/facing, canonical directions, registry/occupancy, generic movement/transitions/rendering, data-driven creature definitions/composition, authored directional faction relationships, explicit data-driven NPC dialogue, bounded deterministic A*, supplied-route execution, composed integer health/damage/death state, explicit cardinal melee attacks, main-hand weapon damage, and deterministic equipped-armor mitigation. Quests, merchants, dynamic reputation, conditions, autonomous AI, skills, and broader combat remain out of scope.

### 6 — Narrative and persistence

Add dialogue, quests, factions, witnesses and NPC knowledge provenance. Save player and mutable state by stable IDs with migrations, while referring to static map content by map/version rather than copying it.

### 7 — Canary retirement

Delete server sources, database/network deployment, and imported datapacks in reviewed batches once Greyhaven documentation and replacements cover every retained concept. Preserve required notices and document provenance in release packaging.

## Next acceptance slice

Add a minimal authored quest-state foundation independent of dialogue actions, rewards, merchants, schedules, reputation, and autonomous behavior.
