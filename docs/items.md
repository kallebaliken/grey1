# Item model

## Decision

Canary separates the shared `ItemType` catalog from individual `Item` objects. Greyhaven preserves that distinction as two pure-Lua concepts:

| Canary concept | Greyhaven equivalent | Important difference |
| --- | --- | --- |
| `ItemType` | `items/item_registry.lua` entries loaded from `items/item_defs.lua` | Definitions use stable string IDs and contain only local RPG data. The registry validates and copies definitions rather than loading server/client protocol metadata. |
| `Item` | `items/item_instance.lua` value | An instance has a stable string ID, definition type, bounded quantity, and independently copied mutable state. It has no cylinder parent, network identity, database behavior, or inheritance hierarchy. |
| Stack count/subtype | `quantity` constrained by `max_stack` | Quantity is never overloaded with fluid type, charges, or protocol subtype. Future concepts receive explicit state fields. |

Definitions are treated as immutable configuration: the registry owns a deep copy and returns copies to consumers. Instance state is also copied on construction so map or content tables cannot become runtime state accidentally. A stackable definition has an explicit integer `max_stack`; a non-stackable definition always has an effective maximum of one.

## Containers

Canary's `Container` combines item ownership with its general `Cylinder` movement hierarchy, nested traversal, networking, and specialized depot/inbox behavior. Greyhaven replaces the reusable part with `items/container.lua`: a pure-Lua, fixed-slot holder of item instances. It has a stable container ID, deterministic insertion order, and no Defold dependency. Capacity counts logical slots; every non-stackable item and every stack uses one slot.

Container contents are private. Added instances, returned instances, and item-list snapshots are copies, so callers cannot mutate stored state accidentally. Item IDs must be unique within a container. Compatible stacks have the same item type and equal instance state. When they merge, the existing stack ID survives. If overflow fits a new slot, that stack keeps the incoming ID.

`add_item` always returns `{ inserted_quantity, remainder }`. A `nil` remainder means the entire incoming quantity was accepted. On a partial insertion, `remainder` is an isolated item instance with the incoming ID and uninserted quantity; overflow is never discarded and the caller's input is never mutated.

## Inventory ownership

Canary's player inventory participates in the `Player`/`Cylinder` hierarchy and mixes ownership with equipment slots, protocol updates, capacity weight, and item movement. Greyhaven's `items/inventory.lua` preserves only the ownership boundary: an inventory has stable `id` and `owner_id` values and composes exactly one generic container. It stores no actor table, so the same abstraction can later be owned by an NPC, merchant, companion, or monster ID.

Inventory operations delegate insertion, removal, snapshots, stack identity, overflow, and slot capacity directly to the container subsystem. The underlying container is available through `get_container` and has the deterministic ID `<inventory-id>.items`. Type queries aggregate quantities across stacks and instance states. Inventory metadata and returned item snapshots cannot be used to mutate internal state.

Removal currently removes the complete item instance identified by its stable ID. Partial stack removal is deferred because generic containers do not yet define that operation.

## Equipment ownership

Canary combines inventory slots and equipment behavior inside `Player`/`Cylinder` movement. Greyhaven instead composes `items/equipment.lua` beside the inventory. `items/equipment_slots.lua` is the canonical data-driven slot list, while each item definition declares its allowed slots under `equipment.slots`. Items without that policy cannot be equipped, and equippable items are non-stackable.

Equip validates the item, requested slot, policy, and vacancy before removing the instance from inventory. The simpler occupied-slot policy rejects replacement; callers explicitly unequip first. Unequip asks the existing inventory/container to accept the item before clearing the slot, so a full inventory leaves equipment unchanged. Both directions preserve the item ID and emit `item_equipped` or `item_unequipped` only for successful gameplay transfers. Read APIs and snapshots return copies rather than live slot tables.

## World ownership and transfers

Canary moves an `Item` between `Tile` and `Cylinder` parents through its server movement machinery. Greyhaven keeps the transferable concept but makes the operation explicit: `world/world_items.lua` places the same item-instance model in a logical tile stack, while `simulation/item_transfers.lua` coordinates ownership changes between that world location and an inventory. A world placement has its own stable placement ID, position, and contained item instance; it is not another item type.

Pickup first asks the inventory/container how much it can accept. Only that quantity leaves the world: a partial stack retains its item ID and remaining quantity on the tile, while a fully accepted instance exists only in inventory. Whole-instance drop validates the destination before removing the inventory item, then places it in the world under the deterministic placement ID `world.<item-id>`. The item ID therefore survives a world → inventory → world round trip. Transfer and world-placement events contain stable IDs, quantities, and logical `(x, y, z)` coordinates.

World items share deterministic tile ordering with fixtures but resolve visuals from item definitions. Placement requires an in-bounds existing ground tile at the requested Z level; it deliberately does not require that tile to be walkable. `pickupable` is an item-definition policy rather than a property of walls, doors, or other logical fixtures.

## Deferred boundaries

The item ownership layers deliberately do not yet implement equipment GUI, combat/stat effects, durability, nested backpacks or container references, item usage, merchants, loot generation, weight limits, or partial-stack dropping. Save version 3 persists inventory, equipment, static placement overrides, and dynamic world items through the existing versioned snapshot model; see `docs/save-format.md`.
