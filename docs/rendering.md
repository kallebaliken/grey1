# Atlas-backed world rendering

Greyhaven keeps presentation downstream of authoritative state:

```text
Map placement -> logical definition -> normalized render pieces -> render commands
              -> Defold sprite adapter -> world atlas image
```

Actors follow the equivalent Actor state -> Actor renderer -> sprite adapter path. HUD text, F1 diagnostics, and dialogue remain in `main/world.gui`; the GUI no longer creates world nodes.

## Fixed presentation layout

Greyhaven has four deliberately separate concepts:

1. **Logical world:** authoritative integer 32×32 tile coordinates used by gameplay.
2. **World presentation:** fixed 2x zoom makes each 32×32 logical tile occupy 64×64 virtual pixels.
3. **Greyhaven client:** a fixed 1280×800 GUI canvas. The clipped world rectangle is `(0, 160, 960, 640)`, its centre is `(480, 480)`, the bottom panel is `(0, 0, 960, 160)`, and the permanent sidebar is `(960, 0, 320, 800)`. The world rectangle always exposes 15×10 logical tiles; the existing two-tile culling margin only admits graphics that may overlap the clipped edge.
4. **Physical window:** arbitrary size. `render/layout.lua` computes one uniform `min(physical_width / 1280, physical_height / 800)` scale and centred letterbox/pillarbox offsets. The custom render script projects the complete virtual client through that physical viewport and uses a separate physical viewport for the world rectangle.

The custom pipeline targets Defold 1.13.1. Buffer-clear keys and supported blend/depth state values come from `graphics` (`BUFFER_TYPE_COLOR0_BIT`, `BUFFER_TYPE_DEPTH_BIT`, `BUFFER_TYPE_STENCIL_BIT`, blend/depth states and factors); `render` owns the operations themselves. This version exposes neither a supported scissor render state nor `render.set_scissor`. World clipping therefore uses the rasterization viewport itself: the renderer selects the physical 960×640-scaled world rectangle and a matching world-only orthographic projection, draws world sprites, then restores the full physical canvas viewport and 1280×800 projection before GUI drawing. Required constants are asserted during initialization so an API mismatch fails descriptively.

World pieces use the built-in alpha-blended Sprite material and painter ordering from the deterministic render-command sequence. Depth testing and depth writes remain disabled for this pass. Transparent pixels still produce fragments, so writing their whole sprite quads to depth would incorrectly occlude already-drawn ground and appear as black rectangles or bands around Actors, items, walls, and roofs.

The camera follows the player's interpolated presentation position around `(480, 480)`, never the full-client centre. The sidebar and bottom panel are therefore never additional world space. Resizing only changes the physical client scale and black bars; it cannot change camera zoom, logical culling dimensions, Sprite positions, or visible tile count. Windows smaller than 1280×800 are supported by uniform downscaling with no configured minimum, although non-integer physical scales can produce uneven pixel sizes despite nearest-neighbour sampling.

GUI nodes use the same fixed 1280×800 virtual coordinates and are grouped beneath client, world-frame, sidebar, bottom, dialogue, and debug roots. The sidebar provides nonfunctional map, status, equipment, inventory, and utility placeholders. The bottom panel provides nonfunctional Log/Dialogue/Combat/Journal tabs, current notice text, and debug-only controls. Dialogue remains a GUI overlay in the lower world view and does not resize it. Keyboard input is unaffected. Future mouse input must first apply `layout.physical_to_virtual()`, reject points outside `layout.VIRTUAL`, then use `is_world_point`, `is_sidebar_point`, or `is_bottom_panel_point` before any world-tile mapping.

```text
GREYHAVEN CLIENT 1280x800

+--------------------------------------+-------------+
|              WORLD 960x640           |  SIDEBAR    |
|          15x10 tiles @ 2x            |  320x800    |
+--------------------------------------+             |
|          BOTTOM PANEL 960x160         |             |
+--------------------------------------+-------------+
```

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

The exhaustive uncropped prototype render-command check peaks at **332 visible world pieces**. The fixed 15×10 exterior viewport at the authored player position produces **259 pieces**: 212 ground/detail, 25 world-object, 4 item, 2 Actor, and 16 roof pieces. Multi-piece commands are included in those categories. Each piece consumes one factory-created Game Object and one Sprite component. Standing still reuses all stable identities; the automated reconciliation test verifies that active count does not grow.

The prior Sprite capacity was Defold's default **128**, which was below the 332-piece conservative peak even though `collection.max_instances` was already **4096**. `game.project` now explicitly configures `sprite.max_count = 2048` and retains `collection.max_instances = 4096`. That leaves more than 1,700 Sprite slots and 3,700 Game Object slots above the measured peak, including headroom for non-world components and future effects. The runtime reads both compiled settings for F1 diagnostics. Project settings require a clean rebuild; hot reload cannot resize existing component or collection buffers.

Allocation reconciliation is mark-and-sweep. Unchanged command IDs reuse the same successful factory handle, including when only their animation changes, and pieces absent from the next frame are deleted and removed from the identity table. The creation budget is the lower of the Game Object capacity (with 32 reserved) and Sprite capacity (with 16 reserved). If a viewport replacement would temporarily exceed that budget while deferred deletions are pending, new pieces are deferred until the next frame rather than calling the factory into exhaustion. A failed `factory.create()` result is never stored, positioned, scaled, animated, or addressed as a Sprite; it is counted, logged once per failure streak, skipped, and retried on the next frame. Successful handles address the prototype's exact `sprite` component as `<spawned-instance>#sprite`.

The adapter projects current camera-relative coordinates without changing logical coordinates, scales sprite Game Objects and authored graphical offsets by the same integer zoom, and leaves GUI nodes untouched. Viewport dimensions are divided by `32 * zoom`, while the existing two-tile graphical margin remains. Default minification and magnification filters are nearest-neighbour so enlarged pixel art stays crisp. Pure-Lua ordering first separates ground, details, bottom items, the shared Y-sorted Actor/top-object band, effects, and roofs. Within the world band, each piece's logical anchor plus graphical pixel offset supplies its sort point; higher Y draws first so pieces lower on screen overlap naturally, and stable IDs break remaining ties. The adapter maps that final order into `[-0.8, 0.8]`, keeping semantic layer numbers and logical Z levels out of Defold depth values.

## Replacing grass

1. Replace `assets/world/ground/grass_01.png` with another 32×32 PNG.
2. Keep the atlas image/animation ID `grass_01`.
3. Rebuild Defold. Every logical `grass` placement uses the replacement automatically.

To add `grass_02` or `grass_03`, add the PNG to `assets/world.atlas`, register its ID in `render/world_animations.lua`, then list its animation ID in the definition's future `render.variants` data. Variant selection should remain authored/deterministic when that feature is connected; map collision and gameplay data require no changes.

This milestone intentionally excludes animation, lighting, shaders, tile blending, autotiling, fractional/dynamic camera zoom, and production batching.
