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
| **J** | Development control: deal exactly 5 damage to `monster_test_rat` |
| **K** | Explicitly attack the Actor on the tile directly in front of the player |
| **L** | Development control: equip/unequip the first inventory weapon in `main_hand` |
| **O** | Development control: equip/unequip the first compatible inventory armor in `torso` |
| **P** | Explicitly invoke one test-rat attack against the player; the rat remains otherwise inert |
| **T** | Development control: toggle `greyhaven.test_dialogue_flag` while no dialogue is active |
| **1–4** | Select the corresponding choice while dialogue is active |
| **Escape** | Close the active dialogue session |
| **F1** | Toggle diagnostics |
| **F5** | Save |
| **F8** | Delete the development save and immediately rebuild the authored world |
| **F9** | Load the development save |
| **Page Up / Page Down** | While held, inspect the adjacent rendered Z level without moving the Actor |

F1 reports the player Actor ID/type, logical tile and Z, facing, resolved attack damage/source/main-hand weapon/current cooldown, total armor and sources, last raw/armor/final attack resolution, player and test-rat health/death, render-command count, active dynamic GUI nodes, path status, tile context, inventory, and equipment. There is no equipment or combat GUI; **L**, **O**, and **P** are development-only.

Diagnostics identify the player faction as `player`, `npc_test_villager` as definition `test_villager` / type `npc` / faction `townsfolk`, and `monster_test_rat` as definition `rat` / type `monster` / faction `vermin`. Villager-to-player is friendly and rat-to-player is hostile. These associations live outside the generic Actor.

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

## Health/death development check

1. Launch or reset with **F8**, enable **F1**, and confirm player HP is `100/100` and `monster_test_rat` is `20/20`, `dead: false`.
2. Confirm existing movement, rendering, interaction, and the explicit H route still work.
3. Press **J** once and confirm the rat becomes `15/20`; each press applies exactly five damage.
4. Press **J** until it reaches `0/20`, `dead: true`. The rat remains visible and occupies its tile.
5. Press **J** again. Confirm the status reports `actor_dead`, health remains zero, and no repeated death error occurs.
6. The test rat has no autonomous or debug path command. Automated tests verify that a dead Actor's supplied route blocks; no Actor chooses a new route.
7. Save/load after player damage when a future player-damage control exists; Save Format v4 already persists player health. Rat damage intentionally resets because static Actor combat persistence is deferred.
8. Press **F8** and confirm both authored health values are full with dead flags cleared. Confirm no Defold runtime errors occurred.

## Explicit attack check

1. Launch or reset, enable **F1**, and confirm the player shows fixed attack `5` with cooldown `0.00`.
2. Walk next to `monster_test_rat` at `(14,10,7)` and face it. The rat remains inert and never attacks or selects a target by itself.
3. Press **K**. Confirm the facing tile selects the rat and it loses exactly five health through the existing damage system.
4. Immediately press **K** again. Confirm `cooldown` is reported and no additional health is lost.
5. Keep moving if desired; cooldown does not lock movement. Wait until F1 reaches `0.00`, then attack again.
6. Repeat until the rat reaches zero. Confirm one lethal resolution, and that the dead rat remains rendered and occupying its tile.
7. Press **K** again after cooldown. Confirm `target_dead`, no health below zero, and no repeated death behavior.
8. Face away from the rat or stand too far away and press **K**. Confirm no nearest-target selection or pathfinding occurs.
9. Save/load and confirm player health persistence still works; attack cooldown intentionally restarts ready.
10. Exercise movement, H path execution, interactions, items, roofs, stairs, and save/reset as before. Confirm no Defold runtime errors.

## Equipped weapon check

1. Press **F8** for a fresh session. From spawn, move east onto the key tile so the sword at `(11,2,7)` is directly ahead, then press **E** to pick up `test.sword.01`. Avoid filling the second inventory slot first.
2. Walk next to the rat, face it, and press **K** while unarmed. Confirm exactly five damage and `Attack: 5 unarmed` in F1.
3. Wait for cooldown, then press **L**. Confirm `main_hand:test.sword.01` in equipment and F1 reports `Attack: 8 weapon` with `worn_iron_sword [test.sword.01]`.
4. Press **K** and confirm exactly eight—not thirteen—damage. Cooldown remains the authored 0.75 seconds.
5. After cooldown, press **L** to unequip. Confirm the exact same sword ID returns to inventory and F1 returns to five unarmed damage.
6. Press **L** again, then **F5** and **F9** (or restart). Confirm the sword remains equipped with the same ID and eight weapon damage still resolves from its definition.
7. Continue attacking only as health allows, or press **F8** between comparisons. Confirm the dead rat still occupies its tile and no Defold runtime errors occur.

## Equipped armor check

1. Press **F8**, enable **F1**, and confirm player armor is zero. Move east so `test.armor.01` at `(12,2,7)` is ahead and pick it up with **E**; avoid filling the second inventory slot first.
2. Walk next to the inert rat. Press **P** once while adjacent and confirm its explicit fixed attack deals the full raw two damage. The rat never attacks without **P**.
3. Wait for the rat's one-second cooldown, press **O**, and confirm `torso:patched_leather_armor [test.armor.01]` plus total Armor 2 in F1.
4. Press **P** again while adjacent. Confirm F1/notice reports `raw 2 - armor 2 = 1`, demonstrating the minimum-one rule.
5. Press **O** to unequip, wait for cooldown, and press **P** again. Confirm damage returns to two and the exact armor item ID is back in inventory.
6. Re-equip with **O**, save with **F5**, then load with **F9** or restart. Confirm torso equipment and Armor 2 are restored and the next explicit rat attack is still mitigated to one.
7. Confirm sword attacks still resolve weapon damage before target armor, cooldowns are unchanged, and all existing world systems remain operational without Defold errors.

## Creature definition check

1. Launch Greyhaven and enable **F1**. Confirm `npc_test_villager` reports definition `test_villager`, renders at `(12,5,7)`, and still blocks movement.
2. Confirm `monster_test_rat` reports definition `rat`, type `monster`, and 20/20 HP at its authored position.
3. Walk adjacent and use **K**; confirm the existing attack damages the rat. Use **J** to confirm direct damage/death behavior is unchanged.
4. Reset if needed, stand adjacent, and press **P**; confirm the definition-composed rat attack profile still deals its fixed damage.
5. Wait without pressing a development command. Confirm neither creature chooses movement or attacks autonomously and no Defold runtime errors occur.

## Faction relationship check

1. Launch Greyhaven and enable **F1**. Confirm the player faction is `player`.
2. Inspect `npc_test_villager`; confirm faction `townsfolk` and relationship to player `friendly`.
3. Inspect `monster_test_rat`; confirm faction `vermin` and relationship to player `hostile`.
4. Wait and move around. Confirm the rat and villager remain inert: faction queries cause no attacks, chasing, dialogue, or movement.
5. Use **K**, **J**, and **P** as before. Confirm explicit combat remains possible because faction data does not impose friendly-fire or targeting policy.
6. Save/load or reset and confirm the same authored associations reconstruct without a save migration or runtime errors.

## Explicit dialogue check

1. Launch or reset Greyhaven, walk next to `npc_test_villager`, face the villager, and press **E**.
2. Confirm the HUD dialogue panel shows `Test Villager`, “Morning, traveler.”, and numbered choices.
3. Hold movement keys and press **K**, **E**, or development controls. Confirm player movement and unrelated actions are ignored while dialogue is active.
4. Press **1** for “What is this place?” and confirm the panel advances to “Greyhaven. Quiet enough, most days.”
5. Press **1** to return to the greeting, or **2** to say goodbye and close. Also verify **Escape** closes explicitly.
6. Confirm movement and existing explicit combat controls resume after closing.
7. Face `monster_test_rat` and press **E**. Confirm it reports no dialogue and opens no panel.
8. Save or load while no dialogue is active; confirm sessions never persist and the next game begins with no conversation.
9. Confirm the villager never initiates dialogue and no quests, items, health, factions, or world state change through choices.

## Persistent condition check

1. Press **F8**, enable **F1**, and confirm `greyhaven.test_dialogue_flag` is false.
2. Talk to `npc_test_villager`; confirm “What is going on with the rats?” is absent, then close the dialogue.
3. Press **T** and confirm the flag becomes true in F1.
4. Talk to the villager again; confirm the rat question is now visible. Select it and verify the normal `rat_problem` text transition.
5. Close dialogue and press **F5**, then restart/load or press **F9**. Confirm the flag remains true and the gated choice remains available.
6. Press **F8** and confirm the flag returns to false and the gated choice disappears again.
7. Confirm evaluating or selecting choices does not change the flag, health, inventory, faction, Actor position, or any other world state, and no Defold errors occur.

## Expected prototype content

The map contains Z7 outdoor ground and cottage, the Z8 cottage roof, a Z6 basement, blocking walls/furniture, a door, chest placeholder, paired stairs, the inert shared-Actor NPC, the inert test rat, a healing-herb stack, an iron key, and original sword/armor test placements.

## Automated checks

From the repository root, run:

```sh
lua tests/run.lua
python3 tests/run_greyhaven.py
```

The Python check runs the full Lua suite when `lua`, `lua5.1`, or `luajit` is installed. It also validates the Defold entry resources and the literal prototype-map dependency. These checks do not replace the graphical smoke test above.
