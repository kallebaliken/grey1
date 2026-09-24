# Defold runtime smoke test

## Launch

1. Open the repository's `game.project` in the current stable Defold editor.
2. Select **Project → Build** (or Build & Run).
3. Move with WASD/arrows and face an adjacent object or item before pressing E.

Controls: **E** uses or picks up the target ahead, **G** drops the first inventory item on the player's tile, **H** explicitly calculates a test-villager path to `(14,5,7)`, **F1** toggles diagnostics, **F5** saves, **F9** loads, **F8** resets the development save, and holding **Page Up/Page Down** inspects an adjacent Z level without changing gameplay position. **G** and **H** are temporary development controls.

Persistence route: start fresh with 15 carried herbs. Step west and back east to face the gold key, then press E to pick it up. Step east onto the key's former tile and back west to face the green 10-herb stack, then press E. Five herbs merge into the carried stack and five remain on the tile because both inventory slots are occupied. Press G on a different tile to drop the carried 20-herb stack while retaining the key. Follow the dirt road left to the cottage, open its brown door, enter, use the cyan stair, and save downstairs with F5. Restart or use F9. Door, chest, stairs, and pickup are registered interactions; the chest intentionally only toggles placeholder state.

The brown-orange test villager stands at `(12, 5, 7)`. It is an inert shared Actor used only to verify rendering and one-actor-per-tile collision.

## Checklist

- [ ] project builds and launches without errors
- [ ] movement works and F1 reports authoritative coordinates/facing
- [ ] the herb and key render on their logical tiles
- [ ] E removes the targeted item from the world and G restores it on the player's tile
- [ ] partial herb pickup leaves five herbs at the original static placement
- [ ] F1 shows stable item IDs and quantities in the inventory diagnostic
- [ ] F1 includes the equipment diagnostic (empty in the authored engine-test start)
- [ ] item pickup/drop does not affect door, chest, stair, or movement behavior
- [ ] the test villager renders at `(12,5,7)` and blocks the player from entering its tile
- [ ] H reports a deterministic two-step NPC path without moving the villager
- [ ] walls and table block the player
- [ ] closed door blocks the player
- [ ] E opens/closes the targeted door and its appearance changes
- [ ] open door becomes walkable
- [ ] entering the building hides only `house_01` roof
- [ ] doorway reveal works and leaving restores the roof
- [ ] stairs change the actor from Z7 to Z6
- [ ] basement renders and is walkable
- [ ] return stairs restore Z7
- [ ] F5 saves in the basement after opening the door
- [ ] restart or F9 restores basement position/facing and the open door
- [ ] reload retains `test.key.01` in inventory and does not respawn its static placement
- [ ] reload retains the five-herb static remainder and the dropped 20-herb stack at its chosen tile
- [ ] F8 resets the save for a clean run
- [ ] F8 immediately restores the authored key, 10-herb world stack, and 15-herb starter inventory

Equipment has no temporary gameplay key or GUI in this slice. Equip/unequip policy and save restoration are exercised by the pure-Lua suite; the F1 equipment line exists only to make restored state inspectable when later gameplay actions use it.

## Pure Lua tests

Run `lua tests/run.lua` from the repository root with Lua 5.1+ (LuaJIT is supported). `python3 tests/run_greyhaven.py` runs the suite when a Lua executable is installed and always checks Defold project wiring.
