# Greyhaven

Greyhaven is the beginning of an original single-player 2D RPG built with [Defold](https://defold.com/). It uses a 32×32 logical grid, explicit Z-levels, stacked world objects, smooth presentation, and data-authored maps. The engine-test slice includes a stateful cottage door, grouped roof reveal, explicit basement stairs, and versioned local save/load.

This repository began as a fork of the GPL-2.0 Canary MMORPG server. Canary's source remains temporarily as architectural reference while systems are replaced incrementally; it is **not** used by the Greyhaven runtime. Existing licenses and notices remain in place. New Greyhaven Lua and documentation are independently authored, and all current visuals are simple original color placeholders.

## Run in Defold

1. Install the current stable Defold editor.
2. Choose **Open From Disk** and select this repository's `game.project`.
3. Build and run the project (`Project` → `Build`).
4. Move with WASD/arrows, use the faced object with E, toggle diagnostics with F1, save with F5, and load with F9. Follow the detailed [runtime checklist](docs/runtime-test.md).

The project has no external library or asset dependencies. Its initial collection is `main/main.collection`.

## Current foundation

- Lua map format with stable placement IDs and `(x, y, z)` coordinates.
- Chunk-addressed tiles with sorted object stacks, actor reservations, gameplay footprints, and authoritative walkability.
- Stable object instances separate from registry definitions, including a 2×2 visual object with a distinct 1×1 gameplay footprint.
- Deterministic semantic render layers and a player-following presentation camera.
- Smooth visual player interpolation after grid movement validation.
- Grouped roof rendering from `z + 1`, interior/reveal-zone detection, and actual playable Z transitions.
- Registered interactions for stateful doors, explicit stairs, and a chest placeholder.
- Synchronous semantic events, object-ID world-state deltas, and validated Defold local saves.

This is deliberately a narrow world-engine slice. Inventory, NPCs, monsters, combat, pathfinding, dialogue, and quests remain planned rather than represented by misleading stubs.

## Documentation

- [Migration plan](MIGRATION_PLAN.md)
- [Canary system audit](CANARY_SYSTEM_MAP.md)
- [Architecture decision record](GREYHAVEN_ARCHITECTURE.md)
- [Runtime architecture](docs/architecture.md)
- [World format](docs/world-format.md)
- [Object format](docs/object-format.md)
- [Save format direction](docs/save-format.md)
- [Runtime test checklist](docs/runtime-test.md)
- [Phase 2 runtime audit](docs/phase2-runtime-audit.md)

## Repository status

The legacy C++ server, datapacks, database files, and deployment tooling are quarantined by non-use rather than deleted in this first milestone. They will be removed in coherent, reviewable phases after their useful concepts are documented and Greyhaven replacements exist. Do not add new gameplay to the legacy server.

## License and content

See [`LICENSE`](LICENSE). Do not add Tibia/CipSoft graphics, maps, audio, writing, or other proprietary content. Greyhaven requires original or appropriately licensed assets and content.
