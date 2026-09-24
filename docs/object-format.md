# Logical object format

Definitions are immutable traits keyed by type. Instances are stable placed identities.

```lua
-- definition
wall = { id = "wall", graphical_width = 2, graphical_height = 2,
  footprint_width = 1, footprint_height = 1, blocking = true,
  stack_layer = "top", patterns = { ... } }

-- instance in a map
{ id = "greyhaven.house01.wall_nw", type = "wall",
  x = 20, y = 18, z = 7, variant = 1, state = {}, metadata = {} }
```

Graphical dimensions select row-major draw pieces; footprint dimensions select tiles receiving collision/interaction entries. They never imply one another. Stack layers are `ground`, `ground_detail`, `bottom`, `top`, `actor`, `effect`, and `roof`, with ordering centralized in world/render modules.

Definitions may provide `blocking_state(state)` and `state_patterns(state)` to derive collision and appearance from merged state. `interaction` names a registered handler (`door`, `stairs`, or the current chest placeholder); adding types does not add conditionals to the game manager.
