# Item model

## Decision

Canary separates the shared `ItemType` catalog from individual `Item` objects. Greyhaven preserves that distinction as two pure-Lua concepts:

| Canary concept | Greyhaven equivalent | Important difference |
| --- | --- | --- |
| `ItemType` | `items/item_registry.lua` entries loaded from `items/item_defs.lua` | Definitions use stable string IDs and contain only local RPG data. The registry validates and copies definitions rather than loading server/client protocol metadata. |
| `Item` | `items/item_instance.lua` value | An instance has a stable string ID, definition type, bounded quantity, and independently copied mutable state. It has no cylinder parent, network identity, database behavior, or inheritance hierarchy. |
| Stack count/subtype | `quantity` constrained by `max_stack` | Quantity is never overloaded with fluid type, charges, or protocol subtype. Future concepts receive explicit state fields. |

Definitions are treated as immutable configuration: the registry owns a deep copy and returns copies to consumers. Instance state is also copied on construction so map or content tables cannot become runtime state accidentally. A stackable definition has an explicit integer `max_stack`; a non-stackable definition always has an effective maximum of one.

## Boundary of this subsystem

This slice intentionally does not place items in the world or add containers, inventory, equipment, pickup/drop, effects, or persistence. Those systems should compose item instances rather than adding ownership fields to them. The next item-phase slice is a generic container with deterministic slots and stack merging.
