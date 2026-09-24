package.path = "./?.lua;./?/init.lua;" .. package.path

local position = require "world.position"
local chunks = require "world.chunks"
local registry_api = require "world.object_registry"
local world_api = require "world.world"
local state_api = require "state.world_state"
local actor_api = require "actors.actor"
local movement = require "simulation.movement"
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
    world:get_tile(1, 1, 7).actor_id = nil; actor.tile_position = position.new(3, 1, 7); actor.visual_position = position.copy(actor.tile_position); world:place_actor(actor)
    world:set_object_state("door", { open = true }); assert(movement.begin(world, actor, -1, 0) == false, "wall remains blocking")
    local other = fixture(); local walker = actor_api.new("walker", "player", 4, 1, 7); other:place_actor(walker)
    other:set_object_state("door", { open = true }); assert(movement.begin(other, walker, -1, 0)); equal(walker.tile_position.x, 3)
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
    equal(actor.tile_position.z, 6)
end)

test("world-state overrides and roof groups", function()
    local world = fixture(); world:set_object_state("door", { open = true }); assert(world:object_state("door").open)
    local actor = actor_api.new("hero", "player", 1, 1, 7); equal(roofs.interior_group(world, actor.tile_position), "house")
    assert(roofs.revealed_groups(world, actor).house)
end)

test("save capture, serialization, deserialization and restore", function()
    local world, map = fixture(); local actor = actor_api.new("hero", "player", 5, 1, 6); actor.facing = "north"
    world:set_object_state("door", { open = true }); local saved = save_data.capture(actor, world.state, map.id)
    local decoded = codec.deserialize(codec.serialize(saved)); assert(save_data.validate(decoded, map.id)); assert(decoded.objects.door.open)
    local restored = actor_api.new("hero", "player", 1, 1, 7); save_data.restore_player(restored, decoded)
    equal(restored.tile_position.z, 6); equal(restored.facing, "north")
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

print(string.format("%d Greyhaven Lua tests passed", count))
