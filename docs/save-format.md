# Save format v2

Defold persists a versioned local snapshot with `sys.save` at `sys.get_save_file("greyhaven", "engine_test")`. Version 2 adds explicit item ownership to the existing player, object-delta, and flag state:

```lua
{
  version = 2,
  map_id = "greyhaven.engine_test",
  player = { x = 5, y = 5, z = 6, facing = "south" },
  objects = { ["greyhaven.house01.front_door"] = { open = true } },
  flags = {},
  inventory = {
    id = "inventory.player", owner_id = "player", capacity = 2,
    items = {
      { id = "test.key.01", type = "old_iron_key", quantity = 1, state = {} }
    }
  },
  world_items = {
    static_overrides = {
      ["world.test.key.01"] = { removed = true },
      ["world.test.herbs.01"] = { quantity = 5, state = { quality = "fresh" } }
    },
    dynamic = {
      { id = "world.test.starter.000001", x = 9, y = 3, z = 7,
        item = { id = "test.starter.000001", type = "healing_herb",
          quantity = 20, state = { quality = "fresh" } } }
    }
  }
}
```

## Static data and deltas

The map remains the source of original geometry and original `item_placements`. Saves never copy unchanged map items:

- A **static map item** is an authored `item_placements` entry.
- A **persistent override** records only removal or changed quantity/state for that static placement.
- A **dynamic world item** is a runtime placement, such as a dropped inventory item, and therefore stores its world-placement ID, item instance, and logical coordinates.
- An **inventory item** appears only in the inventory snapshot and retains its item-instance ID, quantity, and mutable state.

Before saving or loading, validation rejects duplicate item ownership, duplicate dynamic placement IDs, unknown static overrides, malformed positions, and incompatible map/version identities. Snapshots come from public inventory/world-item APIs and contain copies rather than live internal tables. Item ID allocators reserve every restored inventory and world ID before producing new IDs.

## Deterministic load order

The runtime restores in this order:

1. Load immutable map content and construct its original objects and static world items.
2. Apply static world-item removals and quantity/state overrides without gameplay events.
3. Restore the player inventory through its validated public constructor.
4. Restore dynamic world items through validated placement APIs, without pickup/drop events.
5. Restore player position/facing and use the already-seeded object/flag state.
6. Reserve all restored item IDs in the session allocator.

This order prevents authored items from respawning after their saved ownership has moved elsewhere. An item ID must resolve to exactly one retained static placement, dynamic placement, or inventory entry.

## Migration and reset

Version 1 saves are intentionally rejected as `unsupported_save_version`; they did not contain enough ownership information to infer where items belong safely. **F8** deletes the development save and immediately rebuilds the authored map and starter inventory. F5 writes version 2, and F9 validates and reconstructs a new session before replacing runtime references.

`state/save_data.lua` owns pure snapshot, validation, and restoration transforms. `state/save_manager.lua` remains the only Defold `sys.save`/`sys.load` adapter. `state/save_codec.lua` supplies deterministic text round-trip coverage for pure-Lua tests and is not used to read arbitrary runtime files.
