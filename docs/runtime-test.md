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
| **V** | Inspect the current read-only `monster_test_rat` awareness snapshot |
| **T** | Development control: toggle `greyhaven.test_dialogue_flag` while no dialogue is active |
| **Y** | Development control: explicitly start `rat_problem` |
| **U** | Development control: advance its `investigate` objective by one |
| **I** | Development control: explicitly complete it after all objectives are complete |
| **1–4** | Select the corresponding choice while dialogue is active |
| **Escape** | Close the active dialogue session |
| **F1** | Toggle diagnostics |
| **F5** | Save |
| **F8** | Delete the development save and immediately rebuild the authored world |
| **F9** | Load the development save |
| **Page Up / Page Down** | While held, inspect the adjacent rendered Z level without moving the Actor |

F1 reports the player Actor ID/type, logical tile and Z, facing, resolved attack damage/source/main-hand weapon/current cooldown, total armor and sources, last raw/armor/final attack resolution, player and test-rat health/death, the test quest status/progress, render-piece category counts, active sprite instances, per-frame creation/reuse/removal/failure counts, configured capacity, path status, tile context, inventory, and equipment. There is no equipment, quest, or combat GUI; **L**, **O**, **P**, **Y**, **U**, and **I** are development-only.

Diagnostics identify the player faction as `player`, `npc_test_villager` as definition `test_villager` / type `npc` / faction `townsfolk`, and `monster_test_rat` as definition `rat` / type `monster` / faction `vermin`. Villager-to-player is friendly and rat-to-player is hostile. These associations live outside the generic Actor.

Once the locally created PNGs listed in `assets/world/ASSET_MANIFEST.md` are present, the world uses `assets/world.atlas` on factory-created sprite Game Objects. Visible pieces are reused by stable render-command ID and remain camera-culled with a two-tile margin. HUD, F1 text, and dialogue stay in GUI. Production batching remains a future optimization.

## Ordered playtest route

1. Press **F8**, then **F1**. Confirm player `player (player)` starts at `(9,2,7)`, facing west, with 15 herbs.
2. Walk with both WASD and arrows. Confirm the blue player interpolates between tiles while F1 reports the authoritative destination tile.
   Confirm F1 render-command and sprite-piece counts remain stable while the camera moves, with no GUI-node overflow.
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
7. Save/load after player damage when a future player-damage control exists; Save Format v5 already persists player health. Rat damage intentionally resets because static Actor combat persistence is deferred.
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
5. Press **1** to return to the greeting, **2** for the newly conditioned follow-up, or **3** to say goodbye and close. Also verify **Escape** closes explicitly.
6. Confirm movement and existing explicit combat controls resume after closing.
7. Face `monster_test_rat` and press **E**. Confirm it reports no dialogue and opens no panel.
8. Save or load while no dialogue is active; confirm sessions never persist and the next game begins with no conversation.
9. Confirm the villager never initiates dialogue and choices change no quests, items, health, factions, movement, or world state other than their explicitly authored boolean flag action.

## Persistent condition check

1. Press **F8**, enable **F1**, and confirm `greyhaven.test_dialogue_flag` is false.
2. Talk to `npc_test_villager`; confirm “What is going on with the rats?” is absent, then close the dialogue.
3. Press **T** and confirm the flag becomes true in F1.
4. Talk to the villager again; confirm the rat question is now visible. Select it and verify the normal `rat_problem` text transition.
5. Close dialogue and press **F5**, then restart/load or press **F9**. Confirm the flag remains true and the gated choice remains available.
6. Press **F8** and confirm the flag returns to false and the gated choice disappears again.
7. Confirm evaluating conditions and selecting the rat-information choice do not change that test flag, health, inventory, faction, Actor position, or any other world state, and no Defold errors occur.

## Dialogue flag action check

1. Press **F8**, enable **F1**, and confirm `greyhaven.met_test_villager` is false.
2. Face `npc_test_villager`, press **E**, and select “What is this place?” without using **T**.
3. Confirm F1 now shows `greyhaven.met_test_villager` as true.
4. Confirm the conditioned “I am glad we spoke.” response is available on the resulting node.
5. Close dialogue, press **F5**, restart/load or press **F9**, and confirm the flag remains true.
6. Reopen dialogue and confirm conditioned content reflects the restored flag.
7. Press **F8** and confirm the flag returns to false and the conditioned response is absent until the authored action runs again.
8. Confirm no Defold runtime errors and no items, quests, health, movement, factions, or AI were changed.

## Minimal quest-state check

1. Press **F8**, enable **F1**, and confirm `A Small Rat Problem` is `not_started` with `investigate` shown as `0/1`.
2. Press **U** or **I** first and confirm the rejected update leaves the quest unchanged.
3. Press **Y** and confirm status becomes `active` and one `quest_started` transition is reported.
4. Press **Y** again and confirm the active quest is not reset.
5. Press **I** and confirm completion is rejected while the objective is incomplete.
6. Press **U** and confirm `investigate` becomes `1/1`; press **U** again and confirm it stays clamped with no repeated completion.
7. Press **I** and confirm status becomes `completed`; press **I** again and confirm no repeated completion.
8. Press **F5**, restart/load or press **F9**, and confirm completed status and `1/1` progress survive.
9. Press **F8** and confirm the quest returns to `not_started` and `0/1`.
10. Confirm no rewards, items, XP, money, flags, dialogue, Actors, factions, combat, or world objects changed and no Defold runtime errors occurred.

## Read-only quest-condition check

1. Press **F8**, face `npc_test_villager`, press **E**, and confirm “About that rat problem...” and the completed-quest response are hidden.
2. Close dialogue, press **Y**, then talk to the villager again and confirm “About that rat problem...” appears.
3. Select it, confirm “That should be enough.” is hidden while the objective is incomplete, then close with **Escape**.
4. Press **U**, reopen the active-quest branch, confirm the report is hidden and “That should be enough.” appears, then close with **Escape**.
5. Press **I** and talk again. Confirm the active branch is hidden and “The rat trouble is settled.” appears.
6. Repeatedly open, inspect, and close the conversation. Confirm status and progress never change and no quest lifecycle events repeat.
7. Press **F5**, restart/load or press **F9**, and confirm the completed branch remains available.
8. Press **F8** and confirm dialogue returns immediately to the `not_started` choices.
9. Confirm merely viewing and closing conditioned dialogue never starts, advances, or completes the quest and no Defold runtime errors occur.

## Event-driven quest-action check

1. Press **F8**, enable **F1**, and confirm `rat_problem` is `not_started` at `0/1`.
2. Talk to `npc_test_villager`, select “Do you need a hand?”, then choose “I can help.”
3. Confirm F1 reports `active` at `0/1` without using **Y**.
4. Walk to `monster_test_rat`, face it, and kill it using normal **K** attacks.
5. Confirm normal CombatState death occurs, F1 reports `active` at `1/1`, and `Last binding: rat_problem.rat_died = success`; the quest has not auto-completed.
6. Return to the villager, enter the active branch, select “That should be enough.”, and confirm F1 reports `completed` at `1/1` without using **U** or **I**.
7. Reopen dialogue and confirm “The rat trouble is settled.” is available while the offer and active branch are hidden.
8. Press **F5**, restart/load or press **F9**, and confirm completed state and dialogue availability persist.
9. Press **F8** and confirm the quest returns to `not_started`, `0/1`, with the offer visible again.
10. Reset again and kill the rat before accepting the quest. Confirm the rat remains dead, the quest remains `not_started`, and the last binding reports failure cleanly.
11. Confirm no loot, XP, money, items, factions, reputation, markers, respawning, or other rewards occur and no Defold runtime errors occur.

## Creature perception check

1. Press **F8**, enable **F1**, and confirm rat sight is 6 while `monster_test_rat` remains inert.
2. Stand more than six Manhattan tiles from the rat and press **V**. Confirm the player is absent.
3. Move within six tiles on Z7 and press **V**. Confirm the player appears with distance and hostile relationship.
4. Walk around the rat while staying in range; confirm its facing does not affect the result.
5. Move to the cottage basement on Z6 and confirm the Z7 rat no longer perceives the player; return to Z7 and query again.
6. Confirm the rat never moves, attacks, starts a path, selects a target, or remembers a previously visible Actor.
7. The compact prototype layout does not provide a practical rat/door alignment. The pure-Lua suite therefore verifies wall blocking, closed-door blocking, immediate visibility after opening, diagonal corner policy, endpoint handling, and logical-versus-graphical footprints in focused maps.
8. Exercise the normal quest, dialogue, combat, door, roof, stair, and save/load controls and confirm no Defold runtime errors.

## Atlas-backed world renderer check

1. Launch Greyhaven and confirm the world is rendered with atlas sprites rather than flat GUI boxes.
2. Confirm textured grass, dirt, cottage wood floor, and basement floor are visibly distinct.
3. Confirm walls, table, chest, stairs, and roof use world sprites.
4. Face the closed cottage door and confirm `door_closed_01` is visible; press **E** and confirm it changes to the open-door image without changing interaction or collision behavior.
5. Confirm the player, villager, and rat use distinct static sprites, and player/NPC movement retains smooth interpolation.
6. Enter and leave the cottage and confirm roof reveal behavior is unchanged.
7. Use the stairs and confirm only the expected logical Z level is presented.
8. Confirm herbs, key, sword, and leather armor appear as sprites and remain pickupable/equippable with stable IDs.
9. Confirm status, F1 diagnostics, and dialogue remain GUI content above the sprite world.
10. Exercise quest progression, explicit combat, perception, save/load, and reset; confirm their behavior is unchanged.
11. Confirm there are no missing-atlas, missing-factory, invalid-animation, black-world, GUI-overflow, or recurring Defold errors.
12. Stand still for several frames and confirm F1 reports zero new creations, stable active instances, and reuse equal to the visible piece count.
13. Perform a clean rebuild (project settings are not applied by hot reload), then move between exterior, cottage, roof-visible, and basement viewports. Confirm stale pieces are removed, world sprites remain below the runtime-reported Sprite max of 2048 and collection max of 4096, and spawn failures remain zero. A one-frame nonzero `deferred` count is allowed during a capacity-bound viewport replacement; it must recover on the following frame.
14. Confirm the console contains no `Gameobject buffer is full`, `/game#sprite`, or `play_animation` dispatch errors.

## Pixel-perfect camera zoom check

1. Clean-build and launch with `greyhaven.camera_zoom = 2` in `game.project`.
2. Confirm each 32×32 source tile occupies 64×64 displayed pixels and remains crisp rather than linearly blurred.
3. Confirm the player stays centered and crosses 64 screen pixels per logical tile with unchanged movement duration and smooth interpolation.
4. Confirm ground, items, doors, walls, roofs, and multi-piece 32-pixel offsets remain aligned.
5. Enable F1 and confirm `Camera zoom: 2x` and approximately `15x10` visible logical tiles.
6. Confirm HUD, F1 text, and dialogue retain their original screen-space size.
7. Confirm no new allocation, atlas, sprite, or runtime errors appear.

## Boxed Greyhaven RPG client check

1. Clean-build and launch at the initial 1280×800 window size; confirm the client reads as a framed world, permanent sidebar, and permanent bottom panel.
2. Confirm the world is clipped to `(0, 160, 960, 640)`, shows exactly 15×10 logical tiles at 2x zoom, and centres the player around `(480, 480)`.
3. Confirm the sidebar occupies `(960, 0, 320, 800)` with labeled map, status, equipment, inventory, and utility placeholders.
4. Confirm the bottom panel occupies `(0, 0, 960, 160)`, shows the placeholder tab header and current runtime notice, and shows control help only while F1 is enabled.
5. Confirm world sprites and large roof/wall pieces never spill into either GUI region, and transparent pixels reveal ground rather than black Sprite-quad rectangles or bands.
6. Move in all directions; use doors and stairs; reveal roofs; pick up/drop items; attack; talk; complete the quest; and save/load. Confirm all behavior is unchanged.
7. Confirm dialogue remains usable in the lower world viewport and F1 remains a constrained developer overlay without changing world dimensions.
8. Resize through 1920×1200, 2560×1600, 1920×1080, 4:3, tall, and ultrawide windows. Confirm the same 15×10 world remains visible, the complete client scales uniformly, and unused space becomes letterbox/pillarbox.
9. Resize below 1280×800 and confirm the complete client scales down rather than cropping; nearest filtering remains enabled, with the expected pixel tradeoff at non-integer scale.
10. Confirm F1 reports a stable fixed-viewport render count (259 pieces at the authored exterior start before state changes), reuse while standing still, and no Sprite/Game Object capacity failures.
11. Confirm there are no render-script, projection, GUI, Sprite, Game Object, or Defold runtime errors, including the previously fixed constant/state/scissor failures.

## Expected prototype content

The map contains Z7 outdoor ground and cottage, the Z8 cottage roof, a Z6 basement, blocking walls/furniture, a door, chest placeholder, paired stairs, the inert shared-Actor NPC, the inert test rat, a healing-herb stack, an iron key, and original sword/armor test placements.

## Automated checks

From the repository root, run:

```sh
lua tests/run.lua
python3 tests/run_greyhaven.py
```

The Python check runs the full Lua suite when `lua`, `lua5.1`, or `luajit` is installed. It also validates the Defold entry resources and the literal prototype-map dependency. These checks do not replace the graphical smoke test above.

## Functional equipment panel check

1. Launch Greyhaven and confirm all eight recessed Equipment slots appear in the right sidebar: head, torso, legs, feet, neck, ring, main hand, and off hand.
2. Confirm empty slots show their compact neutral letter and no item icon.
3. Pick up the worn iron sword, press **L**, and confirm its existing atlas icon immediately appears in main hand while attack damage changes through the existing combat resolver.
4. Pick up patched leather armor, press **O**, and confirm its icon immediately appears in torso while existing armor mitigation remains effective.
5. Press **L** to unequip and confirm main hand immediately returns to its empty marker; press **L** again to restore the exact sword instance.
6. Enable F1 and confirm Equipment UI reports eight slots, occupied count, item types, and exact stable instance IDs.
7. Save, restart/load, and confirm sword and armor icons reconstruct from restored Equipment state without saved GUI state.
8. Reset and confirm every slot immediately reflects the authored empty equipment state with no stale icon.
9. Resize the physical window and confirm 24×24 virtual-pixel icons remain inside Equipment while the complete client scales uniformly.
10. Confirm world sprites never enter the sidebar, the Inventory panel remains contained, Map remains a placeholder, and dialogue/quests/combat remain functional.
11. Confirm there are no GUI-node, atlas-animation, render, Sprite, or Game Object errors.

The panel is read-only in this milestone; slot-click unequip is deferred until Greyhaven has a stable mouse/UI dispatch path.

## Functional inventory panel check

1. Launch Greyhaven and confirm the real 4×4 Inventory grid appears beneath Equipment with clean empty slots and the real occupied/capacity count.
2. Confirm authored starter items appear in deterministic container order; herb stacks show their exact quantity, while keys and other quantity-one items show no count.
3. Pick up another herb and confirm the surviving stack updates immediately instead of creating a fake duplicate slot.
4. Pick up the iron key and worn iron sword and confirm their existing atlas icons appear without quantity-one labels.
5. Press **L** to equip the sword; confirm the exact instance leaves Inventory and appears in Equipment main hand. Press **L** again and confirm it returns to Inventory.
6. Press **G** to drop an item and confirm the Inventory presentation updates from gameplay state.
7. Enable F1 and verify Inventory UI reports occupied/capacity plus exact item IDs and quantities. Inventories above 16 entries must report `+N more`.
8. Save, restart/load, and confirm exact identities, order, and quantities reconstruct without saved GUI state; reset and confirm the authored starter inventory returns without stale icons/counts.
9. Resize the physical window and confirm the fixed grid remains within the sidebar without overlapping Equipment, world, or bottom panel.
10. Confirm combat, dialogue, quests, world clipping, and equipment remain functional, with no GUI-node, atlas, or runtime errors.

The Inventory panel is read-only; drag/drop, item use, slot reordering, nested containers, and mouse inventory interaction remain deferred.
