# Inventory UI boundary

`items.inventory` and its generic `items.container` remain the only authorities for inventory capacity, ordering, item identity, and quantity. `ui.inventory_panel` reads that public state into an isolated presentation snapshot; the Inventory GUI never owns item identity or quantity and no GUI state is serialized.

The adapter retains container order and exposes each visible entry's slot, exact item ID, type, quantity, display name, and shared atlas animation. Its fingerprint includes every presentation-relevant value, so pickup, drop, stack merges, equipment transfers, load, and reset refresh the existing nodes without rebuilding them each frame.

The sidebar presents a fixed 4×4 grid. Capacity and occupied count come from the real player inventory rather than the grid. If more than 16 authoritative entries exist, the first 16 remain visible in container order and the title reports `+N MORE`; scrolling and nested container windows are deliberately deferred.

Inventory-to-Inventory drag operates only on those visible indices. Because the underlying Container is a compact ordered sequence, an empty visible target appends the dragged entry to the end of occupied content; it does not create a persistent hole. Occupied incompatible entries swap. Compatible same-type/state stacks merge source into destination up to the authored maximum, retaining the destination ID; a partial source retains its own ID, and a full destination swaps instead. Overflow entries remain authoritative and keep their relative order but cannot be direct drag sources or targets without future scrolling.

Icons are 28×28 virtual GUI pixels and use the existing world atlas IDs without inheriting the 2× world-camera zoom. Quantity labels appear only above one. Inventory and Equipment are separate read-only projections of their respective ownership systems, so transfers synchronize naturally through authoritative gameplay APIs rather than GUI coordination.

Equipment drag/drop and authoritative visible Inventory rearranging are supported. Stack splitting, item use, scrolling, sorting, tooltips, and context menus remain outside this milestone.
