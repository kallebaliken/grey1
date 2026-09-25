# Atlas-backed world rendering

Greyhaven keeps presentation downstream of authoritative state:

```text
Map placement -> logical definition -> normalized render pieces -> render commands
              -> Defold sprite adapter -> world atlas image
```

Actors follow the equivalent Actor state -> Actor renderer -> sprite adapter path. HUD text, F1 diagnostics, and dialogue remain in `main/world.gui`; the GUI no longer creates world nodes.

## Atlas and definitions

`assets/world.atlas` declares the required 32×32 PNGs grouped under `assets/world/`. The binary PNGs are intentionally created locally; the complete required path list and image conventions live in `assets/world/ASSET_MANIFEST.md`. Logical object and item definitions refer only to atlas animation IDs such as `grass_01`; map placements never contain image paths. Creature render metadata similarly selects `player_01`, `villager_01`, or `rat_01` through the Actor renderer.

A single-piece definition is concise:

```lua
render = { animation = "grass_01" }
```

`render/render_definition.lua` normalizes that shorthand to one piece. `render/world_animations.lua` is the small validated catalog of animations actually packed into the atlas; missing or unknown visual IDs resolve to `fallback_01`. A multi-piece graphic remains independent from its collision footprint:

```lua
render = { pieces = {
    { animation = "wall_01", offset_x = 0,  offset_y = 0 },
    { animation = "wall_01", offset_x = 32, offset_y = 0 },
} }
```

Offsets are source-art pixels relative to the logical tile centre. One logical tile is always 32×32 units in gameplay. The presentation camera defaults to the integer `camera_zoom = 2` configured in `game.project`, so a tile and a 32-pixel piece offset each occupy 64 displayed pixels. Zoom may be configured to 1, 2, or 3 without changing maps, footprints, movement duration, or save data. Missing render metadata resolves to `fallback_01` rather than crashing. Optional ordered `variants` are supported by the data model, but current content selects authored variants deterministically and does not randomize terrain.

Door animation selection reads the existing authoritative `open` state. Roof visibility, floor selection, viewport culling, Actor interpolation, item ownership, and gameplay footprints remain in their existing systems.

## Sprite lifetime and ordering

`render/world_render_piece.go` contains one atlas-backed sprite. A single collection factory creates these pieces; `render/world_sprite_renderer.script` retains instances by stable render-command identity (`object ID + piece index`), updates animation/position, and deletes only pieces absent from the next visible command set.

The prototype exterior currently peaks at **332 visible sprite pieces**: 284 ground/detail pieces, 25 world-object pieces, 4 items, 3 Actors, and 16 roof pieces. Of those, 28 belong to multi-piece walls/roofs and overlap the category counts. `game.project` configures `collection.max_instances = 4096`, leaving more than 3,700 Game Object slots of development headroom for the root object, visible pieces, and later prototype additions. The runtime reads that compiled setting for diagnostics instead of repeating a constant. Project settings require a clean rebuild; hot reload cannot resize an already-created collection.

Allocation reconciliation is mark-and-sweep. Unchanged command IDs reuse the same successful factory handle, changed animations are sent only when necessary, and pieces absent from the next frame are deleted. A 32-instance reserve protects the collection's authored objects. If a viewport replacement would temporarily exceed the remaining sprite budget while deferred deletions are pending, new pieces are deferred until the next frame rather than calling the factory into exhaustion. A failed `factory.create()` result is never stored or addressed as a sprite; it is counted, logged once per failure streak, skipped, and retried on the next frame.

The adapter projects current camera-relative coordinates without changing logical coordinates, scales sprite Game Objects and authored graphical offsets by the same integer zoom, and leaves GUI nodes untouched. Viewport dimensions are divided by `32 * zoom`, while the existing two-tile graphical margin remains. Default minification and magnification filters are nearest-neighbour so enlarged pixel art stays crisp. Pure-Lua ordering first separates ground, details, bottom items, the shared Y-sorted Actor/top-object band, effects, and roofs. Within the world band, each piece's logical anchor plus graphical pixel offset supplies its sort point; higher Y draws first so pieces lower on screen overlap naturally, and stable IDs break remaining ties. The adapter maps that final order into `[-0.8, 0.8]`, keeping semantic layer numbers and logical Z levels out of Defold depth values.

## Replacing grass

1. Replace `assets/world/ground/grass_01.png` with another 32×32 PNG.
2. Keep the atlas image/animation ID `grass_01`.
3. Rebuild Defold. Every logical `grass` placement uses the replacement automatically.

To add `grass_02` or `grass_03`, add the PNG to `assets/world.atlas`, register its ID in `render/world_animations.lua`, then list its animation ID in the definition's future `render.variants` data. Variant selection should remain authored/deterministic when that feature is connected; map collision and gameplay data require no changes.

This milestone intentionally excludes animation, lighting, shaders, tile blending, autotiling, fractional/dynamic camera zoom, and production batching.
