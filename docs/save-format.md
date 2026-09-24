# Save format v3

Defold persists a versioned local snapshot with `sys.save` at `sys.get_save_file("greyhaven", "engine_test")`. Version 3 adds equipment ownership to the item-aware player, object-delta, and flag state:

```lua
{
  version = 3,
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
  equipment = {
    id = "equipment.player", owner_id = "player",
    slots = {
      main_hand = { id = "gear.saved.000001", type = "worn_iron_sword",
        quantity = 1, state = { maker = "Mara" } }
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
- An **equipped item** appears only under its canonical equipment slot and retains the same item-instance schema and identity.

Before saving or loading, validation rejects duplicate item ownership across inventory, equipment, and world; duplicate dynamic placement IDs; unknown equipment slots; unknown static overrides; malformed positions; and incompatible map/version identities. Snapshots come from public ownership APIs and contain copies rather than live internal tables. Item ID allocators reserve every restored inventory, equipment, and world ID before producing new IDs.

## Deterministic load order

The runtime restores in this order:

1. Load immutable map content and construct its original objects and static world items.
2. Apply static world-item removals and quantity/state overrides without gameplay events.
3. Restore the player inventory through its validated public constructor.
4. Restore equipment through its validated slot policy.
5. Restore dynamic world items through validated placement APIs, without gameplay transfer events.
6. Restore player position/facing and use the already-seeded object/flag state.
7. Reserve all restored item IDs in the session allocator.

This order prevents authored items from respawning after their saved ownership has moved elsewhere. An item ID must resolve to exactly one retained static placement, dynamic placement, inventory entry, or equipment slot.

## Migration and reset

Versions 1 and 2 are intentionally rejected as `unsupported_save_version`; version 2 has no equipment ownership field, so it cannot safely infer whether an item should be equipped or carried. **F8** deletes the development save and immediately rebuilds the authored map, starter inventory, and empty equipment. F5 writes version 3, and F9 validates and reconstructs a new session before replacing runtime references.

`state/save_data.lua` owns pure snapshot, validation, and restoration transforms. `state/save_manager.lua` remains the only Defold `sys.save`/`sys.load` adapter. `state/save_codec.lua` supplies deterministic text round-trip coverage for pure-Lua tests and is not used to read arbitrary runtime files.
