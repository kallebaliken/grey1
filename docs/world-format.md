# World format v1

A development map is a Lua module returning immutable initial data:

```lua
return {
  version = 1, id = "greyhaven.engine_test", tile_size = 32,
  width = 18, height = 14,
  player_spawn = { x = 9, y = 2, z = 7, facing = "west" },
  placements = {
    { id = "greyhaven.house01.front_door", type = "wood_door",
      x = 6, y = 3, z = 7, variant = 1,
      state = { open = false }, metadata = {} }
  }
}
```

Every placement ID is a stable, unique string. `type` resolves a definition. `state` is the initial state; save/runtime state overrides matching fields without editing this table. `metadata` holds instance-specific facts such as explicit transition destinations, `interior_group`, `roof_group`, and reveal zones.

Coordinates are integer tiles and `tile_size` is 32. Storage maps them into 32×32 chunks; chunking is an implementation detail and does not leak into authored placement coordinates. Lower and higher Z values are both valid. Only the current gameplay level is interactive.
