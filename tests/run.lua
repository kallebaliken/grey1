package.path = "./?.lua;./?/init.lua;" .. package.path

local position = require "world.position"
local chunks = require "world.chunks"
local registry_api = require "world.object_registry"
local world_api = require "world.world"
local map_loader = require "world.map_loader"
local state_api = require "state.world_state"
local actor_api = require "actors.actor"
local actor_types = require "actors.actor_types"
local actor_registry_api = require "actors.registry"
local direction = require "world.direction"
local movement = require "simulation.movement"
local pathfinding = require "simulation.pathfinding"
local transitions = require "simulation.transitions"
local interaction = require "simulation.interaction"
local actions = require "simulation.actions"
local roofs = require "world.roofs"
local save_data = require "state.save_data"
local codec = require "state.save_codec"
local definitions = require "objects.object_defs"
local item_definitions = require "items.item_defs"
local item_registry_api = require "items.item_registry"
local item_instance = require "items.item_instance"
local container_api = require "items.container"
local inventory_api = require "items.inventory"
local equipment_api = require "items.equipment"
local equipment_slots = require "items.equipment_slots"
local world_items = require "world.world_items"
local item_transfers = require "simulation.item_transfers"
local renderer = require "render.world_renderer"
local events = require "core.events"

local count = 0
local function test(name, callback)
    local ok, message = pcall(callback)
    if not ok then error("FAIL " .. name .. ": " .. tostring(message), 0) end
    count = count + 1; print("PASS " .. name)
end
local function equal(actual, expected) assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected)) end
local function placement(id, object_type, x, y, z, state, metadata)
    return { id = id, type = object_type, x = x, y = y, z = z, state = state or {}, metadata = metadata or {} }
end
local function fixture()
    local map = { id = "test", version = 1, tile_size = 32, width = 64, height = 64, placements = {
        placement("ground_a", "grass", 1, 1, 7), placement("ground_b", "grass", 2, 1, 7),
        placement("ground_c", "grass", 3, 1, 7), placement("ground_d", "grass", 4, 1, 7),
        placement("ground_e", "grass", 5, 1, 7), placement("ground_z6", "basement_floor", 5, 1, 6),
        placement("wall", "wall", 2, 1, 7), placement("door", "wood_door", 3, 1, 7, { open = false }),
        placement("table", "table", 4, 1, 7), placement("wide", "wall_block", 10, 10, 7),
        placement("interior", "interior", 1, 1, 7, {}, { interior_group = "house" }),
        placement("roof", "roof", 1, 1, 8, {}, { roof_group = "house" }),
        placement("stairs", "stairs", 5, 1, 7, {}, { transition = { dz = -1 } }),
    } }
    return world_api.new(map, registry_api.new(definitions), state_api.new()), map
end

test("position equality and coordinate conversion", function()
    assert(position.equals(position.new(2, 3, 7), position.new(2, 3, 7)))
    local sx, sy = position.world_to_screen(position.new(4, 5, 7), position.new(2, 2, 7), 32)
    equal(sx, 64); equal(sy, 96); assert(position.equals(position.screen_to_world(sx, sy, position.new(2, 2, 7), 32, 7), position.new(4, 5, 7)))
end)

test("actor identity, types, directions, and registry are canonical", function()
    assert(actor_types.is_valid("player") and actor_types.is_valid("npc") and actor_types.is_valid("monster"))
    assert(not actor_types.is_valid("vendor"))
    local dx, dy = direction.offset("north"); equal(dx, 0); equal(dy, 1)
    equal(direction.from_delta(-1, 0), "west")
    local npc = actor_api.new("npc.test", "npc", 2, 3, 7, "east")
    equal(npc.position.x, 2); equal(npc.facing, "east"); assert(npc.active)
    local actor_snapshot = actor_api.snapshot(npc); actor_snapshot.position.x = 99; equal(npc.position.x, 2)
    assert(npc.visual_position == nil and npc.movement_target == nil)
    assert(not pcall(actor_api.new, "bad actor", "npc", 1, 1, 7))
    assert(not pcall(actor_api.new, "actor.bad", "vendor", 1, 1, 7))
    assert(not pcall(actor_api.new, "actor.float", "npc", 1.5, 1, 7))
    assert(not pcall(actor_api.new, "actor.facing", "npc", 1, 1, 7, "up"))
    local registry = actor_registry_api.new(); registry:add(npc)
    equal(registry:get("npc.test").id, "npc.test"); equal(registry:get_all()[1].id, "npc.test")
    assert(not pcall(function() registry:add(actor_api.new("npc.test", "npc", 1, 1, 7)) end))
    equal(registry:remove("npc.test").id, "npc.test"); assert(registry:get("npc.test") == nil)
end)

test("shared actors own occupancy, facing, movement runtime, and events", function()
    events.clear()
    local map = { id = "actor_test", version = 1, tile_size = 32, width = 4, height = 4, placements = {
        placement("actor.ground.1", "grass", 1, 1, 7), placement("actor.ground.2", "grass", 2, 1, 7),
        placement("actor.ground.3", "grass", 3, 1, 7),
    }, actor_placements = { { id = "npc.blocker", type = "npc", x = 2, y = 1, z = 7, facing = "west" } } }
    local world = world_api.new(map, registry_api.new(definitions), state_api.new())
    local player = actor_api.new("player.test", "player", 1, 1, 7, "north")
    local added, facing, moved, removed
    events.on("actor_added", function(payload) added = payload end)
    events.on("actor_facing_changed", function(payload) facing = payload end)
    events.on("actor_moved", function(payload) moved = payload end)
    events.on("actor_removed", function(payload) removed = payload end)
    world:place_actor(player, events)
    equal(added.actor_type, "player"); equal(world:get_actor_at(2, 1, 7).id, "npc.blocker")
    assert(not pcall(function() world:place_actor(actor_api.new("monster.blocked", "monster", 2, 1, 7)) end))
    assert(not world:is_walkable(2, 1, 7, player.id))
    assert(not movement.begin(world, player, 1, 0, events)); equal(player.facing, "east")
    equal(facing.actor_id, player.id); assert(not movement.is_moving(player))
    world:remove_actor("npc.blocker", events); equal(removed.actor_type, "npc")
    assert(movement.begin(world, player, 1, 0, events)); equal(player.position.x, 2)
    equal(moved.actor_type, "player"); equal(moved.from.x, 1); equal(moved.to.x, 2)
    equal(movement.visual_position(player).x, 1)
    movement.update(player, 1); equal(movement.visual_position(player).x, 2); assert(not movement.is_moving(player))
    equal(world:get_actor_at(2, 1, 7).id, player.id)
end)

local function path_world(width, height, walls, actor_placements, extra_objects, item_registry)
    local placements, sequence = {}, 0
    for y = 0, height - 1 do for x = 0, width - 1 do
        sequence = sequence + 1
        placements[#placements + 1] = placement("path.ground." .. sequence, "grass", x, y, 7)
    end end
    for index, wall in ipairs(walls or {}) do
        placements[#placements + 1] = placement("path.wall." .. index, wall.type or "wall", wall.x, wall.y, 7)
    end
    for _, object in ipairs(extra_objects or {}) do placements[#placements + 1] = object end
    local map = { id = "path_test", version = 1, tile_size = 32, width = width, height = height,
        placements = placements, actor_placements = actor_placements or {} }
    return world_api.new(map, registry_api.new(definitions), state_api.new(), item_registry)
end

test("A star finds deterministic cardinal paths without moving the actor", function()
    local world = path_world(5, 3)
    local actor = actor_api.new("path.actor", "npc", 0, 1, 7, "south"); world:place_actor(actor)
    local result = pathfinding.find_path(world, actor.id, position.new(4, 1, 7))
    assert(result.success); equal(result.cost, 4); equal(#result.path, 4); equal(actor.position.x, 0)
    equal(result.path[1].x, 1); equal(result.path[4].x, 4)
    local same = pathfinding.find_path(world, actor.id, position.new(0, 1, 7))
    assert(same.success); equal(same.cost, 0); equal(#same.path, 0)

    for _, step in ipairs(result.path) do
        local dx, dy = step.x - actor.position.x, step.y - actor.position.y
        assert(movement.begin(world, actor, dx, dy)); movement.update(actor, 1)
    end
    equal(actor.position.x, 4); assert(not movement.is_moving(actor))

    local equal_world = path_world(3, 3)
    local equal_actor = actor_api.new("path.equal", "npc", 0, 0, 7); equal_world:place_actor(equal_actor)
    local first = pathfinding.find_path(equal_world, equal_actor.id, position.new(2, 2, 7))
    local second = pathfinding.find_path(equal_world, equal_actor.id, position.new(2, 2, 7))
    equal(first.path[1].x, 0); equal(first.path[1].y, 1)
    equal(codec.serialize(first.path), codec.serialize(second.path))
end)

test("A star validates actors, goals, Z levels, and bounded searches", function()
    local world = path_world(5, 2)
    local actor = actor_api.new("path.validation", "player", 0, 0, 7); world:place_actor(actor)
    equal(pathfinding.find_path(world, "missing", position.new(1, 0, 7)).reason, "unknown_actor")
    equal(pathfinding.find_path(world, actor.id, { x = 1.5, y = 0, z = 7 }).reason, "invalid_goal")
    equal(pathfinding.find_path(world, actor.id, position.new(9, 0, 7)).reason, "invalid_goal")
    equal(pathfinding.find_path(world, actor.id, position.new(1, 0, 6)).reason, "invalid_goal")
    local other_z_map = { id = "path_z", version = 1, tile_size = 32, width = 2, height = 1, placements = {
        placement("path.z7", "grass", 0, 0, 7), placement("path.z6", "basement_floor", 1, 0, 6),
    } }
    local other_z_world = world_api.new(other_z_map, registry_api.new(definitions), state_api.new())
    local other_z_actor = actor_api.new("path.z", "npc", 0, 0, 7); other_z_world:place_actor(other_z_actor)
    equal(pathfinding.find_path(other_z_world, other_z_actor.id, position.new(1, 0, 6)).reason, "different_z")
    equal(pathfinding.find_path(world, actor.id, position.new(4, 0, 7), { max_nodes = 1 }).reason, "search_limit")
    actor.position = position.new(4, 1, 7)
    equal(pathfinding.find_path(world, actor.id, position.new(4, 0, 7)).reason, "invalid_start")
end)

test("A star routes around collision footprints and reports blocked routes", function()
    local world = path_world(5, 3, { { x = 2, y = 1 } })
    local actor = actor_api.new("path.detour", "npc", 0, 1, 7); world:place_actor(actor)
    local result = pathfinding.find_path(world, actor.id, position.new(4, 1, 7))
    assert(result.success); equal(result.cost, 6)
    for _, step in ipairs(result.path) do assert(not (step.x == 2 and step.y == 1)) end

    local blocked = path_world(5, 3, { { x = 4, y = 1 } })
    local blocked_actor = actor_api.new("path.blocked", "npc", 0, 1, 7); blocked:place_actor(blocked_actor)
    equal(pathfinding.find_path(blocked, blocked_actor.id, position.new(4, 1, 7)).reason, "blocked_goal")

    local barrier = path_world(5, 3, { { x = 2, y = 0 }, { x = 2, y = 1 }, { x = 2, y = 2 } })
    local trapped = actor_api.new("path.trapped", "npc", 0, 1, 7); barrier:place_actor(trapped)
    equal(pathfinding.find_path(barrier, trapped.id, position.new(4, 1, 7)).reason, "no_path")

    local graphical = path_world(3, 3, { { x = 1, y = 1, type = "wall_block" } })
    local graphical_actor = actor_api.new("path.graphical", "npc", 0, 1, 7); graphical:place_actor(graphical_actor)
    local around_graphics = pathfinding.find_path(graphical, graphical_actor.id, position.new(2, 1, 7))
    assert(around_graphics.success)
    local used_graphical_cell = false
    for _, step in ipairs(around_graphics.path) do
        if step.x == 1 and step.y == 2 then used_graphical_cell = true end
    end
    assert(used_graphical_cell, "graphical footprint must not become collision")
end)

test("A star respects doors, world items, and Actor occupancy policies", function()
    local door = placement("path.door", "wood_door", 1, 0, 7, { open = false })
    local door_world = path_world(3, 1, nil, nil, { door })
    local actor = actor_api.new("path.door.actor", "player", 0, 0, 7); door_world:place_actor(actor)
    equal(pathfinding.find_path(door_world, actor.id, position.new(2, 0, 7)).reason, "no_path")
    door_world:set_object_state("path.door", { open = true })
    assert(pathfinding.find_path(door_world, actor.id, position.new(2, 0, 7)).success)

    local occupied = path_world(5, 1, nil, { { id = "npc.goal", type = "npc", x = 4, y = 0, z = 7 } })
    local seeker = actor_api.new("path.seeker", "monster", 0, 0, 7); occupied:place_actor(seeker)
    equal(pathfinding.find_path(occupied, seeker.id, position.new(4, 0, 7)).reason, "blocked_goal")
    local allowed = pathfinding.find_path(occupied, seeker.id, position.new(4, 0, 7), { allow_occupied_goal = true })
    assert(allowed.success); equal(allowed.cost, 4)

    local corridor = path_world(5, 1, nil, { { id = "npc.middle", type = "npc", x = 2, y = 0, z = 7 } })
    local corridor_actor = actor_api.new("path.corridor", "player", 0, 0, 7); corridor:place_actor(corridor_actor)
    equal(pathfinding.find_path(corridor, corridor_actor.id, position.new(4, 0, 7)).reason, "no_path")

    local registry = item_registry_api.new(item_definitions)
    local item_world = path_world(3, 1, nil, nil, nil, registry)
    local item_actor = actor_api.new("path.item", "player", 0, 0, 7); item_world:place_actor(item_actor)
    world_items.place(item_world, item_instance.new({ id = "path.herb", type = "healing_herb" }, registry),
        position.new(1, 0, 7), "world.path.herb")
    assert(pathfinding.find_path(item_world, item_actor.id, position.new(2, 0, 7)).success)
end)

test("A star crosses chunks and stale paths remain movement-validated", function()
    local world = path_world(35, 1)
    local actor = actor_api.new("path.chunk", "npc", 31, 0, 7); world:place_actor(actor)
    local result = pathfinding.find_path(world, actor.id, position.new(33, 0, 7))
    assert(result.success); equal(result.cost, 2)
    local first_chunk_x = chunks.coordinates(result.path[1].x, result.path[1].y)
    equal(first_chunk_x, 1)

    local stale_world = path_world(4, 1)
    local stale_actor = actor_api.new("path.stale", "npc", 0, 0, 7); stale_world:place_actor(stale_actor)
    local stale = pathfinding.find_path(stale_world, stale_actor.id, position.new(3, 0, 7)); assert(stale.success)
    stale_world:place_actor(actor_api.new("path.new_blocker", "monster", stale.path[1].x, stale.path[1].y, 7))
    local dx, dy = stale.path[1].x - stale_actor.position.x, stale.path[1].y - stale_actor.position.y
    assert(not movement.begin(stale_world, stale_actor, dx, dy))
    equal(stale_actor.position.x, 0)
end)

test("tile retrieval, deterministic stack, removal", function()
    local world = fixture(); local tile = world:get_tile(1, 1, 7)
    equal(tile.objects[1].definition.stack_layer, "ground")
    assert(world:remove_object("interior")); equal(#world:get_objects(1, 1, 7), 1); assert(not world:remove_object("missing"))
end)

test("walkability cases and actor reservation", function()
    local world = fixture()
    assert(world:is_walkable(1, 1, 7)); assert(not world:is_walkable(2, 1, 7)); assert(not world:is_walkable(3, 1, 7))
    assert(not world:is_walkable(4, 1, 7)); world:set_object_state("door", { open = true }); assert(world:is_walkable(3, 1, 7))
    world:get_tile(1, 1, 7).actor_id = "npc"; assert(not world:is_walkable(1, 1, 7, "player"))
end)

test("graphical footprint is not collision footprint", function()
    local world = fixture()
    assert(not world:is_walkable(10, 10, 7))
    assert(world:get_tile(11, 10, 7) == nil and world:get_tile(10, 11, 7) == nil,
        "2x2 graphics must not expand a 1x1 collision footprint")
end)

test("movement validates and commits authoritative tile", function()
    local world = fixture(); local actor = actor_api.new("hero", "player", 1, 1, 7); world:place_actor(actor)
    assert(not movement.begin(world, actor, 1, 0)); assert(movement.begin(world, actor, 0, 0) == false)
    local other = fixture(); local walker = actor_api.new("walker", "player", 4, 1, 7); other:place_actor(walker)
    other:set_object_state("door", { open = true }); assert(movement.begin(other, walker, -1, 0)); equal(walker.position.x, 3)
end)

test("registered door interaction toggles state", function()
    actions.register_defaults()
    local world = fixture(); local actor = actor_api.new("hero", "player", 4, 1, 7); actor.facing = "west"; world:place_actor(actor)
    assert(interaction.use(world, actor)); assert(world:object_state("door").open)
    assert(interaction.use(world, actor)); assert(not world:object_state("door").open)
end)

test("explicit Z transition", function()
    local world = fixture(); local actor = actor_api.new("hero", "player", 5, 1, 7); world:place_actor(actor)
    local stairs = world.objects.stairs; assert(transitions.resolve(world, actor, stairs, stairs.metadata.transition))
    equal(actor.position.z, 6)
end)

test("world-state overrides and roof groups", function()
    local world = fixture(); world:set_object_state("door", { open = true }); assert(world:object_state("door").open)
    local actor = actor_api.new("hero", "player", 1, 1, 7); equal(roofs.interior_group(world, actor.position), "house")
    assert(roofs.revealed_groups(world, actor).house)
end)

test("save capture, serialization, deserialization and restore", function()
    local world, map = fixture(); local actor = actor_api.new("hero", "player", 5, 1, 6); actor.facing = "north"
    actor.inventory = inventory_api.create("inventory.hero", actor.id, 2, item_registry_api.new(item_definitions))
    actor.equipment = equipment_api.create("equipment.hero", actor.id, item_registry_api.new(item_definitions))
    world:set_object_state("door", { open = true }); local saved = save_data.capture(actor, world, map.id)
    local decoded = codec.deserialize(codec.serialize(saved)); assert(save_data.validate(decoded, map.id)); assert(decoded.objects.door.open)
    local restored = actor_api.new("hero", "player", 1, 1, 7); save_data.restore_player(restored, decoded)
    equal(restored.position.z, 6); equal(restored.facing, "north")
end)

test("chunk addressing", function()
    local x, y = chunks.coordinates(33, 63); equal(x, 1); equal(y, 1)
    local world = fixture(); assert(world:get_chunk(0, 0, 7)); assert(world:get_chunk(1, 0, 7) == nil)
end)

test("item definitions are validated and isolated from callers", function()
    local registry = item_registry_api.new(item_definitions)
    local herb = registry:get("healing_herb")
    assert(herb.stackable); equal(herb.max_stack, 20); equal(herb.weight, 0.1)
    herb.name = "Changed"; herb.tags[1] = "changed"
    equal(registry:get("healing_herb").name, "Healing Herb")
    equal(registry:get("healing_herb").tags[1], "consumable")
    assert(registry:has("old_iron_key")); assert(not registry:has("missing"))

    local ok = pcall(item_registry_api.new, { bad = { id = "bad", name = "Bad", stackable = true, max_stack = 1 } })
    assert(not ok, "invalid stack limits must be rejected")
end)

test("item instances own bounded quantity and mutable state", function()
    local registry = item_registry_api.new(item_definitions)
    local source_state = { quality = "fresh", provenance = { area = "marsh" } }
    local herb = item_instance.new({ id = "loot.herb.1", type = "healing_herb", quantity = 3, state = source_state }, registry)
    source_state.provenance.area = "changed"
    equal(herb.state.provenance.area, "marsh")
    equal(item_instance.remaining_capacity(herb, registry), 17)
    item_instance.set_quantity(herb, 20, registry); equal(herb.quantity, 20)

    assert(not pcall(item_instance.set_quantity, herb, 21, registry))
    assert(not pcall(item_instance.new, { id = "key.1", type = "old_iron_key", quantity = 2 }, registry))
    assert(not pcall(item_instance.new, { id = "unknown.1", type = "missing" }, registry))
end)

local function item_fixture(id, item_type, quantity, state)
    return item_instance.new({ id = id, type = item_type, quantity = quantity, state = state }, item_registry_api.new(item_definitions))
end

test("containers report slot capacity and isolate non-stackable items", function()
    local registry = item_registry_api.new(item_definitions)
    local container = container_api.create("chest.1", 1)
    equal(container.id, "chest.1"); equal(container.capacity, 1)
    assert(not pcall(function() container.capacity = 2 end))
    equal(container_api.get_count(container), 0); equal(container_api.get_remaining_capacity(container), 1)
    assert(not container_api.is_full(container)); equal(#container_api.get_items(container, registry), 0)

    local key = item_fixture("key.1", "old_iron_key")
    local added = container_api.add_item(container, key, registry)
    equal(added.inserted_quantity, 1); assert(added.remainder == nil); assert(container_api.is_full(container))
    key.state.owner = "caller"; key.quantity = 99
    local stored = container_api.get_item(container, "key.1", registry)
    equal(stored.quantity, 1); assert(stored.state.owner == nil)
    stored.state.owner = "getter"
    assert(container_api.get_item(container, "key.1", registry).state.owner == nil)
    local snapshot = container_api.get_items(container, registry)
    snapshot[1].state.owner = "snapshot"; snapshot[2] = item_fixture("key.fake", "old_iron_key")
    equal(container_api.get_count(container), 1)
    assert(container_api.get_item(container, "key.1", registry).state.owner == nil)

    local rejected = container_api.add_item(container, item_fixture("key.2", "old_iron_key"), registry)
    equal(rejected.inserted_quantity, 0); equal(rejected.remainder.id, "key.2")
    equal(container_api.get_count(container), 1)
    local removed = container_api.remove_item(container, "key.1", registry)
    equal(removed.id, "key.1"); equal(container_api.get_count(container), 0)
    assert(container_api.get_item(container, "key.1", registry) == nil)
end)

test("containers merge compatible stacks with deterministic identity", function()
    local registry = item_registry_api.new(item_definitions)
    local container = container_api.create("crate.1", 2)
    container_api.add_item(container, item_fixture("herb.existing", "healing_herb", 5, { quality = "fresh" }), registry)
    local merged = container_api.add_item(container, item_fixture("herb.incoming", "healing_herb", 4, { quality = "fresh" }), registry)
    equal(merged.inserted_quantity, 4); assert(merged.remainder == nil)
    equal(container_api.get_count(container), 1)
    equal(container_api.get_item(container, "herb.existing", registry).quantity, 9)
    assert(container_api.get_item(container, "herb.incoming", registry) == nil)

    local exact = container_api.add_item(container, item_fixture("herb.exact", "healing_herb", 11, { quality = "fresh" }), registry)
    equal(exact.inserted_quantity, 11); equal(container_api.get_item(container, "herb.existing", registry).quantity, 20)
    assert(container_api.get_item(container, "herb.exact", registry) == nil)
end)

test("container stack overflow uses a new slot without losing identity", function()
    local registry = item_registry_api.new(item_definitions)
    local container = container_api.create("crate.overflow", 2)
    container_api.add_item(container, item_fixture("herb.old", "healing_herb", 15), registry)
    local result = container_api.add_item(container, item_fixture("herb.new", "healing_herb", 10), registry)
    equal(result.inserted_quantity, 10); assert(result.remainder == nil)
    equal(container_api.get_item(container, "herb.old", registry).quantity, 20)
    equal(container_api.get_item(container, "herb.new", registry).quantity, 5)
    equal(container_api.get_count(container), 2)
end)

test("container returns stack overflow when no slot remains", function()
    local registry = item_registry_api.new(item_definitions)
    local container = container_api.create("crate.full", 1)
    container_api.add_item(container, item_fixture("herb.old.full", "healing_herb", 15), registry)
    local incoming = item_fixture("herb.leftover", "healing_herb", 10)
    local result = container_api.add_item(container, incoming, registry)
    equal(result.inserted_quantity, 5); equal(result.remainder.quantity, 5); equal(result.remainder.id, "herb.leftover")
    equal(incoming.quantity, 10); equal(container_api.get_item(container, "herb.old.full", registry).quantity, 20)
    assert(not pcall(container_api.add_item, container, { id = "invalid", type = "missing", quantity = 1 }, registry))
    assert(not pcall(container_api.add_item, container, item_fixture("herb.old.full", "healing_herb", 1), registry))
end)

test("inventory owns and delegates to one generic container", function()
    local registry = item_registry_api.new(item_definitions)
    local inventory = inventory_api.create("inventory.hero", "player", 2, registry)
    equal(inventory.id, "inventory.hero"); equal(inventory.owner_id, "player")
    assert(not pcall(function() inventory.owner_id = "other" end))
    local container = inventory_api.get_container(inventory)
    equal(container.id, "inventory.hero.items"); equal(container.capacity, 2)
    equal(inventory_api.get_count(inventory), 0); equal(inventory_api.get_remaining_capacity(inventory), 2)
    assert(not inventory_api.is_full(inventory)); assert(not inventory_api.has_item_type(inventory, "healing_herb"))

    local herb = item_fixture("inventory.herb", "healing_herb", 7, { quality = "fresh" })
    local result = inventory_api.add_item(inventory, herb)
    equal(result.inserted_quantity, 7); assert(result.remainder == nil)
    equal(inventory_api.get_quantity(inventory, "healing_herb"), 7)
    assert(inventory_api.has_item_type(inventory, "healing_herb"))
    local key_result = inventory_api.add_item(inventory, item_fixture("inventory.key", "old_iron_key"))
    equal(key_result.inserted_quantity, 1); assert(inventory_api.is_full(inventory))

    local found = inventory_api.get_item(inventory, "inventory.herb")
    equal(found.quantity, 7); found.state.quality = "spoiled"
    equal(inventory_api.get_item(inventory, "inventory.herb").state.quality, "fresh")
    local snapshot = inventory_api.get_items(inventory)
    snapshot[1].quantity = 1; snapshot[3] = item_fixture("inventory.fake", "old_iron_key")
    equal(inventory_api.get_count(inventory), 2); equal(inventory_api.get_quantity(inventory, "healing_herb"), 7)

    local removed = inventory_api.remove_item(inventory, "inventory.key")
    equal(removed.id, "inventory.key"); equal(inventory_api.get_count(inventory), 1)
    assert(inventory_api.get_item(inventory, "inventory.key") == nil)
end)

test("inventory preserves partial insertion and validation contracts", function()
    local registry = item_registry_api.new(item_definitions)
    local inventory = inventory_api.create("inventory.full", "player", 1, registry)
    inventory_api.add_item(inventory, item_fixture("inventory.stack", "healing_herb", 15))
    local incoming = item_fixture("inventory.overflow", "healing_herb", 10)
    local result = inventory_api.add_item(inventory, incoming)
    equal(result.inserted_quantity, 5); equal(result.remainder.id, "inventory.overflow"); equal(result.remainder.quantity, 5)
    equal(incoming.quantity, 10); equal(inventory_api.get_quantity(inventory, "healing_herb"), 20)
    assert(not pcall(inventory_api.get_quantity, inventory, "missing"))
    assert(not pcall(inventory_api.create, "bad inventory", "player", 1, registry))
    assert(not pcall(inventory_api.create, "inventory.bad", "", 1, registry))
end)

test("equipment slots and item policies are data-driven", function()
    equal(#equipment_slots.get_definitions(), 8)
    local registry = item_registry_api.new(item_definitions)
    local equipment = equipment_api.create("equipment.hero", "hero", registry)
    local sword = item_instance.new({ id = "gear.sword", type = "worn_iron_sword", state = { maker = "Mara" } }, registry)
    assert(equipment_api.is_slot_empty(equipment, "main_hand"))
    local allowed = equipment_api.can_equip(equipment, sword, "main_hand"); assert(allowed)
    local denied, reason = equipment_api.can_equip(equipment, sword, "head")
    assert(not denied); equal(reason, "slot_not_allowed")
    local key = item_instance.new({ id = "gear.not_equipment", type = "old_iron_key" }, registry)
    local not_equipment, item_reason = equipment_api.can_equip(equipment, key, "ring")
    assert(not not_equipment); equal(item_reason, "slot_not_allowed")
    local unknown, unknown_reason = equipment_api.can_equip(equipment, sword, "unknown")
    assert(not unknown); equal(unknown_reason, "unknown_slot")
    assert(not pcall(equipment_api.get, equipment, "unknown"))
    assert(not pcall(item_registry_api.new, { bad = { id = "bad", name = "Bad",
        equipment = { slots = { "unknown" } } } }))
    assert(not pcall(item_registry_api.new, { bad = { id = "bad", name = "Bad", stackable = true,
        equipment = { slots = { "ring" } } } }))
    local other_inventory = inventory_api.create("inventory.other", "other", 1, registry)
    inventory_api.add_item(other_inventory, sword)
    local owner_ok, owner_reason = equipment_api.equip(equipment, other_inventory, sword.id, "main_hand")
    assert(not owner_ok); equal(owner_reason, "owner_mismatch")
end)

test("equip and unequip preserve exclusive identity and events", function()
    events.clear()
    local registry = item_registry_api.new(item_definitions)
    local inventory = inventory_api.create("inventory.gear", "hero", 2, registry)
    local equipment = equipment_api.create("equipment.hero", "hero", registry)
    inventory_api.add_item(inventory, item_instance.new({ id = "gear.sword.1", type = "worn_iron_sword",
        state = { maker = "Mara" } }, registry))
    local equipped_event, unequipped_event
    events.on("item_equipped", function(payload) equipped_event = payload end)
    events.on("item_unequipped", function(payload) unequipped_event = payload end)
    local equipped, item = equipment_api.equip(equipment, inventory, "gear.sword.1", "main_hand", events)
    assert(equipped); equal(item.id, "gear.sword.1"); assert(inventory_api.get_item(inventory, item.id) == nil)
    equal(equipment_api.get(equipment, "main_hand").id, "gear.sword.1")
    equal(equipped_event.owner_id, "hero"); equal(equipped_event.slot, "main_hand")
    local snapshot = equipment_api.get_items(equipment); snapshot.main_hand.state.maker = "changed"
    equal(equipment_api.get(equipment, "main_hand").state.maker, "Mara")

    inventory_api.add_item(inventory, item_instance.new({ id = "gear.sword.2", type = "worn_iron_sword" }, registry))
    local replaced, occupied_reason = equipment_api.equip(equipment, inventory, "gear.sword.2", "main_hand")
    assert(not replaced); equal(occupied_reason, "slot_occupied")
    equal(equipment_api.get(equipment, "main_hand").id, "gear.sword.1")
    assert(inventory_api.get_item(inventory, "gear.sword.2"))

    local unequipped, returned = equipment_api.unequip(equipment, inventory, "main_hand", events)
    assert(unequipped); equal(returned.id, "gear.sword.1"); assert(equipment_api.is_slot_empty(equipment, "main_hand"))
    equal(inventory_api.get_item(inventory, "gear.sword.1").id, "gear.sword.1")
    equal(unequipped_event.item_id, "gear.sword.1")
end)

test("unequip fails atomically when inventory is full", function()
    local registry = item_registry_api.new(item_definitions)
    local inventory = inventory_api.create("inventory.full.gear", "hero", 1, registry)
    local equipment = equipment_api.create("equipment.full.gear", "hero", registry)
    inventory_api.add_item(inventory, item_instance.new({ id = "gear.cap", type = "leather_cap" }, registry))
    assert(equipment_api.equip(equipment, inventory, "gear.cap", "head"))
    inventory_api.add_item(inventory, item_instance.new({ id = "gear.key", type = "old_iron_key" }, registry))
    local changed, reason = equipment_api.unequip(equipment, inventory, "head")
    assert(not changed); equal(reason, "inventory_full")
    equal(equipment_api.get(equipment, "head").id, "gear.cap")
    assert(inventory_api.get_item(inventory, "gear.cap") == nil)
end)

local function world_item_fixture(capacity)
    local map = { id = "item_test", version = 1, tile_size = 32, width = 4, height = 4, placements = {
        placement("ground.1", "grass", 1, 1, 7), placement("ground.2", "grass", 2, 1, 7),
        placement("ground.3", "grass", 1, 2, 7),
    } }
    local item_defs = {
        healing_herb = item_definitions.healing_herb,
        old_iron_key = item_definitions.old_iron_key,
        sealed_stone = { id = "sealed_stone", name = "Sealed Stone", pickupable = false,
            stack_layer = "bottom", interaction = "pickup", patterns = { { { .3, .3, .35, 1 } } } },
    }
    local item_registry = item_registry_api.new(item_defs)
    local world = world_api.new(map, registry_api.new(definitions), state_api.new(), item_registry)
    local inventory = inventory_api.create("inventory.item_test", "hero", capacity or 4, item_registry)
    return world, inventory, item_registry
end

test("world items place, render, retrieve, and remove stable instances", function()
    local world, _, registry = world_item_fixture()
    local herb = item_instance.new({ id = "item.world.herb", type = "healing_herb", quantity = 5 }, registry)
    local placed = world_items.place(world, herb, position.new(1, 1, 7), "world.herb")
    equal(placed.item.id, "item.world.herb"); equal(world_items.get(world, "world.herb").item.quantity, 5)
    local stack = world:get_objects(1, 1, 7)
    equal(stack[1].definition.stack_layer, "ground"); equal(stack[2].instance.id, "world.herb")
    local actor = actor_api.new("viewer", "player", 2, 1, 7)
    local commands = renderer.build(world, actor, 0)
    local rendered = false
    for _, command in ipairs(commands) do if command.id == "world.herb:1" then rendered = true end end
    assert(rendered, "world item must render from world state")
    local removed = world_items.remove(world, "world.herb")
    equal(removed.item.id, "item.world.herb"); assert(world_items.get(world, "world.herb") == nil)
    equal(#world:get_objects(1, 1, 7), 1)
end)

test("engine test map loads its stable herb and key placements", function()
    local map = map_loader.load("data.maps.prototype")
    local registry = item_registry_api.new(item_definitions)
    local world = world_api.new(map, registry_api.new(definitions), state_api.new(), registry)
    equal(world_items.get(world, "world.test.herbs.01").item.id, "test.herbs.01")
    equal(world_items.get(world, "world.test.key.01").item.id, "test.key.01")
    equal(world:get_actor_at(12, 5, 7).id, "npc_test_villager")
    local viewer = actor_api.new("player.viewer", "player", 9, 2, 7); world:place_actor(viewer)
    local commands = renderer.build(world, viewer, 0)
    local npc_rendered = false
    for _, command in ipairs(commands) do if command.id == "npc_test_villager:actor" then npc_rendered = true end end
    assert(npc_rendered, "static NPC must render from actor state")
end)

test("pickup transfers a non-stackable item through interaction", function()
    events.clear(); actions.register_defaults()
    local world, inventory, registry = world_item_fixture(1)
    local key = item_instance.new({ id = "item.world.key", type = "old_iron_key" }, registry)
    world_items.place(world, key, position.new(1, 1, 7), "world.key")
    local actor = actor_api.new("hero", "player", 2, 1, 7); actor.facing = "west"; actor.inventory = inventory
    world:place_actor(actor)
    local picked, removed
    events.on("item_picked_up", function(payload) picked = payload end)
    events.on("world_item_removed", function(payload) removed = payload end)
    local changed = interaction.use(world, actor, events)
    assert(changed); assert(world_items.get(world, "world.key") == nil)
    equal(inventory_api.get_item(inventory, "item.world.key").id, "item.world.key")
    equal(picked.actor_id, "hero"); equal(picked.item_id, "item.world.key"); equal(picked.x, 1)
    equal(removed.world_item_id, "world.key"); equal(removed.quantity, 1)
    local dropped = item_transfers.drop(world, inventory, "item.world.key", position.new(1, 2, 7), actor.id)
    equal(dropped.item.id, "item.world.key"); assert(inventory_api.get_item(inventory, "item.world.key") == nil)
    equal(world_items.get(world, dropped.id).item.id, "item.world.key")
end)

test("failed non-stackable pickup leaves world ownership unchanged", function()
    local world, inventory, registry = world_item_fixture(1)
    inventory_api.add_item(inventory, item_instance.new({ id = "item.held.key", type = "old_iron_key" }, registry))
    world_items.place(world, item_instance.new({ id = "item.waiting.key", type = "old_iron_key" }, registry),
        position.new(1, 1, 7), "world.waiting.key")
    local result, reason = item_transfers.pickup(world, inventory, "world.waiting.key", "hero")
    equal(result.inserted_quantity, 0); equal(reason, "inventory_full")
    equal(world_items.get(world, "world.waiting.key").item.id, "item.waiting.key")
    assert(inventory_api.get_item(inventory, "item.waiting.key") == nil)
end)

test("stack pickup preserves remainder in world without duplicate ownership", function()
    local world, inventory, registry = world_item_fixture(1)
    inventory_api.add_item(inventory, item_instance.new({ id = "item.herb.held", type = "healing_herb", quantity = 15 }, registry))
    world_items.place(world, item_instance.new({ id = "item.herb.world", type = "healing_herb", quantity = 10 }, registry),
        position.new(1, 1, 7), "world.herb.partial")
    local result = item_transfers.pickup(world, inventory, "world.herb.partial", "hero")
    equal(result.inserted_quantity, 5); equal(result.remainder.quantity, 5)
    equal(inventory_api.get_quantity(inventory, "healing_herb"), 20)
    equal(world_items.get(world, "world.herb.partial").item.quantity, 5)
    assert(inventory_api.get_item(inventory, "item.herb.world") == nil)

    local empty_inventory = inventory_api.create("inventory.empty", "hero", 1, registry)
    local empty_world = world_item_fixture(1)
    world_items.place(empty_world, item_instance.new({ id = "item.herb.whole", type = "healing_herb", quantity = 10 }, registry),
        position.new(1, 1, 7), "world.herb.whole")
    local whole = item_transfers.pickup(empty_world, empty_inventory, "world.herb.whole", "hero")
    equal(whole.inserted_quantity, 10); assert(world_items.get(empty_world, "world.herb.whole") == nil)
    equal(inventory_api.get_item(empty_inventory, "item.herb.whole").id, "item.herb.whole")
end)

test("whole-item drop preserves identity and emits transfer events", function()
    events.clear()
    local world, inventory, registry = world_item_fixture(2)
    inventory_api.add_item(inventory, item_instance.new({ id = "item.roundtrip", type = "old_iron_key" }, registry))
    local added, dropped
    events.on("world_item_added", function(payload) added = payload end)
    events.on("item_dropped", function(payload) dropped = payload end)
    local placed = item_transfers.drop(world, inventory, "item.roundtrip", position.new(2, 1, 7), "hero", events)
    equal(placed.item.id, "item.roundtrip"); assert(inventory_api.get_item(inventory, "item.roundtrip") == nil)
    equal(world_items.get(world, placed.id).item.id, "item.roundtrip")
    equal(added.item_id, "item.roundtrip"); equal(dropped.actor_id, "hero"); equal(dropped.z, 7)
end)

test("world item placement and pickup reject invalid content", function()
    local world, inventory, registry = world_item_fixture()
    local herb = item_instance.new({ id = "item.invalid.place", type = "healing_herb" }, registry)
    assert(not pcall(world_items.place, world, herb, position.new(1, 1, 99), "world.invalid"))
    local stone = item_instance.new({ id = "item.sealed", type = "sealed_stone" }, registry)
    world_items.place(world, stone, position.new(1, 1, 7), "world.sealed")
    local result, reason = item_transfers.pickup(world, inventory, "world.sealed", "hero")
    equal(result.inserted_quantity, 0); equal(reason, "not_pickupable")
    assert(world_items.get(world, "world.sealed")); assert(not inventory_api.has_item_type(inventory, "sealed_stone"))
end)

test("save v3 serializes empty and populated ownership snapshots safely", function()
    local world, empty_inventory, registry = world_item_fixture(3)
    local actor = actor_api.new("hero", "player", 1, 1, 7); actor.inventory = empty_inventory
    actor.equipment = equipment_api.create("equipment.hero", actor.id, registry)
    local empty = save_data.capture(actor, world, world.map.id)
    equal(empty.version, 3); equal(#empty.inventory.items, 0); assert(next(empty.equipment.slots) == nil)
    local old = state_api.copy(empty); old.version = 2
    local old_valid, old_reason = save_data.validate(old, world.map)
    assert(not old_valid); equal(old_reason, "unsupported_save_version")

    inventory_api.add_item(actor.inventory, item_instance.new({ id = "save.herb", type = "healing_herb",
        quantity = 8, state = { quality = "dried" } }, registry))
    inventory_api.add_item(actor.inventory, item_instance.new({ id = "save.key", type = "old_iron_key",
        state = { lock = "cellar" } }, registry))
    local decoded = codec.deserialize(codec.serialize(save_data.capture(actor, world, world.map.id)))
    local valid, reason = save_data.validate(decoded, world.map)
    assert(valid, reason); equal(decoded.inventory.items[1].id, "save.herb")
    equal(decoded.inventory.items[1].quantity, 8); equal(decoded.inventory.items[1].state.quality, "dried")
    equal(decoded.inventory.items[2].id, "save.key"); equal(decoded.inventory.items[2].state.lock, "cellar")
    decoded.inventory.items[1].state.quality = "changed"
    equal(inventory_api.get_item(actor.inventory, "save.herb").state.quality, "dried")
    local restored = save_data.restore_inventory(codec.deserialize(codec.serialize(save_data.capture(actor, world, world.map.id))), registry)
    equal(inventory_api.get_item(restored, "save.herb").id, "save.herb")
    equal(inventory_api.get_item(restored, "save.key").id, "save.key")
end)

test("save v3 restores exclusive inventory, equipment, and world ownership", function()
    events.clear()
    local map = map_loader.load("data.maps.prototype")
    local registry = item_registry_api.new(item_definitions)
    local world = world_api.new(map, registry_api.new(definitions), state_api.new(), registry)
    local actor = actor_api.new("player", "player", 9, 2, 7)
    actor.inventory = inventory_api.restore(map.player_inventory, registry)
    actor.equipment = equipment_api.restore(map.player_equipment, registry)

    local key_pickup = item_transfers.pickup(world, actor.inventory, "world.test.key.01", actor.id)
    equal(key_pickup.inserted_quantity, 1)
    local herb_pickup = item_transfers.pickup(world, actor.inventory, "world.test.herbs.01", actor.id)
    equal(herb_pickup.inserted_quantity, 5); equal(herb_pickup.remainder.quantity, 5)
    local dropped = item_transfers.drop(world, actor.inventory, "test.starter.000001", position.new(9, 3, 7), actor.id)
    inventory_api.add_item(actor.inventory, item_instance.new({ id = "gear.saved.000001", type = "worn_iron_sword",
        state = { maker = "Mara" } }, registry))
    assert(equipment_api.equip(actor.equipment, actor.inventory, "gear.saved.000001", "main_hand"))
    world:set_object_state("greyhaven.house01.front_door", { open = true })
    actor.position = position.new(5, 5, 6); actor.facing = "north"

    local saved = codec.deserialize(codec.serialize(save_data.capture(actor, world, map.id)))
    local valid, reason = save_data.validate(saved, map); assert(valid, reason)
    assert(saved.world_items.static_overrides["world.test.key.01"].removed)
    equal(saved.world_items.static_overrides["world.test.herbs.01"].quantity, 5)
    equal(saved.world_items.dynamic[1].id, dropped.id); equal(saved.world_items.dynamic[1].x, 9)

    local restored_world = world_api.new(map, registry_api.new(definitions), state_api.new(saved), registry)
    local gameplay_events = 0
    events.on("item_picked_up", function() gameplay_events = gameplay_events + 1 end)
    events.on("item_dropped", function() gameplay_events = gameplay_events + 1 end)
    events.on("item_equipped", function() gameplay_events = gameplay_events + 1 end)
    events.on("item_unequipped", function() gameplay_events = gameplay_events + 1 end)
    save_data.apply_static_item_overrides(restored_world, saved)
    local restored_inventory = save_data.restore_inventory(saved, registry)
    local restored_equipment = save_data.restore_equipment(saved, registry)
    save_data.restore_dynamic_world_items(restored_world, saved)
    local restored_actor = actor_api.new("player", "player", 9, 2, 7)
    restored_actor.inventory, restored_actor.equipment = restored_inventory, restored_equipment
    save_data.restore_player(restored_actor, saved)

    equal(gameplay_events, 0); equal(restored_actor.position.z, 6); equal(restored_actor.facing, "north")
    assert(restored_world:object_state("greyhaven.house01.front_door").open)
    equal(inventory_api.get_item(restored_inventory, "test.key.01").id, "test.key.01")
    assert(world_items.get(restored_world, "world.test.key.01") == nil)
    equal(world_items.get(restored_world, "world.test.herbs.01").item.quantity, 5)
    local restored_drop = world_items.get(restored_world, dropped.id)
    equal(restored_drop.item.id, "test.starter.000001"); equal(restored_drop.item.state.quality, "fresh")
    equal(restored_drop.position.x, 9); equal(restored_drop.position.y, 3); equal(restored_drop.position.z, 7)
    assert(inventory_api.get_item(restored_inventory, "test.starter.000001") == nil)
    local restored_sword = equipment_api.get(restored_equipment, "main_hand")
    equal(restored_sword.id, "gear.saved.000001"); equal(restored_sword.state.maker, "Mara")
    assert(inventory_api.get_item(restored_inventory, "gear.saved.000001") == nil)

    local allocator = save_data.create_item_id_allocator(saved, map)
    equal(allocator:next("test.starter"), "test.starter.000002")
    equal(allocator:next("gear.saved"), "gear.saved.000002")
end)

test("save validation rejects duplicate item ownership", function()
    local map = map_loader.load("data.maps.prototype")
    local registry = item_registry_api.new(item_definitions)
    local world = world_api.new(map, registry_api.new(definitions), state_api.new(), registry)
    local actor = actor_api.new("player", "player", 9, 2, 7); actor.inventory = inventory_api.restore(map.player_inventory, registry)
    actor.equipment = equipment_api.restore(map.player_equipment, registry)
    local saved = save_data.capture(actor, world, map.id)
    saved.equipment.slots.main_hand = state_api.copy(saved.inventory.items[1])
    local valid, reason = save_data.validate(saved, map)
    assert(not valid); equal(reason, "duplicate_item_ownership")
end)

test("fresh session after reset uses authored item state", function()
    local map = map_loader.load("data.maps.prototype")
    local registry = item_registry_api.new(item_definitions)
    local fresh_world = world_api.new(map, registry_api.new(definitions), state_api.new(), registry)
    local fresh_inventory = inventory_api.restore(map.player_inventory, registry)
    local fresh_equipment = equipment_api.restore(map.player_equipment, registry)
    equal(world_items.get(fresh_world, "world.test.herbs.01").item.quantity, 10)
    equal(world_items.get(fresh_world, "world.test.key.01").item.id, "test.key.01")
    equal(inventory_api.get_item(fresh_inventory, "test.starter.000001").quantity, 15)
    assert(equipment_api.is_slot_empty(fresh_equipment, "main_hand"))
end)

print(string.format("%d Greyhaven Lua tests passed", count))
