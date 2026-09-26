# Shared mouse and UI input dispatch

Greyhaven routes pointer input through one read-only pipeline:

```text
Defold physical mouse coordinates
    -> render.layout.physical_to_virtual
    -> render.layout.classify_virtual_point
    -> ui.input_dispatch.hit_test
    -> semantic UI target / ui_click intent
```

The adapter reads Defold's unadjusted, bottom-left-origin `screen_x`/`screen_y` fields (falling back to `x`/`y), so orientation is normalized at that single boundary. `render.layout` remains the sole owner of physical scaling, centring, and unused-bar rejection. The dispatcher never performs scaling math. `ui/client_layout.lua` owns virtual hit rectangles for the eight Equipment nodes and sixteen Inventory nodes; its centres and sizes match the authored nodes in `main/world.gui`. These rectangles are independent of physical resolution.

Targets contain presentation/gameplay identities rather than GUI node IDs. Equipment uses `{ region = "sidebar", target_type = "equipment_slot", slot = <canonical slot> }`; Inventory uses `{ region = "sidebar", target_type = "inventory_slot", index = <1..16> }`. When a current read-only panel snapshot has an item in that target, `item_id` and `item_type` are copied into the result. Empty slots are still targets and have nil item identity.

A matched left click produces a `{ type = "ui_click", target = ... }` intent and is consumed before any future world-pointer handling. During dialogue it is still identified and consumed, but marked `blocked`; dialogue remains the authoritative gameplay input lock. The dispatcher does not call Equipment, Inventory, transfer, movement, interaction, or combat mutation APIs.

Hover only changes the authored slot node's color. F1 reports physical and virtual pointer coordinates, region, hover target, last clicked target, and whether dialogue blocked that intent. Click controllers, equipment/inventory mutation, drag/drop, right click, tooltips, and world mouse targeting remain deferred.
