# Defold 1.13.1 local playtest

This is a manual smoke test for the existing Greyhaven engine slice. It does not require or introduce NPC AI, combat, inventory UI, or equipment UI.

## Starting

1. Clone or update `kallebaliken/grey1` and check out the playtest branch.
2. Open `game.project` in Defold 1.13.1.
3. Select **Project → Build** (Build & Run).
4. Confirm the prototype world appears and the Defold console has no missing-module, missing-resource, or recurring script errors.
5. Press **F8** first if an older development save affects the expected starting state.

The startup chain is `game.project` → `/main/main.collection` → `/main/game_manager.script` → the statically registered `data.maps.prototype` module. Map modules must remain literal `require` dependencies in `world/map_loader.lua` so Defold includes them in the bundle.

## Controls

| Input | Current action |
| --- | --- |
| **WASD** or **arrow keys** | Move one cardinal tile; a blocked attempt still turns the Actor |
| **E** | Interact with the tile in front (door, chest, stair, or pickupable item) |
| **G** | Development control: drop the first inventory item on the current tile |
| **H** | Development control: calculate and execute the test NPC's path to `(14,7,7)` |
| **F1** | Toggle diagnostics |
| **F5** | Save |
| **F8** | Delete the development save and immediately rebuild the authored world |
| **F9** | Load the development save |
| **Page Up / Page Down** | While held, inspect the adjacent rendered Z level without moving the Actor |

F1 reports the player Actor ID/type, logical tile and Z, facing, render-command count, active dynamic GUI nodes, the configured 1024-node capacity, test-NPC path status/remaining steps/next target, objects on the current tile, interaction target, chunk, revealed roof group, inventory, equipment, and the latest notice. Equipment has no development control or GUI; initialization and persistence remain covered by automated tests.

The colored GUI boxes are temporary prototype/debug world presentation. Rendering is camera-culled with a two-tile margin and nodes are pooled. World nodes remain at safe GUI Z 0; their already-sorted node order preserves ground-to-roof stacking, while the HUD uses a separate layer above the world. Production rendering should later use Defold tilemaps, sprites, meshes/batching, or chunk rendering rather than one GUI node per visible sprite piece.

## Ordered playtest route

1. Press **F8**, then **F1**. Confirm player `player (player)` starts at `(9,2,7)`, facing west, with 15 herbs.
2. Walk with both WASD and arrows. Confirm the blue player interpolates between tiles while F1 reports the authoritative destination tile.
   Confirm the F1 render-command and active-node counts stay well below the displayed 1024-node capacity while the camera moves.
3. Try to cross a wall or table and confirm it blocks movement.
4. Walk to the brown-orange `npc_test_villager` at `(12,5,7)` and confirm its occupied tile blocks the player.
5. Return to `(9,2,7)`. Step west onto the herb tile and east back to face the gold key, then press **E**. Confirm the key disappears and appears in F1 inventory.
6. Step east onto the former key tile and west back to face the herb, then press **E**. Five herbs merge into the carried stack and five remain in the world because both inventory slots are occupied.
7. Move to a different tile and press **G**. Confirm the first inventory item disappears from inventory and appears at the player's logical tile with the same item ID.
8. Follow the vertical dirt road left to the cottage. Face the brown door and press **E**; confirm its appearance changes and it becomes walkable.
9. Enter the cottage. Confirm only the `house_01` roof hides; leave and confirm it returns. Also confirm the doorway reveal zone behaves the same way.
10. Face the cyan stair inside and press **E**. Confirm F1 changes from Z7 to Z6 and the basement renders. Use the basement return stair to verify Z7, then descend again.
11. Open the chest with **E** and confirm no exception occurs. It is intentionally only a state-toggle placeholder.
12. With the door open, an item transferred, and the player at Z6, press **F5**. Confirm the status says `Game saved`.
13. Restart Build & Run or change state and press **F9**. Confirm position, facing, Z, door/chest state, inventory/equipment ownership, the five-herb static remainder, and the dropped item position are restored. Confirm the original static key does not respawn.
14. Confirm the player still moves manually, then press **H**. The NPC should calculate a route and visibly walk tile by tile to `(14,7,7)`, including a turn. F1 should show `moving`, decreasing remaining steps, and the next target, followed by `completed`.
15. Reset and press **H** again, then place the player on the NPC's next reported tile. Confirm the NPC becomes `blocked`, never walks through the player, and does not replan or restart by itself. Confirm no Defold runtime errors occur.
16. Press **F8**. Confirm the authored key, 10-herb stack, 15-herb starter inventory, empty equipment, closed door/chest, original NPC position, and original player spawn return.

## Expected prototype content

The map contains Z7 outdoor ground and cottage, the Z8 cottage roof, a Z6 basement, blocking walls/furniture, a door, chest placeholder, paired stairs, the inert shared-Actor NPC, a healing-herb stack, and an iron key. Equipment test definitions exist but are not authored as extra map content in this playtest.

## Automated checks

From the repository root, run:

```sh
lua tests/run.lua
python3 tests/run_greyhaven.py
```

The Python check runs the full Lua suite when `lua`, `lua5.1`, or `luajit` is installed. It also validates the Defold entry resources and the literal prototype-map dependency. These checks do not replace the graphical smoke test above.
