# Required local world PNGs

The repository intentionally does not contain these binary placeholder assets. Create each file locally as a **32×32 RGBA PNG** at the exact path below; `assets/world.atlas` already references them and the animation ID is the filename without `.png`.

## Ground

- `assets/world/ground/grass_01.png`
- `assets/world/ground/dirt_01.png`
- `assets/world/ground/wood_floor_01.png`
- `assets/world/ground/basement_floor_01.png`
- `assets/world/ground/interior_01.png`

Ground tiles should fill the full image. `interior_01.png` may use transparency because it is a ground-detail overlay.

## Objects

- `assets/world/objects/wall_01.png`
- `assets/world/objects/door_closed_01.png`
- `assets/world/objects/door_open_01.png`
- `assets/world/objects/table_01.png`
- `assets/world/objects/chest_01.png`
- `assets/world/objects/stairs_01.png`
- `assets/world/objects/roof_01.png`
- `assets/world/objects/fallback_01.png`

Use transparent backgrounds for objects. `fallback_01.png` should be visually unmistakable so missing render assignments are easy to diagnose.

## Actors

- `assets/world/actors/player_01.png`
- `assets/world/actors/villager_01.png`
- `assets/world/actors/rat_01.png`

Use transparent backgrounds and a centered, bottom-aligned character footprint. These are static, non-directional images in the current renderer.

## Items

- `assets/world/items/herb_01.png`
- `assets/world/items/key_01.png`
- `assets/world/items/sword_01.png`
- `assets/world/items/leather_armor_01.png`

Use transparent backgrounds and keep the item centered within the tile.

After creating the files, open `game.project` in Defold and rebuild. Keep these filenames unchanged unless you also update `assets/world.atlas`, `render/world_animations.lua`, and the relevant logical render definitions.
