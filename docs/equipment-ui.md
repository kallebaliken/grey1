# Equipment sidebar UI

The equipment panel is a presentation adapter over Greyhaven's existing equipment model:

```text
Equipment runtime (authoritative)
    -> equipment_panel.snapshot()
    -> shared frame view model
    -> authored sidebar GUI slot nodes
```

`items/equipment_slots.lua` remains the canonical source of the eight slot IDs and their order. `ui/equipment_panel.lua` queries each slot through `items/equipment.lua`, preserves the exact equipped item instance ID and type in its read-only presentation snapshot, and resolves the display name and atlas animation through the immutable item registry. GUI code never owns, copies into gameplay, equips, or unequips an item.

The eight recessed 28×28 virtual-pixel slots are created once in `main/world.gui`. Empty slots show compact letters; occupied slots hide that label and display the existing world-atlas animation at 24×24 virtual pixels. Icons do not inherit the 2x world-camera zoom—the complete 1280×800 client handles physical scaling uniformly.

`main/game_manager.script` rebuilds a safe snapshot whenever it publishes a presentation frame. `main/world.gui_script` compares a fingerprint and only updates icon visibility/animations when equipment identity changes. Existing L/O development controls, save/load, and reset already publish a new frame, so the panel follows authoritative mutations immediately. Combat continues to read Equipment directly for weapon damage and armor mitigation.

The current panel is deliberately read-only. Greyhaven has physical-to-virtual coordinate helpers, but no established mouse button binding/UI dispatch layer yet; click-to-unequip is deferred rather than adding fragile input plumbing. Future UI input must map physical coordinates into the virtual client, prioritize sidebar UI hits, and call the public Equipment/Inventory APIs. It must never mutate GUI or equipment slot tables directly.

The Inventory and Minimap sidebar regions remain nonfunctional placeholders. Drag/drop, inventory-to-equipment actions, swaps, context menus, tooltips, and final paper-doll artwork are outside this milestone.
