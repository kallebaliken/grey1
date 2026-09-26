# Shared mouse and UI input dispatch

Greyhaven routes pointer input through one read-only pipeline:

```text
Defold physical mouse coordinates
    -> render.layout.physical_to_virtual
    -> render.layout.classify_virtual_point
    -> ui.input_dispatch.hit_test
    -> semantic UI target / ui_click intent
```

Defold delivers mouse motion to `on_input` with a nil action ID, without a binding entry; only the left button uses a `mouse_trigger`. The adapter reads Defold's unadjusted, bottom-left-origin `screen_x`/`screen_y` fields (falling back to `x`/`y`), so orientation is normalized at that single boundary. `render.layout` remains the sole owner of physical scaling, centring, and unused-bar rejection. The dispatcher never performs scaling math. `ui/client_layout.lua` owns virtual hit rectangles for the eight Equipment nodes and sixteen Inventory nodes; its centres and sizes match the authored nodes in `main/world.gui`. These rectangles are independent of physical resolution.

Targets contain presentation/gameplay identities rather than GUI node IDs. Equipment uses `{ region = "sidebar", target_type = "equipment_slot", slot = <canonical slot> }`; Inventory uses `{ region = "sidebar", target_type = "inventory_slot", index = <1..16> }`. When a current read-only panel snapshot has an item in that target, `item_id` and `item_type` are copied into the result. Empty slots are still targets and have nil item identity.

A matched left click produces a `{ type = "ui_click", target = ... }` intent and is consumed before any future world-pointer handling. During dialogue it is still identified and consumed, but marked `blocked`; dialogue remains the authoritative gameplay input lock. The dispatcher does not call Equipment, Inventory, transfer, movement, interaction, or combat mutation APIs.

`ui/equipment_controller.lua` is the separate mutation boundary for Equipment and Inventory targets. An occupied Equipment slot delegates to `items.equipment.unequip`. An occupied Inventory slot reads its immutable ItemDefinition equipment policy, filters that policy through canonical `items.equipment_slots` order, selects the first compatible empty slot, and delegates to `items.equipment.equip`. Both directions preserve the exact item instance. Empty slots return `empty_slot`, ordinary items return `not_equippable`, all-compatible-slots-occupied returns `slot_occupied` without swapping, a full Inventory returns `inventory_full`, and dialogue-blocked intents return `input_locked`.

The dispatcher only identifies the clicked slot; the controller interprets it; ItemDefinition declares compatibility; Equipment performs the authoritative transfer; and the Inventory and Equipment panels independently reflect new snapshots. The GUI never equips an item directly. Hover only changes the authored slot node's color. F1 reports physical and virtual pointer coordinates, region, hover target, last clicked target, and whether dialogue blocked that intent. Rearranging, swapping, stack operations, right click, tooltips, and world mouse targeting remain deferred.

`ui/item_selection.lua` owns at most one transient selection containing only source, source slot, item ID/type, and optional presentation metadata. The first occupied-slot click selects without mutation; a second click on that same item at the same reconciled location invokes the existing controller. After an equip/unequip transfer, selection follows the exact ID through current panel snapshots but requires one fresh click at its new location before another action. Empty slots, dialogue, load/reset, and identities no longer found in either player-owned snapshot clear selection. Quantity changes preserve selection when the stable ID survives; a merged-away stack ID clears rather than being redirected.

Hover and selection use separate colors and one combined highlight fingerprint. Moving the pointer never changes selection. The GUI renders selection but never owns the item or performs the action.

`ui/item_drag.lua` adds a transient six-virtual-pixel gesture threshold above semantic targets. A press/release below threshold remains the existing selection click. Crossing the threshold captures the pointer, selects the exact source identity, updates a semantic drop target, and emits `drop_item` only on release. The drag model never calls gameplay APIs. `ui/equipment_controller.lua` validates the exact authored Equipment target and invokes public `equip`, or invokes public `unequip` when an equipped item is released over the Inventory panel. Inventory-to-Inventory, Equipment-to-Equipment, world, background, and outside-client drops never mutate ownership.

The GUI renders one 28×28 atlas-backed translucent ghost while retaining and dimming the source icon. Compatible empty Equipment slots are green, occupied/incompatible targets are red, and the Inventory panel is highlighted for an Equipment-origin drag. The authored GUI now uses 101 nodes under the unchanged `max_nodes = 112`, leaving 11 nodes of headroom. Drag is cancelled by Escape, dialogue, save, load/reset session reconstruction, or disappearance of its authoritative source identity. Drag state is never serialized, and the GUI never transfers an item directly.
