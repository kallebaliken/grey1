# World format v1

A development map is a Lua module returning immutable initial data:

```lua
return {
  version = 1, id = "greyhaven.engine_test", tile_size = 32,
  width = 18, height = 14,
  player_spawn = { x = 9, y = 2, z = 7, facing = "west" },
  player_max_health = 100,
  player_attack = { damage = 5, range = 1, cooldown = 0.75 },
  actor_placements = {
    { id = "npc_test_villager", creature = "test_villager", x = 12, y = 5, z = 7, facing = "south" },
    { id = "monster_test_rat", creature = "rat", x = 14, y = 10, z = 7, facing = "west" }
  },
  placements = {
    { id = "greyhaven.house01.front_door", type = "wood_door",
      x = 6, y = 3, z = 7, variant = 1,
      state = { open = false }, metadata = {} }
  },
  item_placements = {
    { id = "world.test.herbs.01",
      item = { id = "test.herbs.01", type = "healing_herb", quantity = 5 },
      position = { x = 8, y = 2, z = 7 } }
  },
  player_inventory = {
    id = "inventory.player", owner_id = "player", capacity = 2,
    items = {
      { id = "test.starter.000001", type = "healing_herb", quantity = 15,
      state = { quality = "fresh" } }
    }
  },
  player_equipment = { id = "equipment.player", owner_id = "player", slots = {} }
}
```

Every placement ID is a stable, unique string. `type` resolves a definition. `state` is the initial state; save/runtime state overrides matching fields without editing this table. `metadata` holds instance-specific facts such as explicit transition destinations, `interior_group`, `roof_group`, and reveal zones.

`item_placements` is optional immutable map input. Its outer ID identifies the world placement, while `item.id` is the stable logical item identity that survives pickup and drop. The embedded item record uses the same item-instance schema as inventories and containers; runtime transfers never rewrite this source table.

Weapon behavior is item-definition data, not placement data. The prototype authors `test.sword.01` as an ordinary `worn_iron_sword` world item; pickup and equipment retain that item identity while attacks resolve damage from its definition.

Armor behavior is also definition data. The prototype authors `test.armor.01` as an ordinary `patched_leather_armor` world item; only equipping that same instance makes its defense participate in mitigation.

`player_max_health` is the authored positive-integer new-game maximum. Non-player combat state comes from optional `combat` metadata on the referenced creature definition; definitions without it remain Actor-only.

`player_attack` explicitly composes the player. Non-player attack capability comes from optional creature-definition `attack` metadata and still uses the same fixed-damage service. Cooldown runtime is session-only and is not map or save mutation.

`player_inventory` is the authored new-game inventory. Save v4 replaces it with the saved inventory snapshot on load; reset returns to this authored value. It is content input, not a live runtime container.

`player_equipment` is the authored new-game equipment snapshot. Its slot keys must come from `items/equipment_slots.lua`, and each item must satisfy its definition's equipment policy. Save v4 restores equipment separately from inventory so ownership stays exclusive.

Coordinates are integer tiles and `tile_size` is 32. Storage maps them into 32×32 chunks; chunking is an implementation detail and does not leak into authored placement coordinates. Lower and higher Z values are both valid. Only the current gameplay level is interactive.

`actor_placements` optionally seeds inert non-player Actors through a stable `creature` definition reference and the same validated Actor constructor/world occupancy path used by the player. Instance IDs and definition IDs are distinct. Type, optional faction/dialogue/combat/attack components, and prototype render metadata live in immutable creature definitions; no autonomous behavior is encoded in either placement or definition. Faction or dialogue placement overrides are intentionally unsupported in this slice.
