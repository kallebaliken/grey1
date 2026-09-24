# Defold runtime smoke test

## Launch

1. Open the repository's `game.project` in the current stable Defold editor.
2. Select **Project → Build** (or Build & Run).
3. Move with WASD/arrows and face an adjacent object before pressing E.

Controls: **E** uses the object ahead, **F1** toggles diagnostics, **F5** saves, **F9** loads, **F8** resets the development save, and holding **Page Up/Page Down** inspects an adjacent Z level without changing gameplay position.

Route: follow the dirt road left to the cottage, stand below its brown door and face north, press E, enter, approach the cyan stair from below and press E, explore the basement, then face south toward its stair and press E to return. Door, chest, and stairs are interaction-registry objects; the chest intentionally only toggles placeholder state.

## Checklist

- [ ] project builds and launches without errors
- [ ] movement works and F1 reports authoritative coordinates/facing
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

## Pure Lua tests

Run `lua tests/run.lua` from the repository root with Lua 5.1+ (LuaJIT is supported). `python3 tests/run_greyhaven.py` runs the suite when a Lua executable is installed and always checks Defold project wiring.
