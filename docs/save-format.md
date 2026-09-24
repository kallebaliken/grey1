# Save format v1

Defold persists the following table with `sys.save` at `sys.get_save_file("greyhaven", "engine_test")`:

```lua
{
  version = 1,
  map_id = "greyhaven.engine_test",
  player = { x = 5, y = 5, z = 6, facing = "south" },
  objects = { ["greyhaven.house01.front_door"] = { open = true } },
  flags = {}
}
```

`state/save_data.lua` captures, validates, and restores this pure data. `state/save_manager.lua` is the sole Defold persistence adapter. Static geometry, definitions, and initial state are not duplicated. On load, object deltas seed `WorldState`; object queries merge them over initial state. Wrong versions/maps and malformed player or state tables are rejected before session replacement.

F5 saves, F9 reloads, and F8 deletes the development save. `state/save_codec.lua` supplies deterministic text round-trip coverage for pure-Lua tests; it is not used to read arbitrary runtime files.
