# Defold runtime smoke test

## Launch

1. Open the repository's `game.project` in the current stable Defold editor.
2. Select **Project → Build** (or Build & Run).
3. Move with WASD/arrows and face an adjacent object or item before pressing E.

Controls: **E** uses or picks up the target ahead, **G** drops the first inventory item on the player's tile, **F1** toggles diagnostics, **F5** saves, **F9** loads, **F8** resets the development save, and holding **Page Up/Page Down** inspects an adjacent Z level without changing gameplay position. **G** is a temporary development control, not inventory UI.

Route: the green herb begins immediately west of the player and the gold key begins east. Face either item and press E to pick it up, then press G to drop the first held item. Follow the dirt road left to the cottage, stand below its brown door and face north, press E, enter, approach the cyan stair from below and press E, explore the basement, then face south toward its stair and press E to return. Door, chest, stairs, and pickup are registered interactions; the chest intentionally only toggles placeholder state.

## Checklist

- [ ] project builds and launches without errors
- [ ] movement works and F1 reports authoritative coordinates/facing
- [ ] the herb and key render on their logical tiles
- [ ] E removes the targeted item from the world and G restores it on the player's tile
- [ ] item pickup/drop does not affect door, chest, stair, or movement behavior
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
- [ ] F8 resets the save for a clean run

Inventory and world-item mutations are session-only in save version 1. Loading or restarting restores the two static test items and an empty inventory until the follow-up persistence slice lands.

## Pure Lua tests

Run `lua tests/run.lua` from the repository root with Lua 5.1+ (LuaJIT is supported). `python3 tests/run_greyhaven.py` runs the suite when a Lua executable is installed and always checks Defold project wiring.
