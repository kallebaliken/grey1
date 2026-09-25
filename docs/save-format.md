# Save format v5

Defold persists a versioned local snapshot with `sys.save` at `sys.get_save_file("greyhaven", "engine_test")`. Version 5 adds persistent quest runtime state to the existing player, combat, item-ownership, object-delta, and flag snapshot. Version 4 is intentionally rejected rather than silently interpreted without quest state:

```lua
{
  version = 5,
  map_id = "greyhaven.engine_test",
  player = { x = 5, y = 5, z = 6, facing = "south" },
  combat = { player = { actor_id = "player", max_health = 100, health = 65, dead = false } },
  objects = { ["greyhaven.house01.front_door"] = { open = true } },
  flags = {},
  quests = {
    rat_problem = { status = "active", objectives = { investigate = 1 } }
  },
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
7. Restore quest progress through the validated QuestState service.
8. Use the already-seeded object/flag state and reserve all restored item IDs in the session allocator.

This order prevents authored items from respawning after their saved ownership has moved elsewhere. An item ID must resolve to exactly one retained static placement, dynamic placement, inventory entry, or equipment slot.

## Migration and reset

Versions 1–4 are intentionally rejected as `unsupported_save_version`; version 4 has no quest state and is not silently reinterpreted. **F8** deletes the development save and immediately rebuilds authored full health, static Actor health, map state, starter inventory, and empty equipment. F5 writes version 5, and F9 validates and reconstructs a new session before replacing runtime references. Only player combat state persists in v5; static NPC/monster combat deltas are deferred until general Actor persistence exists.

Attack profiles come from static map data and attack cooldowns are temporary simulation runtime. Cooldowns are deliberately absent from Save Format v5; loading or resetting starts every authored attack profile ready.

Weapon damage is also derived rather than serialized: equipped item identity/type already persists in the equipment snapshot, and its immutable item definition supplies `weapon.damage` after load. No save-version change is required for equipped weapon integration.

Armor mitigation follows the same rule: equipped item identity/type persists, immutable definitions supply `armor.defense`, and total defense is recomputed after load. Save Format v5 stores no derived armor total.

Creature definitions are immutable authored data and are never serialized. Static NPC/monster Actors are reconstructed from map placements and definitions when a session starts. Save Format v5 still persists player combat state only; general creature health, death, cooldown, and position persistence remains deferred.

Faction definitions and directional relationships are immutable authored data. Player and creature Actor associations reconstruct during session composition, so Save Format v5 stores neither faction definitions nor associations. Dynamic reputation and relationship persistence do not exist.

Dialogue definitions are immutable authored data and active DialogueSessions are deliberately temporary. Save Format v5 stores neither definitions nor current speaker/node; loading or resetting always begins with no active conversation.

The existing top-level `flags` table stores stable boolean WorldState facts. Unset flags read false, saved true/false values restore through `state.world_state.new`, and validation rejects unstable IDs or non-boolean values. Condition results are derived and never serialized; flags themselves did not require the version bump introduced later for quest state.

Validated `set_flag` actions write through that same WorldState API. Saves persist only their resulting flags (including `greyhaven.met_test_villager`), never action history. Loading therefore restores dialogue-visible facts naturally without a format bump, while reset returns them to authored/unset false defaults.

`state/save_data.lua` owns pure snapshot, validation, and restoration transforms. `state/save_manager.lua` remains the only Defold `sys.save`/`sys.load` adapter. `state/save_codec.lua` supplies deterministic text round-trip coverage for pure-Lua tests and is not used to read arbitrary runtime files.

## Quest state

The top-level `quests` table contains mutable runtime state only: canonical quest IDs map to `active` or `completed` status plus integer objective counters. `not_started` quests are absent. Immutable titles, descriptions, objective descriptions, and targets remain in the quest registry. Generic save validation rejects malformed IDs, statuses, and counters; the QuestState restore boundary additionally validates authored quest/objective existence, target bounds, and completed-state consistency. F8 reconstructs an empty quest service, so every quest returns `not_started`.

Quest-condition results are derived from restored QuestState and are never serialized. Dialogue therefore reflects active/completed status and objective completion immediately after load without changing Save Format v5.
