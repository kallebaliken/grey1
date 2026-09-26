# Inventory UI boundary

`items.inventory` and its generic `items.container` remain the only authorities for inventory capacity, ordering, item identity, and quantity. `ui.inventory_panel` reads that public state into an isolated presentation snapshot; the Inventory GUI never owns item identity or quantity and no GUI state is serialized.

The adapter retains container order and exposes each visible entry's slot, exact item ID, type, quantity, display name, and shared atlas animation. Its fingerprint includes every presentation-relevant value, so pickup, drop, stack merges, equipment transfers, load, and reset refresh the existing nodes without rebuilding them each frame.

The sidebar presents a fixed 4×4 grid. Capacity and occupied count come from the real player inventory rather than the grid. If more than 16 authoritative entries exist, the first 16 remain visible in container order and the title reports `+N MORE`; scrolling and nested container windows are deliberately deferred.

Icons are 28×28 virtual GUI pixels and use the existing world atlas IDs without inheriting the 2× world-camera zoom. Quantity labels appear only above one. Inventory and Equipment are separate read-only projections of their respective ownership systems, so transfers synchronize naturally through authoritative gameplay APIs rather than GUI coordination.

Mouse inventory operations, drag/drop, item use, reordering, sorting, tooltips, and context menus are outside this milestone.
