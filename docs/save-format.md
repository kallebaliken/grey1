# Save format v4

Defold persists a versioned local snapshot with `sys.save` at `sys.get_save_file("greyhaven", "engine_test")`. Version 4 adds composed player health/death state to the item-aware player, equipment, object-delta, and flag state:

```lua
{
  version = 4,
  map_id = "greyhaven.engine_test",
  player = { x = 5, y = 5, z = 6, facing = "south" },
  combat = { player = { actor_id = "player", max_health = 100, health = 65, dead = false } },
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
6. Restore player position/facing and composed player combat state.
7. Use the already-seeded object/flag state and reserve all restored item IDs in the session allocator.

This order prevents authored items from respawning after their saved ownership has moved elsewhere. An item ID must resolve to exactly one retained static placement, dynamic placement, inventory entry, or equipment slot.

## Migration and reset

Versions 1–3 are intentionally rejected as `unsupported_save_version`; version 3 has no player combat state and format semantics were not changed in place. **F8** deletes the development save and immediately rebuilds authored full health, static Actor health, map state, starter inventory, and empty equipment. F5 writes version 4, and F9 validates and reconstructs a new session before replacing runtime references. Only player combat state persists in v4; static NPC/monster combat deltas are deferred until general Actor persistence exists.

Attack profiles come from static map data and attack cooldowns are temporary simulation runtime. Cooldowns are deliberately absent from Save Format v4; loading or resetting starts every authored attack profile ready.

Weapon damage is also derived rather than serialized: equipped item identity/type already persists in the equipment snapshot, and its immutable item definition supplies `weapon.damage` after load. No save-version change is required for equipped weapon integration.

Armor mitigation follows the same rule: equipped item identity/type persists, immutable definitions supply `armor.defense`, and total defense is recomputed after load. Save Format v4 stores no derived armor total.

Creature definitions are immutable authored data and are never serialized. Static NPC/monster Actors are reconstructed from map placements and definitions when a session starts. Save Format v4 still persists player combat state only; general creature health, death, cooldown, and position persistence remains deferred.

Faction definitions and directional relationships are immutable authored data. Player and creature Actor associations reconstruct during session composition, so Save Format v4 stores neither faction definitions nor associations. Dynamic reputation and relationship persistence do not exist.

Dialogue definitions are immutable authored data and active DialogueSessions are deliberately temporary. Save Format v4 stores neither definitions nor current speaker/node; loading or resetting always begins with no active conversation.

The existing top-level `flags` table stores stable boolean WorldState facts. Unset flags read false, saved true/false values restore through `state.world_state.new`, and validation rejects unstable IDs or non-boolean values. Condition results are derived and never serialized, so this extension requires no version bump.

`state/save_data.lua` owns pure snapshot, validation, and restoration transforms. `state/save_manager.lua` remains the only Defold `sys.save`/`sys.load` adapter. `state/save_codec.lua` supplies deterministic text round-trip coverage for pure-Lua tests and is not used to read arbitrary runtime files.
