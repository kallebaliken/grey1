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

## Deferred boundaries

Containers deliberately do not yet implement player inventory ownership, equipment, nested backpacks or container references, world pickup/drop, GUI, item effects, weight limits, or persistence. Future ownership systems should compose containers rather than adding those responsibilities here. The item representation leaves instance state extensible, but nested containers need explicit ownership and cycle rules before they are safe.
