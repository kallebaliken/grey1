package.path = "./?.lua;./?/init.lua;" .. package.path

local position = require "world.position"
local chunks = require "world.chunks"
local registry_api = require "world.object_registry"
local world_api = require "world.world"
local object_instance = require "world.object_instance"
local map_loader = require "world.map_loader"
local state_api = require "state.world_state"
local actor_api = require "actors.actor"
local actor_types = require "actors.actor_types"
local actor_registry_api = require "actors.registry"
local direction = require "world.direction"
local movement = require "simulation.movement"
local movement_controller = require "simulation.movement_controller"
local health = require "combat.health"
local combat_registry = require "combat.registry"
local attacks = require "combat.attacks"
local armor = require "combat.armor"
local creature_definitions = require "creatures.creature_defs"
local creature_registry_api = require "creatures.creature_registry"
local creatures = require "creatures.creatures"
local perception = require "simulation.perception"
local line_of_sight = require "world.line_of_sight"
local faction_definitions = require "factions.faction_defs"
local relationship_definitions = require "factions.relationship_defs"
local faction_registry_api = require "factions.faction_registry"
local faction_relationships = require "factions.relationships"
local factions = require "factions.factions"
local dialogue_definitions = require "dialogue.dialogue_defs"
local dialogue_registry_api = require "dialogue.dialogue_registry"
local dialogue = require "dialogue.dialogue"
local conditions = require "conditions.conditions"
local world_actions = require "actions.world_actions"
local quest_definitions = require "quests.quest_defs"
local quest_registry_api = require "quests.quest_registry"
local quest_statuses = require "quests.quest_statuses"
local quests = require "quests.quests"
local binding_definitions = require "event_bindings.binding_defs"
local binding_registry_api = require "event_bindings.binding_registry"
local event_bindings = require "event_bindings.event_bindings"
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
local equipment_panel = require "ui.equipment_panel"
local world_items = require "world.world_items"
local item_transfers = require "simulation.item_transfers"
local renderer = require "render.world_renderer"
local render_order = require "render.render_order"
local render_definition = require "render.render_definition"
local sprite_reconciler = require "render.sprite_reconciler"
local command_diagnostics = require "render.command_diagnostics"
local viewport_api = require "render.viewport"
local camera_api = require "world.camera"
local layout = require "render.layout"
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

test("semantic render layers retain ground-to-roof order", function()
    local layers = { "ground", "ground_detail", "bottom", "actor", "top", "effect", "roof" }
    for index = 2, #layers do
        assert(render_order.value(layers[index - 1]) <= render_order.value(layers[index]))
    end
    equal(render_order.value("actor"), render_order.value("top"))
    assert(render_order.tie("actor") < render_order.tie("top"))
end)

test("sprite render definitions normalize shorthand, pieces, variants, and fallback", function()
    local single = render_definition.normalize({ animation = "grass_01" })
    equal(#single.pieces, 1); equal(single.pieces[1].animation, "grass_01")
    equal(single.pieces[1].offset_x, 0); equal(single.pieces[1].offset_y, 0)
    local multiple = render_definition.normalize({ pieces = {
        { animation = "wall_01", offset_x = 0, offset_y = 0 },
        { animation = "wall_01", offset_x = 32, offset_y = 64 },
    } })
    equal(#multiple.pieces, 2); equal(multiple.pieces[2].offset_x, 32)
    equal(multiple.pieces[2].offset_y, 64)
    equal(render_definition.resolve(nil)[1].animation, "fallback_01")
    equal(render_definition.resolve({ animation = "missing_art" })[1].animation, "fallback_01")
    equal(render_definition.resolve({ variants = { "grass_01", "dirt_01" } }, nil, 2)[1].animation,
        "dirt_01")
    equal(definitions.wall_block.footprint_width, 1)
    equal(#render_definition.resolve(definitions.wall_block.render), 4)
    assert(not pcall(render_definition.normalize, { animation = "grass_01", pieces = { {} } }))
end)

test("sprite reconciliation reuses stable pieces and removes only stale identities", function()
    local created, updated, removed, next_handle = {}, {}, {}, 0
    local reconciler = sprite_reconciler.new({
        create = function(command)
            next_handle = next_handle + 1
            local handle = "handle." .. next_handle
            created[#created + 1] = { id = command.id, handle = handle }
            return handle
        end,
        update = function(handle, command, _, _, animation_changed)
            updated[#updated + 1] = { handle = handle, id = command.id, changed = animation_changed }
        end,
        remove = function(handle) removed[#removed + 1] = handle end,
    })
    local frame = {
        { id = "ground:1", animation = "grass_01" },
        { id = "wall:1", animation = "wall_01" },
        { id = "wall:2", animation = "wall_01" },
    }
    local first = sprite_reconciler.synchronize(reconciler, frame)
    equal(first.active, 3); equal(first.created, 3); equal(first.reused, 0); equal(#updated, 3)
    local handles = { reconciler.instances["ground:1"].handle, reconciler.instances["wall:1"].handle,
        reconciler.instances["wall:2"].handle }
    local second = sprite_reconciler.synchronize(reconciler, frame)
    equal(second.active, 3); equal(second.created, 0); equal(second.reused, 3); equal(#created, 3)
    equal(reconciler.instances["ground:1"].handle, handles[1])
    equal(reconciler.instances["wall:1"].handle, handles[2])
    equal(reconciler.instances["wall:2"].handle, handles[3])
    assert(not updated[#updated].changed)

    local changed = {
        { id = "wall:1", animation = "wall_01" }, { id = "wall:2", animation = "wall_01" },
        { id = "roof:1", animation = "roof_01" },
    }
    local third = sprite_reconciler.synchronize(reconciler, changed)
    equal(third.active, 3); equal(third.created, 1); equal(third.reused, 2); equal(third.removed, 1)
    equal(removed[1], handles[1]); assert(reconciler.instances["ground:1"] == nil)
    equal(reconciler.instances["wall:1"].handle, handles[2])
    equal(reconciler.instances["wall:2"].handle, handles[3])

    local animated = {
        { id = "wall:1", animation = "door_open_01" }, { id = "wall:2", animation = "wall_01" },
        { id = "roof:1", animation = "roof_01" },
    }
    local fourth = sprite_reconciler.synchronize(reconciler, animated)
    equal(fourth.active, 3); equal(fourth.created, 0); equal(fourth.reused, 3)
    equal(reconciler.instances["wall:1"].handle, handles[2])
    assert(updated[#updated - 2].changed, "animation change must update the existing instance")

    local recreated = sprite_reconciler.synchronize(reconciler, frame)
    equal(recreated.active, 3); equal(recreated.created, 1); equal(recreated.reused, 2)
    assert(reconciler.instances["ground:1"].handle ~= handles[1])
end)

test("sprite reconciliation never stores or updates a failed factory allocation and retries", function()
    local attempts, updates, removed = 0, 0, 0
    local reconciler = sprite_reconciler.new({
        create = function()
            attempts = attempts + 1
            if attempts == 1 then return nil end
            return "recovered.handle"
        end,
        update = function() updates = updates + 1 end,
        remove = function() removed = removed + 1 end,
    })
    local command = { { id = "retry:1", animation = "grass_01" } }
    local failed = sprite_reconciler.synchronize(reconciler, command)
    equal(failed.failures, 1); equal(failed.active, 0); equal(updates, 0)
    assert(reconciler.instances["retry:1"] == nil)
    local recovered = sprite_reconciler.synchronize(reconciler, command)
    equal(recovered.failures, 0); equal(recovered.created, 1); equal(recovered.active, 1)
    equal(updates, 1); equal(reconciler.instances["retry:1"].handle, "recovered.handle")
    local stable = sprite_reconciler.synchronize(reconciler, command)
    equal(stable.reused, 1); equal(stable.active, 1); equal(attempts, 2)
    local empty = sprite_reconciler.synchronize(reconciler, {})
    equal(empty.removed, 1); equal(empty.active, 0); equal(removed, 1)
end)

test("sprite reconciliation defers creation before exhausting its collection budget", function()
    local creates, removes = 0, 0
    local reconciler = sprite_reconciler.new({
        create = function(command) creates = creates + 1; return "handle." .. command.id end,
        update = function() end,
        remove = function() removes = removes + 1 end,
    }, { max_active = 2 })
    local first = sprite_reconciler.synchronize(reconciler, {
        { id = "old:1", animation = "grass_01" }, { id = "old:2", animation = "grass_01" },
    })
    equal(first.active, 2); equal(first.deferred, 0); equal(creates, 2)

    -- Defold deletes Game Objects at the end of the frame. Do not call the factory for
    -- replacements until the prior handles have been released by this sweep.
    local transition = sprite_reconciler.synchronize(reconciler, {
        { id = "new:1", animation = "grass_01" }, { id = "new:2", animation = "grass_01" },
    })
    equal(transition.active, 0); equal(transition.deferred, 2); equal(transition.removed, 2)
    equal(creates, 2); equal(removes, 2)

    local recovered = sprite_reconciler.synchronize(reconciler, {
        { id = "new:1", animation = "grass_01" }, { id = "new:2", animation = "grass_01" },
    })
    equal(recovered.active, 2); equal(recovered.created, 2); equal(recovered.deferred, 0)
    equal(creates, 4)
end)

test("map loader exposes only statically registered Defold map modules", function()
    local map = map_loader.load("data.maps.prototype")
    equal(map.id, "greyhaven.engine_test")
    local ok, message = pcall(map_loader.load, "data.maps.missing")
    assert(not ok); assert(tostring(message):find("unknown map module", 1, true))
end)

test("position equality and coordinate conversion", function()
    assert(position.equals(position.new(2, 3, 7), position.new(2, 3, 7)))
    local sx, sy = position.world_to_screen(position.new(4, 5, 7), position.new(2, 2, 7), 32)
    equal(sx, 64); equal(sy, 96); assert(position.equals(position.screen_to_world(sx, sy, position.new(2, 2, 7), 32, 7), position.new(4, 5, 7)))
end)

test("camera zoom is integer, pixel-perfect, and presentation-only", function()
    local default_camera = camera_api.new(960, 640)
    equal(default_camera.zoom, 2)
    local one = camera_api.new(960, 640, 1)
    local two = camera_api.new(960, 640, 2)
    local three = camera_api.new(960, 640, 3)
    camera_api.follow(one, 5, 8); camera_api.follow(two, 5, 8); camera_api.follow(three, 5, 8)
    local x1, y1 = camera_api.project(one, 6, 9, 32)
    local x2, y2 = camera_api.project(two, 6, 9, 32)
    local x3, y3 = camera_api.project(three, 6, 9, 32)
    equal(x1, 512); equal(y1, 352)
    equal(x2, 544); equal(y2, 384)
    equal(x3, 576); equal(y3, 416)
    equal(camera_api.scale_pixels(two, 32), 64)
    local visible_width, visible_height = camera_api.visible_tiles(two, 32)
    equal(visible_width, 15); equal(visible_height, 10)
    local one_width, one_height = camera_api.visible_tiles(one, 32)
    equal(one_width, 30); equal(one_height, 20)
    local zoomed_viewport = viewport_api.new(0, 0, visible_width, visible_height, 0)
    assert(viewport_api.intersects(zoomed_viewport, 8, 0))
    assert(not viewport_api.intersects(zoomed_viewport, 9, 0))
    assert(not pcall(camera_api.new, 960, 640, 1.5))
    assert(not pcall(camera_api.new, 960, 640, 4))
end)

test("camera zoom scales interpolated presentation without changing Actor state", function()
    local map = { id = "zoom", version = 1, tile_size = 32, width = 4, height = 4, placements = {
        placement("zoom.ground.1", "grass", 2, 3, 7), placement("zoom.ground.2", "grass", 3, 3, 7),
    } }
    local world = world_api.new(map, registry_api.new(definitions), state_api.new())
    local actor = actor_api.new("zoom.actor", "player", 2, 3, 7)
    world:place_actor(actor); movement.reset(actor); movement.configure(actor, { speed = 1 })
    assert(movement.begin(world, actor, 1, 0)); movement.update(actor, 0.5)
    local visual = movement.visual_position(actor)
    equal(visual.x, 2.5); equal(actor.position.x, 3)
    local camera = camera_api.new(960, 640, 2); camera_api.follow(camera, 2, 3)
    local screen_x = camera_api.project(camera, visual.x, visual.y, 32)
    equal(screen_x, 512); equal(actor.position.x, 3); equal(actor.position.y, 3)
end)

test("fixed virtual canvas scales uniformly without changing world visibility", function()
    equal(layout.VIRTUAL_WIDTH, 1280); equal(layout.VIRTUAL_HEIGHT, 800)
    equal(layout.WORLD.x, 0); equal(layout.WORLD.y, 160)
    equal(layout.WORLD.width, 960); equal(layout.WORLD.height, 640)
    equal(layout.BOTTOM.x, 0); equal(layout.BOTTOM.y, 0)
    equal(layout.BOTTOM.width, 960); equal(layout.BOTTOM.height, 160)
    equal(layout.SIDEBAR.x, 960); equal(layout.SIDEBAR.width, 320); equal(layout.SIDEBAR.height, 800)
    equal(layout.WORLD.x + layout.WORLD.width, layout.SIDEBAR.x)
    equal(layout.BOTTOM.y + layout.BOTTOM.height, layout.WORLD.y)
    equal(layout.WORLD.x + layout.WORLD.width / 2, 480)

    local camera = camera_api.new(layout.WORLD.width, layout.WORLD.height, 2,
        layout.WORLD.x, layout.WORLD.y)
    local visible_width, visible_height = camera_api.visible_tiles(camera, 32)
    equal(visible_width, 15); equal(visible_height, 10)
    local center_x, center_y = camera_api.project(camera, 0, 0, 32)
    equal(center_x, 480); equal(center_y, 480)

    local native = layout.physical_transform(1280, 800)
    equal(native.scale, 1); equal(native.x, 0); equal(native.y, 0)
    local large = layout.physical_transform(2560, 1600)
    equal(large.scale, 2); equal(large.x, 0); equal(large.y, 0)
    local small = layout.physical_transform(640, 400)
    equal(small.scale, 0.5); equal(small.x, 0); equal(small.y, 0)
    local four_three = layout.physical_transform(1024, 768)
    equal(four_three.scale, 0.8); equal(four_three.x, 0); equal(four_three.y, 64)
    local ultrawide = layout.physical_transform(2560, 1080)
    equal(ultrawide.scale, 1.35); equal(ultrawide.x, 416); equal(ultrawide.y, 0)
    local sx, sy, sw, sh = layout.world_viewport(ultrawide)
    equal(sx, 416); equal(sy, 216); equal(sw, 1296); equal(sh, 864)
    local virtual_x, virtual_y = layout.physical_to_virtual(ultrawide, 1064, 648)
    equal(virtual_x, 480); equal(virtual_y, 480)
    assert(layout.is_world_point(100, 200)); assert(not layout.is_world_point(100, 100))
    assert(layout.is_bottom_panel_point(100, 100)); assert(not layout.is_bottom_panel_point(100, 200))
    assert(layout.is_sidebar_point(1000, 400)); assert(not layout.is_sidebar_point(900, 400))
    assert(layout.is_virtual_point(1279, 799)); assert(not layout.is_virtual_point(1280, 800))
    local bar_x, bar_y = layout.physical_to_virtual(ultrawide, 100, 540)
    assert(not layout.is_virtual_point(bar_x, bar_y), "pillarbox input must remain outside the virtual client")
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

test("creature definitions validate registration and isolate snapshots", function()
    local faction_registry = faction_registry_api.new(faction_definitions, relationship_definitions)
    local dialogue_registry = dialogue_registry_api.new(dialogue_definitions,
        quest_registry_api.new(quest_definitions))
    local registry = creature_registry_api.new(creature_definitions, faction_registry, dialogue_registry)
    assert(registry:has("rat") and registry:has("test_villager"))
    equal(#registry:get_all(), 2)
    local rat = registry:get("rat")
    equal(rat.actor_type, "monster"); equal(rat.combat.max_health, 20); equal(rat.attack.damage, 2)
    equal(registry:get("test_villager").dialogue, "test_villager"); assert(rat.dialogue == nil)
    rat.combat.max_health = 999; rat.render.color[1] = 0
    equal(registry:get("rat").combat.max_health, 20); equal(registry:get("rat").render.color[1], 0.72)
    assert(not pcall(function() registry:register(creature_definitions.rat) end))
    assert(not pcall(creature_registry_api.new, { invalid = {
        id = "invalid", actor_type = "vendor", display_name = "Invalid" } }))
    assert(not pcall(creature_registry_api.new, { invalid = {
        id = "invalid", actor_type = "monster", combat = { max_health = 0 } } }))
    assert(not pcall(creature_registry_api.new, { invalid = {
        id = "invalid", actor_type = "monster", attack = { damage = 2, range = 1, cooldown = 1 } } }))
    assert(not pcall(creature_registry_api.new, { invalid = {
        id = "invalid", actor_type = "npc", render = { color = { 2, 0, 0, 1 } } } }))
    assert(not pcall(creature_registry_api.new, { invalid = {
        id = "invalid", actor_type = "npc", faction = "missing" } }, faction_registry))
    assert(not pcall(creature_registry_api.new, { invalid = {
        id = "invalid", actor_type = "npc", dialogue = "missing" } }, faction_registry, dialogue_registry))
end)

test("dialogue definitions validate graphs and isolate snapshots", function()
    local quest_registry = quest_registry_api.new(quest_definitions)
    local registry = dialogue_registry_api.new(dialogue_definitions, quest_registry)
    local definition = registry:get("test_villager")
    equal(definition.start, "greeting"); equal(definition.nodes.greeting.choices[1].id, "ask_place")
    definition.nodes.greeting.text = "Changed"; definition.nodes.greeting.choices[1].text = "Changed"
    definition.nodes.greeting.choices[1].actions[1].value = false
    definition.nodes.greeting.choices[2].conditions[1].equals = false
    definition.nodes.greeting.choices[4].conditions[1].equals = quest_statuses.COMPLETED
    definition.nodes.quest_offer.choices[1].actions[1].id = "missing"
    equal(registry:get("test_villager").nodes.greeting.text, "Morning, traveler.")
    assert(registry:get("test_villager").nodes.greeting.choices[1].actions[1].value)
    assert(registry:get("test_villager").nodes.greeting.choices[2].conditions[1].equals)
    equal(registry:get("test_villager").nodes.greeting.choices[4].conditions[1].equals,
        quest_statuses.ACTIVE)
    equal(registry:get("test_villager").nodes.quest_offer.choices[1].actions[1].id, "rat_problem")
    assert(not pcall(function() registry:register(dialogue_definitions.test_villager) end))
    local function invalid(nodes, start)
        return dialogue_registry_api.new({ bad = { id = "bad", start = start or "start", nodes = nodes } },
            quest_registry)
    end
    assert(not pcall(invalid, { { id = "other", text = "Text", choices = {
        { id = "close", text = "Close", close = true } } } }, "missing"))
    assert(not pcall(invalid, { { id = "start", text = "Text", choices = {
        { id = "next", text = "Next", next = "missing" } } } }))
    assert(not pcall(invalid, {
        { id = "start", text = "One", choices = { { id = "close", text = "Close", close = true } } },
        { id = "start", text = "Two", choices = { { id = "close", text = "Close", close = true } } },
    }))
    assert(not pcall(invalid, { { id = "start", text = "Text", choices = {
        { id = "same", text = "One", close = true }, { id = "same", text = "Two", close = true } } } }))
    assert(not pcall(invalid, { { id = "start", text = "Text", choices = {
        { id = "ambiguous", text = "Bad", next = "start", close = true } } } }))
    assert(not pcall(invalid, { { id = "start", text = "Text", choices = {
        { id = "condition", text = "Bad", close = true,
            conditions = { { type = "flag", id = "bad flag", equals = true } } } } } }))
    assert(not pcall(invalid, { { id = "start", text = "Text", choices = {
        { id = "action", text = "Bad", close = true,
            actions = { { type = "give_item", id = "item", value = true } } } } } }))
    assert(not pcall(invalid, { { id = "start", text = "Text", choices = {
        { id = "action", text = "Bad", close = true,
            actions = { { type = "set_flag", id = "greyhaven.flag", value = "true" } } } } } }))
    assert(not pcall(invalid, { { id = "start", text = "Text", choices = {
        { id = "action", text = "Bad", close = true,
            actions = { { type = "start_quest", id = "missing" } } } } } }))
    assert(not pcall(invalid, { { id = "start", text = "Text", choices = {
        { id = "quest", text = "Bad", close = true,
            conditions = { { type = "quest_status", id = "missing", equals = quest_statuses.ACTIVE } } } } } }))
    assert(not pcall(invalid, { { id = "start", text = "Text", choices = {
        { id = "quest", text = "Bad", close = true,
            conditions = { { type = "quest_status", id = "rat_problem", equals = "failed" } } } } } }))
    assert(not pcall(invalid, { { id = "start", text = "Text", choices = {
        { id = "quest", text = "Bad", close = true, conditions = { {
            type = "quest_objective", quest_id = "rat_problem", objective_id = "missing", complete = true,
        } } } } } }))
end)

test("world flags and recursive conditions are deterministic and side-effect free", function()
    local state = state_api.new()
    assert(not state_api.get_flag(state, "greyhaven.flag.alpha"))
    assert(not state_api.has_flag(state, "greyhaven.flag.alpha"))
    assert(state_api.set_flag(state, "greyhaven.flag.alpha", true)); assert(state_api.has_flag(state, "greyhaven.flag.alpha"))
    assert(state_api.get_flag(state, "greyhaven.flag.alpha"))
    assert(not state_api.set_flag(state, "greyhaven.flag.alpha", false))
    assert(not state_api.get_flag(state, "greyhaven.flag.alpha")); assert(state_api.has_flag(state, "greyhaven.flag.alpha"))
    assert(not pcall(state_api.get_flag, state, "bad flag"))
    assert(not pcall(state_api.set_flag, state, "greyhaven.flag.bad", "yes"))

    state_api.set_flag(state, "greyhaven.flag.alpha", true)
    local alpha_true = { type = "flag", id = "greyhaven.flag.alpha", equals = true }
    local beta_false = { type = "flag", id = "greyhaven.flag.beta", equals = false }
    local beta_true = { type = "flag", id = "greyhaven.flag.beta", equals = true }
    local context = { world_state = state }
    assert(conditions.evaluate(alpha_true, context)); assert(conditions.evaluate(beta_false, context))
    assert(not conditions.evaluate(beta_true, context))
    assert(conditions.evaluate({ all = { alpha_true, beta_false } }, context))
    assert(not conditions.evaluate({ all = { alpha_true, beta_true } }, context))
    assert(conditions.evaluate({ any = { beta_true, alpha_true } }, context))
    assert(not conditions.evaluate({ any = { beta_true, { ["not"] = alpha_true } } }, context))
    assert(conditions.evaluate({ ["not"] = beta_true }, context))
    local before = codec.serialize(state)
    for _ = 1, 3 do assert(conditions.evaluate(alpha_true, context)) end
    equal(codec.serialize(state), before)
    assert(not pcall(conditions.evaluate, { type = "flag", id = "bad flag", equals = true }, context))
    assert(not pcall(conditions.evaluate, { type = "flag", id = "greyhaven.flag.alpha" }, context))
    assert(not pcall(conditions.evaluate, { all = {} }, context))
    assert(not pcall(conditions.evaluate, { all = { alpha_true }, any = { beta_true } }, context))
end)

test("world flag actions validate complete batches and execute in authored order", function()
    local state = state_api.new()
    local context = { world_state = state }
    local set_true = { type = "set_flag", id = "greyhaven.action.flag", value = true }
    assert(world_actions.validate(set_true))
    assert(not pcall(world_actions.validate, { type = "unknown", id = "greyhaven.action.flag", value = true }))
    assert(not pcall(world_actions.validate, { type = "set_flag", id = "bad flag", value = true }))
    assert(not pcall(world_actions.validate, { type = "set_flag", id = "greyhaven.action.flag", value = 1 }))
    assert(not pcall(world_actions.validate, {
        type = "set_flag", id = "greyhaven.action.flag", value = true, next = "node" }))

    local invalid_batch = { set_true,
        { type = "set_flag", id = "greyhaven.action.other", value = "yes" } }
    assert(not pcall(world_actions.execute_all, invalid_batch, context))
    assert(not state_api.has_flag(state, "greyhaven.action.flag"))

    local results = world_actions.execute_all({ set_true,
        { type = "set_flag", id = "greyhaven.action.flag", value = false } }, context)
    equal(#results, 2); assert(not results[1].previous); assert(results[1].value)
    assert(results[2].previous); assert(not results[2].value)
    assert(not state_api.get_flag(state, "greyhaven.action.flag"))
end)

test("generic world actions validate and delegate quest mutations with structured failures", function()
    events.clear()
    local state = state_api.new()
    local registry = quest_registry_api.new(quest_definitions)
    local quest_service = quests.create(registry, events)
    local context = { world_state = state, quests = quest_service, quest_registry = registry }
    local start = { type = "start_quest", id = "rat_problem" }
    local advance = { type = "advance_quest", id = "rat_problem",
        objective_id = "investigate", amount = 1 }
    local complete = { type = "complete_quest", id = "rat_problem" }
    assert(world_actions.validate(start, registry)); assert(world_actions.validate(advance, registry))
    assert(world_actions.validate(complete, registry))
    assert(not pcall(world_actions.validate, { type = "start_quest", id = "missing" }, registry))
    assert(not pcall(world_actions.validate, { type = "advance_quest", id = "rat_problem",
        objective_id = "missing", amount = 1 }, registry))
    for _, amount in ipairs({ 0, -1, 1.5 }) do
        assert(not pcall(world_actions.validate, { type = "advance_quest", id = "rat_problem",
            objective_id = "investigate", amount = amount }, registry))
    end

    local invalid_batch = {
        { type = "set_flag", id = "greyhaven.prevalidated", value = true },
        start,
        { type = "advance_quest", id = "rat_problem", objective_id = "investigate", amount = 0 },
    }
    assert(not pcall(world_actions.execute_all, invalid_batch, context))
    assert(not state_api.has_flag(state, "greyhaven.prevalidated"))
    equal(quests.get_status(quest_service, "rat_problem"), quest_statuses.NOT_STARTED)

    local inactive_result, inactive_failure = world_actions.execute(advance, context)
    assert(inactive_result == nil); equal(inactive_failure.reason, "not_started")
    equal(inactive_failure.action_index, 1)
    local completion_result, completion_failure = world_actions.execute(complete, context)
    assert(completion_result == nil); equal(completion_failure.reason, "not_started")

    local order = {}
    events.on("quest_started", function() order[#order + 1] = "quest_started" end)
    events.on("world_action_executed", function(payload) order[#order + 1] = "world:" .. payload.type end)
    local mixed = world_actions.execute_all({
        { type = "set_flag", id = "greyhaven.mixed", value = true }, start,
    }, context, events)
    equal(#mixed, 2); assert(state_api.get_flag(state, "greyhaven.mixed"))
    equal(quests.get_status(quest_service, "rat_problem"), quest_statuses.ACTIVE)
    equal(order[1], "world:set_flag"); equal(order[2], "quest_started"); equal(order[3], "world:start_quest")
    local premature, premature_failure = world_actions.execute(complete, context)
    assert(premature == nil); equal(premature_failure.reason, "objectives_incomplete")

    local stopped, failure = world_actions.execute_all({
        { type = "set_flag", id = "greyhaven.committed", value = true },
        start,
        { type = "set_flag", id = "greyhaven.must_not_run", value = true },
    }, context, events)
    assert(stopped == nil); equal(failure.reason, "already_active"); equal(failure.action_index, 2)
    equal(#failure.results, 1); assert(state_api.get_flag(state, "greyhaven.committed"))
    assert(not state_api.has_flag(state, "greyhaven.must_not_run"))

    local advanced = world_actions.execute(advance, context, events)
    equal(advanced.progress, 1); equal(advanced.target, 1)
    local repeated, repeated_failure = world_actions.execute(advance, context)
    assert(repeated == nil); equal(repeated_failure.reason, "objective_completed")
    local completed = world_actions.execute(complete, context, events)
    equal(completed.status, quest_statuses.COMPLETED)
    local completed_again, completed_failure = world_actions.execute(complete, context)
    assert(completed_again == nil); equal(completed_failure.reason, "already_completed")
end)

test("quest definitions validate and registry snapshots are isolated", function()
    local registry = quest_registry_api.new(quest_definitions)
    assert(registry:has("rat_problem")); equal(#registry:get_all(), 1)
    local definition = registry:get("rat_problem")
    equal(definition.title, "A Small Rat Problem"); equal(definition.objectives[1].target, 1)
    definition.title = "Changed"; definition.objectives[1].target = 99
    equal(registry:get("rat_problem").title, "A Small Rat Problem")
    equal(registry:get("rat_problem").objectives[1].target, 1)
    assert(not pcall(function() registry:register(quest_definitions.rat_problem) end))
    local function invalid(definition_source)
        return quest_registry_api.new({ bad = definition_source })
    end
    assert(not pcall(invalid, { id = "bad id", title = "Bad", objectives = {
        { id = "one", description = "One", target = 1 } } }))
    assert(not pcall(invalid, { id = "bad", title = "", objectives = {
        { id = "one", description = "One", target = 1 } } }))
    assert(not pcall(invalid, { id = "bad", title = "Bad", objectives = {
        { id = "one", description = "", target = 1 } } }))
    assert(not pcall(invalid, { id = "bad", title = "Bad", objectives = {
        { id = "one", description = "One", target = 0 } } }))
    assert(not pcall(invalid, { id = "bad", title = "Bad", objectives = {
        { id = "one", description = "One", target = 1 },
        { id = "one", description = "Again", target = 2 } } }))
end)

test("quest runtime explicitly starts, progresses, completes, emits once, and isolates state", function()
    events.clear()
    local registry = quest_registry_api.new(quest_definitions)
    local started, progressed, objective_completed, completed = 0, 0, 0, 0
    local progress_payload
    events.on("quest_started", function() started = started + 1 end)
    events.on("quest_objective_progressed", function(payload)
        progressed = progressed + 1; progress_payload = payload
    end)
    events.on("quest_objective_completed", function() objective_completed = objective_completed + 1 end)
    events.on("quest_completed", function() completed = completed + 1 end)
    local service = quests.create(registry, events)
    equal(quests.get_status(service, "rat_problem"), quest_statuses.NOT_STARTED)
    assert(next(quests.get_snapshot(service)) == nil)
    assert(quests.get_status(service, "missing") == nil)
    local before_progress, before_reason = quests.get_objective_progress(service, "rat_problem", "investigate")
    assert(before_progress == nil); equal(before_reason, "not_started")
    local early_complete, early_reason = quests.complete(service, "rat_problem")
    assert(not early_complete); equal(early_reason, "not_started"); equal(completed, 0)
    assert(quests.start(service, "rat_problem")); equal(started, 1)
    local restarted, restart_reason = quests.start(service, "rat_problem")
    assert(not restarted); equal(restart_reason, "already_active"); equal(started, 1)
    equal(quests.get_objective_progress(service, "rat_problem", "investigate"), 0)
    local incomplete, incomplete_reason = quests.complete(service, "rat_problem")
    assert(not incomplete); equal(incomplete_reason, "objectives_incomplete")
    local invalid, invalid_reason = quests.advance_objective(service, "rat_problem", "investigate", -1)
    assert(not invalid); equal(invalid_reason, "invalid_amount"); equal(progressed, 0)
    local unknown, unknown_reason = quests.advance_objective(service, "rat_problem", "missing", 1)
    assert(not unknown); equal(unknown_reason, "unknown_objective"); equal(progressed, 0)
    assert(quests.advance_objective(service, "rat_problem", "investigate", 5))
    equal(progress_payload.previous, 0); equal(progress_payload.progress, 1); equal(progress_payload.target, 1)
    equal(progressed, 1); equal(objective_completed, 1)
    assert(quests.is_objective_complete(service, "rat_problem", "investigate"))
    local over, over_reason = quests.advance_objective(service, "rat_problem", "investigate", 1)
    assert(not over); equal(over_reason, "objective_completed")
    equal(progressed, 1); equal(objective_completed, 1)
    assert(quests.complete(service, "rat_problem")); equal(completed, 1)
    equal(quests.get_status(service, "rat_problem"), quest_statuses.COMPLETED)
    local twice, twice_reason = quests.complete(service, "rat_problem")
    assert(not twice); equal(twice_reason, "already_completed"); equal(completed, 1)
    local snapshot = quests.get_snapshot(service); snapshot.rat_problem.status = quest_statuses.ACTIVE
    equal(quests.get_status(service, "rat_problem"), quest_statuses.COMPLETED)
    assert(not pcall(quests.create, registry, nil, { missing = {
        status = quest_statuses.ACTIVE, objectives = { investigate = 0 } } }))
    assert(not pcall(quests.create, registry, nil, { rat_problem = {
        status = quest_statuses.COMPLETED, objectives = { investigate = 0 } } }))

    local multi_registry = quest_registry_api.new({ multi = { id = "multi", title = "Multiple", objectives = {
        { id = "first", description = "First", target = 2 },
        { id = "second", description = "Second", target = 1 },
    } } })
    local multi = quests.create(multi_registry)
    assert(quests.start(multi, "multi"))
    assert(quests.advance_objective(multi, "multi", "first", 1))
    equal(quests.get_objective_progress(multi, "multi", "first"), 1)
    assert(quests.advance_objective(multi, "multi", "first", 10))
    equal(quests.get_objective_progress(multi, "multi", "first"), 2)
    local not_all, not_all_reason = quests.complete(multi, "multi")
    assert(not not_all); equal(not_all_reason, "objectives_incomplete")
    assert(quests.advance_objective(multi, "multi", "second", 1)); assert(quests.complete(multi, "multi"))
end)

test("generic conditions query quest status and objectives without side effects", function()
    events.clear()
    local registry = quest_registry_api.new(quest_definitions)
    local service = quests.create(registry, events)
    local state = state_api.new()
    state_api.set_flag(state, "greyhaven.condition.flag", true)
    local context = { world_state = state, quests = service, quest_registry = registry }
    local not_started = { type = "quest_status", id = "rat_problem", equals = quest_statuses.NOT_STARTED }
    local active = { type = "quest_status", id = "rat_problem", equals = quest_statuses.ACTIVE }
    local completed = { type = "quest_status", id = "rat_problem", equals = quest_statuses.COMPLETED }
    local incomplete_objective = { type = "quest_objective", quest_id = "rat_problem",
        objective_id = "investigate", complete = false }
    local complete_objective = { type = "quest_objective", quest_id = "rat_problem",
        objective_id = "investigate", complete = true }
    assert(conditions.validate(not_started, registry)); assert(conditions.validate(complete_objective, registry))
    assert(conditions.evaluate(not_started, context)); assert(not conditions.evaluate(active, context))
    assert(conditions.evaluate(incomplete_objective, context)); assert(not conditions.evaluate(complete_objective, context))
    assert(not pcall(conditions.validate,
        { type = "quest_status", id = "rat_problem", equals = "failed" }, registry))
    assert(not pcall(conditions.validate,
        { type = "quest_status", id = "missing", equals = quest_statuses.ACTIVE }, registry))
    assert(not pcall(conditions.validate, { type = "quest_objective", quest_id = "rat_problem",
        objective_id = "missing", complete = true }, registry))
    assert(not pcall(conditions.validate, { type = "quest_objective", quest_id = "rat_problem",
        objective_id = "investigate", complete = 1 }, registry))

    local flag_true = { type = "flag", id = "greyhaven.condition.flag", equals = true }
    assert(not conditions.evaluate({ all = { flag_true, active } }, context))
    assert(conditions.evaluate({ any = { flag_true, active } }, context))
    assert(conditions.evaluate({ ["not"] = active }, context))

    local quest_events = 0
    events.on("quest_started", function() quest_events = quest_events + 1 end)
    events.on("quest_objective_progressed", function() quest_events = quest_events + 1 end)
    events.on("quest_objective_completed", function() quest_events = quest_events + 1 end)
    events.on("quest_completed", function() quest_events = quest_events + 1 end)
    local before = codec.serialize(quests.get_snapshot(service))
    for _ = 1, 3 do
        assert(conditions.evaluate(not_started, context)); assert(conditions.evaluate(incomplete_objective, context))
    end
    equal(codec.serialize(quests.get_snapshot(service)), before); equal(quest_events, 0)

    assert(quests.start(service, "rat_problem")); equal(quest_events, 1)
    assert(conditions.evaluate(active, context)); assert(not conditions.evaluate(not_started, context))
    assert(conditions.evaluate(incomplete_objective, context))
    assert(conditions.evaluate({ all = { flag_true, active } }, context))
    assert(quests.advance_objective(service, "rat_problem", "investigate", 1)); equal(quest_events, 3)
    local progress = quests.get_objective_progress(service, "rat_problem", "investigate")
    for _ = 1, 3 do assert(conditions.evaluate(complete_objective, context)) end
    equal(quests.get_objective_progress(service, "rat_problem", "investigate"), progress); equal(quest_events, 3)
    assert(quests.complete(service, "rat_problem")); equal(quest_events, 4)
    assert(conditions.evaluate(completed, context)); assert(conditions.evaluate(complete_objective, context))

    local restored = quests.create(registry, nil, quests.get_snapshot(service))
    local restored_context = { world_state = state, quests = restored, quest_registry = registry }
    assert(conditions.evaluate(completed, restored_context))
    local reset = quests.create(registry)
    local reset_context = { world_state = state, quests = reset, quest_registry = registry }
    assert(conditions.evaluate(not_started, reset_context)); assert(conditions.evaluate(incomplete_objective, reset_context))
end)

test("faction definitions and directional relationships are canonical and isolated", function()
    local registry = faction_registry_api.new(faction_definitions, relationship_definitions)
    assert(registry:has("player") and registry:has("townsfolk") and registry:has("vermin"))
    equal(#registry:get_all(), 3)
    local townsfolk = registry:get("townsfolk"); townsfolk.display_name = "Changed"
    equal(registry:get("townsfolk").display_name, "Greyhaven Townsfolk")
    assert(not pcall(function() registry:register(faction_definitions.player) end))
    assert(registry:get("missing") == nil)
    equal(registry:relationship("player", "player"), faction_relationships.FRIENDLY)
    equal(registry:relationship("player", "townsfolk"), faction_relationships.FRIENDLY)
    equal(registry:relationship("player", "vermin"), faction_relationships.HOSTILE)
    assert(not pcall(function() registry:relationship("missing", "player") end))
    assert(not pcall(faction_registry_api.new, faction_definitions, { player = { vermin = "afraid" } }))

    local directional_defs = {
        first = { id = "first", display_name = "First" },
        second = { id = "second", display_name = "Second" },
        third = { id = "third", display_name = "Third" },
    }
    local directional = faction_registry_api.new(directional_defs, { first = { second = "hostile" } })
    equal(directional:relationship("first", "second"), faction_relationships.HOSTILE)
    equal(directional:relationship("second", "first"), faction_relationships.NEUTRAL)
    equal(directional:relationship("first", "third"), faction_relationships.NEUTRAL)
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

local function creature_services(world, definitions_source)
    local faction_registry = faction_registry_api.new(faction_definitions, relationship_definitions)
    local faction_service = factions.create(world, faction_registry)
    local quest_registry = quest_registry_api.new(quest_definitions)
    local quest_service = quests.create(quest_registry, events)
    local dialogue_registry = dialogue_registry_api.new(dialogue_definitions, quest_registry)
    local registry = creature_registry_api.new(definitions_source or creature_definitions, faction_registry,
        dialogue_registry)
    local combat = combat_registry.create(world, events)
    local attack_service = attacks.create(world, combat, events)
    local perception_service = perception.create(world, combat, faction_service)
    local creature_service = creatures.create(world, registry, combat, attack_service, events, faction_service,
        perception_service)
    local dialogue_service = dialogue.create(world, dialogue_registry, creature_service, combat, events,
        quest_service, quest_registry)
    return creature_service, registry, combat, attack_service, faction_service, faction_registry,
        dialogue_service, dialogue_registry, quest_service, quest_registry
end

test("creature spawning composes optional Actor combat and attack state", function()
    events.clear()
    local world = path_world(5, 3)
    local service, _, combat, attack_service, faction_service = creature_services(world)
    local villager = creatures.spawn(service, { id = "npc.spawned", creature = "test_villager",
        x = 1, y = 1, z = 7, facing = "east" })
    equal(villager.id, "npc.spawned"); equal(villager.type, "npc")
    equal(creatures.get_definition_id(service, villager.id), "test_villager")
    assert(combat_registry.get(combat, villager.id) == nil)
    assert(attacks.get_profile(attack_service, villager.id) == nil)
    equal(world:get_actor_at(1, 1, 7).id, villager.id)
    equal(factions.get_actor_faction(faction_service, villager.id), "townsfolk")

    local rat_a = creatures.spawn(service, { id = "monster.rat.a", creature = "rat",
        x = 2, y = 1, z = 7, facing = "west" })
    local rat_b = creatures.spawn(service, { id = "monster.rat.b", creature = "rat",
        x = 3, y = 1, z = 7, facing = "west" })
    equal(rat_a.type, "monster"); equal(rat_b.type, "monster")
    equal(combat_registry.get(combat, rat_a.id).health, 20)
    equal(combat_registry.get(combat, rat_b.id).health, 20)
    equal(attacks.get_profile(attack_service, rat_a.id).damage, 2)
    equal(attacks.get_profile(attack_service, rat_a.id).cooldown, 1)
    assert(combat_registry.apply_damage(combat, rat_a.id, 5).success)
    equal(combat_registry.get(combat, rat_a.id).health, 15)
    equal(combat_registry.get(combat, rat_b.id).health, 20)
    equal(creatures.get_definition_for_actor(service, rat_a.id).id, "rat")
    equal(factions.get_actor_faction(faction_service, rat_a.id), "vermin")
    equal(factions.get_actor_faction(faction_service, rat_b.id), "vermin")
    equal(perception.get_config(service.perception, rat_a.id).sight_range, 6)
    equal(perception.get_config(service.perception, rat_b.id).sight_range, 6)
    local isolated_perception = perception.get_config(service.perception, rat_a.id)
    isolated_perception.sight_range = 99
    equal(perception.get_config(service.perception, rat_a.id).sight_range, 6)
    assert(rat_a.creature == nil and rat_a.combat == nil and rat_a.attack == nil)

    assert(not pcall(creatures.spawn, service, { id = "monster.unknown", creature = "missing",
        x = 4, y = 1, z = 7 }))
    assert(not pcall(creatures.spawn, service, { id = rat_a.id, creature = "rat",
        x = 4, y = 1, z = 7 }))
end)

test("creature perception metadata is validated and definition snapshots are isolated", function()
    local valid = { watcher = { id = "watcher", actor_type = "npc",
        perception = { sight_range = 4 } } }
    local registry = creature_registry_api.new(valid)
    local snapshot = registry:get("watcher")
    equal(snapshot.perception.sight_range, 4)
    snapshot.perception.sight_range = 99
    equal(registry:get("watcher").perception.sight_range, 4)
    for _, value in ipairs({ 0, -1, 1.5, "six" }) do
        assert(not pcall(creature_registry_api.new, { bad = { id = "bad", actor_type = "npc",
            perception = { sight_range = value } } }))
    end
    assert(not pcall(creature_registry_api.new, { bad = { id = "bad", actor_type = "npc",
        perception = { sight_range = 2, hearing = 1 } } }))
end)

test("perception is current, deterministic, omnidirectional, and excludes inactive or dead Actors", function()
    events.clear()
    local world = path_world(10, 2, nil, nil, {
        placement("perception.upper", "grass", 2, 0, 8),
    })
    local service, _, combat, _, faction_service = creature_services(world)
    local rat = creatures.spawn(service, { id = "perception.rat", creature = "rat",
        x = 2, y = 0, z = 7, facing = "north" })
    local player = actor_api.new("perception.player", "player", 0, 0, 7, "west")
    local middle = actor_api.new("perception.middle", "npc", 1, 0, 7, "east")
    local far = actor_api.new("perception.far", "npc", 9, 0, 7, "west")
    local upper = actor_api.new("perception.upper.actor", "npc", 2, 0, 8, "south")
    world:place_actor(player); world:place_actor(middle); world:place_actor(far); world:place_actor(upper)
    assert(combat_registry.add(combat, player.id, 10)); assert(combat_registry.add(combat, middle.id, 10))
    assert(factions.associate(faction_service, player.id, "player"))

    local visible, distance = perception.can_perceive(service.perception, rat.id, player.id)
    assert(visible); equal(distance, 2)
    rat.facing = "east"; assert(perception.can_perceive(service.perception, rat.id, player.id))
    equal(perception.can_perceive(service.perception, rat.id, rat.id), false)
    equal(perception.can_perceive(service.perception, rat.id, far.id), false)
    equal(perception.can_perceive(service.perception, rat.id, upper.id), false)
    local perceived = perception.get_perceived_actors(service.perception, rat.id)
    equal(perceived[1].actor_id, middle.id); equal(perceived[2].actor_id, player.id)
    equal(perceived[2].relationship, "hostile")
    equal(combat_registry.get(combat, player.id).health, 10)
    equal(factions.get_actor_faction(faction_service, player.id), "player")
    middle.active = false; equal(perception.can_perceive(service.perception, rat.id, middle.id), false)
    middle.active = true; assert(combat_registry.apply_damage(combat, middle.id, 10).died)
    equal(perception.can_perceive(service.perception, rat.id, middle.id), false)
    rat.active = false; equal(#perception.get_perceived_actors(service.perception, rat.id), 0)
    rat.active = true; assert(combat_registry.apply_damage(combat, rat.id, 20).died)
    equal(#perception.get_perceived_actors(service.perception, rat.id), 0)
    assert(player.position.x == 0 and rat.position.x == 2)
end)

test("logical line of sight uses authored blockers, door state, and centre-line corner policy", function()
    local function fixture(blocker, blocker_y)
        local extra = blocker and { placement("los.blocker", blocker, 3, blocker_y or 1, 7) } or nil
        local world = path_world(7, 3, nil, nil, extra)
        local service = creature_services(world)
        local rat = creatures.spawn(service, { id = "los.rat", creature = "rat",
            x = 1, y = 1, z = 7, facing = "west" })
        local target = actor_api.new("los.target", "player", 5, 1, 7, "east")
        world:place_actor(target)
        return world, service, rat, target
    end

    local wall_world, wall_service, wall_rat, wall_target = fixture("wall")
    equal(perception.can_perceive(wall_service.perception, wall_rat.id, wall_target.id), false)
    local door_world, door_service, door_rat, door_target = fixture("wood_door")
    equal(perception.can_perceive(door_service.perception, door_rat.id, door_target.id), false)
    door_world:set_object_state("los.blocker", { open = true })
    assert(perception.can_perceive(door_service.perception, door_rat.id, door_target.id))

    local table_world, table_service, table_rat, table_target = fixture("table")
    assert(perception.can_perceive(table_service.perception, table_rat.id, table_target.id))
    local actor_blocker = actor_api.new("los.actor.blocker", "npc", 3, 1, 7); table_world:place_actor(actor_blocker)
    assert(perception.can_perceive(table_service.perception, table_rat.id, table_target.id))

    local item_registry = item_registry_api.new(item_definitions)
    local item_world = path_world(7, 3, nil, nil, nil, item_registry)
    local item_service = creature_services(item_world)
    local item_rat = creatures.spawn(item_service, { id = "item.los.rat", creature = "rat",
        x = 1, y = 1, z = 7 })
    local item_target = actor_api.new("item.los.target", "player", 5, 1, 7); item_world:place_actor(item_target)
    world_items.place(item_world, item_instance.new({ id = "item.los.herb", type = "healing_herb",
        quantity = 1 }, item_registry), { x = 3, y = 1, z = 7 }, "item.los.world")
    assert(perception.can_perceive(item_service.perception, item_rat.id, item_target.id))

    local barrier = {
        placement("barrier.0", "table", 3, 0, 7), placement("barrier.1", "table", 3, 1, 7),
        placement("barrier.2", "table", 3, 2, 7),
    }
    local barrier_world = path_world(7, 3, nil, nil, barrier)
    local barrier_service = creature_services(barrier_world)
    local barrier_rat = creatures.spawn(barrier_service, { id = "barrier.rat", creature = "rat",
        x = 1, y = 1, z = 7 })
    local barrier_target = actor_api.new("barrier.target", "player", 5, 1, 7); barrier_world:place_actor(barrier_target)
    assert(perception.can_perceive(barrier_service.perception, barrier_rat.id, barrier_target.id))
    assert(not pathfinding.find_path(barrier_world, barrier_rat.id, { x = 5, y = 0, z = 7 }).success)

    local visual_world, visual_service, visual_rat, visual_target = fixture("wall_block", 0)
    assert(perception.can_perceive(visual_service.perception, visual_rat.id, visual_target.id))
    local points = line_of_sight.trace(0, 0, 2, 2)
    equal(#points, 3); equal(points[2].x, 1); equal(points[2].y, 1)
    local corner_world = path_world(3, 3, nil, nil, { placement("corner.side", "wall", 1, 0, 7) })
    assert(line_of_sight.is_clear(corner_world, { x = 0, y = 0, z = 7 }, { x = 2, y = 2, z = 7 }))
    corner_world:add_object(object_instance.new(placement("corner.centre", "wall", 1, 1, 7)))
    assert(not line_of_sight.is_clear(corner_world, { x = 0, y = 0, z = 7 }, { x = 2, y = 2, z = 7 }))

    local endpoint_world = path_world(3, 1, nil, nil, { placement("endpoint.wall", "wall", 2, 0, 7) })
    local endpoint_service = creature_services(endpoint_world)
    local endpoint_rat = creatures.spawn(endpoint_service, { id = "endpoint.rat", creature = "rat",
        x = 0, y = 0, z = 7 })
    local endpoint_target = actor_api.new("endpoint.target", "player", 2, 0, 7); endpoint_world:place_actor(endpoint_target)
    assert(perception.can_perceive(endpoint_service.perception, endpoint_rat.id, endpoint_target.id))
end)

test("perception reconstructs from authored definitions without persisted awareness", function()
    local function compose()
        local world = path_world(8, 1)
        local service = creature_services(world)
        local rat = creatures.spawn(service, { id = "restore.rat", creature = "rat", x = 1, y = 0, z = 7 })
        local player = actor_api.new("restore.player", "player", 6, 0, 7); world:place_actor(player)
        return service, rat, player
    end
    local first, first_rat, first_player = compose()
    assert(perception.can_perceive(first.perception, first_rat.id, first_player.id))
    local derived = perception.get_awareness(first.perception, first_rat.id)
    derived.perceived[1].actor_id = "mutated"
    equal(perception.get_awareness(first.perception, first_rat.id).perceived[1].actor_id, first_player.id)
    local restored, restored_rat, restored_player = compose()
    equal(perception.get_config(restored.perception, restored_rat.id).sight_range, 6)
    assert(perception.can_perceive(restored.perception, restored_rat.id, restored_player.id))
end)

test("Actor faction queries remain informational and support unaffiliated Actors", function()
    events.clear()
    local world = path_world(5, 2)
    local creature_service, _, combat, attack_service, faction_service = creature_services(world)
    local player = actor_api.new("faction.player", "player", 0, 0, 7, "east")
    world:place_actor(player); assert(combat_registry.add(combat, player.id, 20))
    assert(factions.associate(faction_service, player.id, "player"))
    local villager = creatures.spawn(creature_service, { id = "faction.villager", creature = "test_villager",
        x = 1, y = 0, z = 7, facing = "west" })
    local rat = creatures.spawn(creature_service, { id = "faction.rat", creature = "rat",
        x = 2, y = 0, z = 7, facing = "west" })
    local unaffiliated = actor_api.new("faction.none", "npc", 3, 0, 7); world:place_actor(unaffiliated)

    equal(factions.get_actor_faction(faction_service, player.id), "player")
    equal(factions.get_actor_faction(faction_service, villager.id), "townsfolk")
    equal(factions.get_actor_faction(faction_service, rat.id), "vermin")
    equal(factions.get_actor_faction(faction_service, unaffiliated.id), nil)
    equal(factions.relationship_between_actors(faction_service, villager.id, player.id), "friendly")
    equal(factions.relationship_between_actors(faction_service, rat.id, player.id), "hostile")
    equal(factions.relationship_between_actors(faction_service, unaffiliated.id, player.id), "neutral")
    assert(factions.are_friendly(faction_service, villager.id, player.id))
    assert(factions.are_hostile(faction_service, rat.id, player.id))
    assert(factions.are_neutral(faction_service, unaffiliated.id, player.id))
    local missing, reason = factions.get_actor_faction(faction_service, "missing")
    assert(missing == nil); equal(reason, "unknown_actor")

    local rat_health = combat_registry.get(combat, rat.id).health
    local rat_position = position.copy(rat.position)
    local cooldown = attacks.get_profile(attack_service, rat.id).cooldown_remaining
    for _ = 1, 3 do assert(factions.are_hostile(faction_service, rat.id, player.id)) end
    equal(combat_registry.get(combat, rat.id).health, rat_health)
    assert(position.equals(rat.position, rat_position)); assert(not movement.is_moving(rat))
    equal(attacks.get_profile(attack_service, rat.id).cooldown_remaining, cooldown)

    local ally = actor_api.new("faction.ally", "npc", 0, 1, 7, "south")
    world:place_actor(ally); assert(combat_registry.add(combat, ally.id, 10))
    assert(factions.associate(faction_service, ally.id, "player"))
    assert(attacks.add_profile(attack_service, player.id, { damage = 1, range = 1, cooldown = 1 }))
    assert(factions.are_friendly(faction_service, player.id, ally.id))
    local explicit_friendly_attack = attacks.try_attack(attack_service, player.id, ally.id)
    assert(explicit_friendly_attack.success); equal(combat_registry.get(combat, ally.id).health, 9)
end)

test("explicit NPC dialogue sessions transition, replace, close, and have no gameplay side effects", function()
    events.clear()
    local world = path_world(4, 3)
    local creature_service, _, combat, _, faction_service, _, dialogue_service = creature_services(world)
    local player = actor_api.new("dialogue.player", "player", 0, 0, 7, "east")
    world:place_actor(player); assert(combat_registry.add(combat, player.id, 20))
    assert(factions.associate(faction_service, player.id, "player"))
    local inventory_registry = item_registry_api.new(item_definitions)
    player.inventory = inventory_api.create("dialogue.inventory", player.id, 1, inventory_registry)
    inventory_api.add_item(player.inventory,
        item_instance.new({ id = "dialogue.item", type = "healing_herb", quantity = 1 }, inventory_registry))
    local villager = creatures.spawn(creature_service, { id = "dialogue.villager", creature = "test_villager",
        x = 1, y = 0, z = 7, facing = "west" })
    local rat = creatures.spawn(creature_service, { id = "dialogue.rat", creature = "rat",
        x = 0, y = 1, z = 7, facing = "south" })
    local player_position, villager_position = position.copy(player.position), position.copy(villager.position)
    local player_health = combat_registry.get(combat, player.id).health
    local player_faction = factions.get_actor_faction(faction_service, player.id)
    local inventory_before = codec.serialize(inventory_api.snapshot(player.inventory))
    local started, selected, changed, closed, action_count, started_payload, choice_payload = 0, 0, 0, 0, 0
    events.on("dialogue_started", function(payload) started = started + 1; started_payload = payload end)
    events.on("dialogue_choice_selected", function(payload) selected = selected + 1; choice_payload = payload end)
    events.on("dialogue_node_changed", function() changed = changed + 1 end)
    events.on("dialogue_closed", function() closed = closed + 1 end)
    events.on("world_action_executed", function(payload)
        action_count = action_count + 1
        equal(payload.id, "greyhaven.met_test_villager")
    end)

    actions.register_defaults({ dialogue = dialogue_service })
    local began = interaction.use(world, player, events)
    assert(began); assert(dialogue.is_active(dialogue_service)); equal(started, 1)
    equal(started_payload.player_actor_id, player.id); equal(started_payload.npc_actor_id, villager.id)
    equal(started_payload.dialogue_id, "test_villager"); equal(started_payload.node_id, "greeting")
    local current = dialogue.get_current(dialogue_service)
    equal(current.node_id, "greeting"); equal(current.speaker_name, "Test Villager")
    equal(current.npc_actor_id, villager.id); equal(current.choices[1].id, "ask_place"); equal(#current.choices, 3)
    local hidden, hidden_reason = dialogue.choose(dialogue_service, "ask_rat")
    assert(not hidden); equal(hidden_reason, "invalid_choice")
    state_api.set_flag(world.state, "greyhaven.test_dialogue_flag", true)
    local revealed = dialogue.get_current(dialogue_service)
    equal(#revealed.choices, 4); equal(revealed.choices[2].id, "ask_rat")
    assert(dialogue.choose(dialogue_service, "ask_rat")); equal(dialogue.get_current(dialogue_service).node_id, "rat_problem")
    assert(dialogue.choose(dialogue_service, "back")); equal(dialogue.get_current(dialogue_service).node_id, "greeting")
    state_api.set_flag(world.state, "greyhaven.test_dialogue_flag", false)
    equal(#dialogue.get_current(dialogue_service).choices, 3)
    local stale_index, stale_reason = dialogue.choose_index(dialogue_service, 4)
    assert(not stale_index); equal(stale_reason, "invalid_choice")
    local isolated_dialogue_registry = dialogue_registry_api.new(dialogue_definitions,
        quest_registry_api.new(quest_definitions))
    equal(isolated_dialogue_registry:get("test_villager").nodes.greeting.choices[2].id, "ask_rat")
    assert(player.dialogue == nil and villager.dialogue == nil)
    local ok, reason = dialogue.choose(dialogue_service, "missing")
    assert(not ok); equal(reason, "invalid_choice"); equal(dialogue.get_current(dialogue_service).node_id, "greeting")
    assert(dialogue.choose(dialogue_service, "ask_place")); equal(selected, 3); equal(changed, 3)
    equal(action_count, 1); assert(state_api.get_flag(world.state, "greyhaven.met_test_villager"))
    equal(choice_payload.choice_id, "ask_place"); equal(choice_payload.node_id, "greeting")
    equal(dialogue.get_current(dialogue_service).node_id, "about_place")
    equal(#dialogue.get_current(dialogue_service).choices, 3)
    equal(dialogue.get_current(dialogue_service).choices[2].id, "met_before")
    assert(dialogue.choose_index(dialogue_service, 3)); assert(not dialogue.is_active(dialogue_service))
    equal(action_count, 2)
    equal(selected, 4); equal(closed, 1)

    assert(dialogue.begin(dialogue_service, player.id, villager.id))
    assert(dialogue.begin(dialogue_service, player.id, villager.id))
    equal(started, 3); equal(closed, 2)
    assert(dialogue.close(dialogue_service, "test")); equal(closed, 3)
    local no_session, no_session_reason = dialogue.choose(dialogue_service, "ask_place")
    assert(not no_session); equal(no_session_reason, "no_active_dialogue")

    player.facing = "north"
    local no_dialogue, no_dialogue_reason = dialogue.begin(dialogue_service, player.id, rat.id)
    assert(not no_dialogue); equal(no_dialogue_reason, "no_dialogue")
    player.facing = "east"; villager.active = false
    local inactive, inactive_reason = dialogue.begin(dialogue_service, player.id, villager.id)
    assert(not inactive); equal(inactive_reason, "npc_unavailable")
    villager.active = true; assert(combat_registry.add(combat, villager.id, 5))
    assert(combat_registry.apply_damage(combat, villager.id, 5).died)
    local dead, dead_reason = dialogue.begin(dialogue_service, player.id, villager.id)
    assert(not dead); equal(dead_reason, "npc_dead")

    equal(factions.get_actor_faction(faction_service, player.id), player_faction)
    assert(not state_api.get_flag(world.state, "greyhaven.test_dialogue_flag"))
    assert(state_api.get_flag(world.state, "greyhaven.met_test_villager"))
    equal(combat_registry.get(combat, player.id).health, player_health)
    equal(codec.serialize(inventory_api.snapshot(player.inventory)), inventory_before)
    assert(position.equals(player.position, player_position)); assert(position.equals(villager.position, villager_position))
end)

test("event binding registry validates and isolates authored actor-death rules", function()
    local creature_registry = creature_registry_api.new(creature_definitions)
    local quest_registry = quest_registry_api.new(quest_definitions)
    local registry = binding_registry_api.new(binding_definitions, creature_registry, quest_registry)
    local definition = assert(registry:get("rat_problem.rat_died"))
    equal(definition.event, "actor_died")
    definition.match.actor_definition = "changed"
    equal(registry:get("rat_problem.rat_died").match.actor_definition, "rat")
    equal(#registry:get_for_event("actor_died"), 1)

    local function rejected(source)
        return not pcall(function()
            binding_registry_api.new({ [source.id or "bad"] = source }, creature_registry, quest_registry)
        end)
    end
    assert(rejected({ id = "bad.event", event = "world_action_executed",
        match = { actor_id = "rat" }, actions = definition.actions }))
    assert(rejected({ id = "bad.match", event = "actor_died",
        match = { unsupported = "rat" }, actions = definition.actions }))
    assert(rejected({ id = "bad.creature", event = "actor_died",
        match = { actor_definition = "unknown" }, actions = definition.actions }))
    assert(rejected({ id = "bad.actions", event = "actor_died",
        match = { actor_id = "rat" }, actions = { { type = "unknown" } } }))
    local duplicate = binding_registry_api.new(nil, creature_registry, quest_registry)
    duplicate:register(definition)
    assert(not pcall(function() duplicate:register(definition) end))
end)

test("actor-death bindings match identity metadata and report action failures", function()
    events.clear()
    local world = path_world(5, 2)
    local creature_service, creature_registry, combat, _, _, _, _, _, quest_service,
        quest_registry = creature_services(world)
    local rat = creatures.spawn(creature_service, { id = "binding.rat", creature = "rat",
        x = 1, y = 0, z = 7, facing = "west" })
    local npc = creatures.spawn(creature_service, { id = "binding.npc", creature = "test_villager",
        x = 2, y = 0, z = 7, facing = "west" })
    local definitions = {
        ["a.actor_id"] = { id = "a.actor_id", event = "actor_died",
            match = { actor_id = rat.id }, actions = { { type = "set_flag", id = "binding.actor", value = true } } },
        ["b.actor_type"] = { id = "b.actor_type", event = "actor_died",
            match = { actor_type = "monster" }, actions = { { type = "set_flag", id = "binding.type", value = true } } },
        ["c.definition"] = { id = "c.definition", event = "actor_died",
            match = { actor_definition = "rat" }, actions = { { type = "advance_quest", id = "rat_problem",
                objective_id = "investigate", amount = 1 } } },
        ["z.nonmatch"] = { id = "z.nonmatch", event = "actor_died",
            match = { actor_id = npc.id }, actions = { { type = "set_flag", id = "binding.npc", value = true } } },
    }
    local registry = binding_registry_api.new(definitions, creature_registry, quest_registry)
    local service = event_bindings.create(registry, events, world, creature_service,
        { world_state = world.state, quests = quest_service, quest_registry = quest_registry })

    assert(combat_registry.apply_damage(combat, rat.id, 20).died)
    local results = event_bindings.get_last_results(service)
    equal(#results, 3); equal(results[1].binding_id, "a.actor_id")
    equal(results[2].binding_id, "b.actor_type"); equal(results[3].binding_id, "c.definition")
    assert(results[1].success and results[2].success and not results[3].success)
    assert(state_api.get_flag(world.state, "binding.actor")); assert(state_api.get_flag(world.state, "binding.type"))
    assert(not state_api.get_flag(world.state, "binding.npc"))
    equal(quests.get_status(quest_service, "rat_problem"), quest_statuses.NOT_STARTED)
    assert(combat_registry.get(combat, rat.id).dead)
    assert(not combat_registry.apply_damage(combat, rat.id, 1).success)
    equal(#event_bindings.get_last_results(service), 3)
    event_bindings.destroy(service)
end)

test("dialogue composes generic quest conditions and actions into the authored quest loop", function()
    events.clear()
    local world = path_world(4, 2)
    local creature_service, _, combat, _, _, _, dialogue_service, dialogue_registry,
        quest_service, quest_registry = creature_services(world)
    local player = actor_api.new("dialogue.quest.player", "player", 0, 0, 7, "east")
    world:place_actor(player); assert(combat_registry.add(combat, player.id, 20))
    local villager = creatures.spawn(creature_service, { id = "dialogue.quest.villager",
        creature = "test_villager", x = 1, y = 0, z = 7, facing = "west" })
    local rat = creatures.spawn(creature_service, { id = "dialogue.quest.rat",
        creature = "rat", x = 2, y = 0, z = 7, facing = "west" })
    local second_rat = creatures.spawn(creature_service, { id = "dialogue.quest.rat.second",
        creature = "rat", x = 3, y = 0, z = 7, facing = "west" })
    local binding_registry = binding_registry_api.new(binding_definitions, creature_service.registry, quest_registry)
    local binding_service = event_bindings.create(binding_registry, events, world, creature_service,
        { world_state = world.state, quests = quest_service, quest_registry = quest_registry })
    local function has_choice(choice_id)
        for _, choice in ipairs(dialogue.get_current(dialogue_service).choices) do
            if choice.id == choice_id then return true end
        end
        return false
    end
    local event_order = {}
    events.on("quest_started", function() event_order[#event_order + 1] = "quest_started" end)
    events.on("quest_objective_progressed", function() event_order[#event_order + 1] = "quest_progressed" end)
    events.on("quest_objective_completed", function() event_order[#event_order + 1] = "objective_completed" end)
    events.on("quest_completed", function() event_order[#event_order + 1] = "quest_completed" end)
    events.on("world_action_executed", function(payload)
        event_order[#event_order + 1] = "world:" .. payload.type
    end)

    assert(dialogue.begin(dialogue_service, player.id, villager.id))
    assert(has_choice("offer_rat_problem")); assert(not has_choice("active_rat_problem"))
    assert(not has_choice("completed_rat_problem"))
    assert(dialogue.choose(dialogue_service, "offer_rat_problem"))
    equal(dialogue.get_current(dialogue_service).node_id, "quest_offer")
    assert(dialogue.choose(dialogue_service, "accept_rat_problem"))
    equal(quests.get_status(quest_service, "rat_problem"), quest_statuses.ACTIVE)
    equal(event_order[1], "quest_started"); equal(event_order[2], "world:start_quest")
    local active_snapshot = codec.serialize(quests.get_snapshot(quest_service))
    assert(has_choice("active_rat_problem")); assert(not has_choice("completed_rat_problem"))
    for _ = 1, 3 do dialogue.get_current(dialogue_service) end
    equal(codec.serialize(quests.get_snapshot(quest_service)), active_snapshot)
    assert(dialogue.choose(dialogue_service, "active_rat_problem"))
    equal(dialogue.get_current(dialogue_service).node_id, "quest_active")
    assert(not has_choice("finish_rat_problem")); assert(dialogue.close(dialogue_service, "test"))
    assert(combat_registry.apply_damage(combat, rat.id, 20).died)
    equal(quests.get_objective_progress(quest_service, "rat_problem", "investigate"), 1)
    equal(quests.get_status(quest_service, "rat_problem"), quest_statuses.ACTIVE)
    equal(event_order[3], "quest_progressed"); equal(event_order[4], "objective_completed")
    equal(event_order[5], "world:advance_quest")
    local first_results = event_bindings.get_last_results(binding_service)
    equal(first_results[1].binding_id, "rat_problem.rat_died"); assert(first_results[1].success)
    assert(not combat_registry.apply_damage(combat, rat.id, 1).success)
    equal(#event_order, 5)
    assert(combat_registry.apply_damage(combat, second_rat.id, 20).died)
    equal(quests.get_objective_progress(quest_service, "rat_problem", "investigate"), 1)
    local second_results = event_bindings.get_last_results(binding_service)
    equal(second_results[1].binding_id, "rat_problem.rat_died")
    assert(not second_results[1].success)
    equal(#event_order, 5)
    assert(dialogue.begin(dialogue_service, player.id, villager.id))
    assert(dialogue.choose(dialogue_service, "active_rat_problem"))
    assert(not has_choice("report_investigation")); assert(has_choice("finish_rat_problem"))
    assert(dialogue.choose(dialogue_service, "finish_rat_problem"))
    equal(quests.get_status(quest_service, "rat_problem"), quest_statuses.COMPLETED)
    equal(event_order[6], "quest_completed"); equal(event_order[7], "world:complete_quest")
    equal(#event_order, 7)

    local completed_snapshot = codec.serialize(quests.get_snapshot(quest_service))
    assert(not has_choice("active_rat_problem")); assert(has_choice("completed_rat_problem"))
    equal(codec.serialize(quests.get_snapshot(quest_service)), completed_snapshot)
    equal(#event_order, 7)
    local definition = dialogue_registry:get("test_villager")
    definition.nodes.greeting.choices[4].conditions[1].equals = quest_statuses.NOT_STARTED
    equal(dialogue_registry:get("test_villager").nodes.greeting.choices[4].conditions[1].equals,
        quest_statuses.ACTIVE)

    local restored_quests = quests.create(quest_registry, nil, quests.get_snapshot(quest_service))
    local restored_dialogue = dialogue.create(world, dialogue_registry, creature_service, combat, events,
        restored_quests, quest_registry)
    assert(dialogue.begin(restored_dialogue, player.id, villager.id))
    local restored_choices = dialogue.get_current(restored_dialogue).choices
    local restored_completed = false
    for _, choice in ipairs(restored_choices) do
        if choice.id == "completed_rat_problem" then restored_completed = true end
    end
    assert(restored_completed)

    local reset_quests = quests.create(quest_registry)
    local reset_dialogue = dialogue.create(world, dialogue_registry, creature_service, combat, events,
        reset_quests, quest_registry)
    assert(dialogue.begin(reset_dialogue, player.id, villager.id))
    for _, choice in ipairs(dialogue.get_current(reset_dialogue).choices) do
        assert(choice.id ~= "active_rat_problem" and choice.id ~= "completed_rat_problem")
    end
    local reset_offer = false
    for _, choice in ipairs(dialogue.get_current(reset_dialogue).choices) do
        if choice.id == "offer_rat_problem" then reset_offer = true end
    end
    assert(reset_offer)
    event_bindings.destroy(binding_service)
end)

test("creature attacks remain explicit and retain existing death and occupancy policy", function()
    events.clear()
    local world = path_world(3, 2)
    local service, _, combat, attack_service, _, _, _, _, quest_service = creature_services(world)
    assert(quests.start(quest_service, "rat_problem"))
    local quest_before_combat = codec.serialize(quests.get_snapshot(quest_service))
    local rat = creatures.spawn(service, { id = "monster.explicit.rat", creature = "rat",
        x = 1, y = 0, z = 7, facing = "west" })
    local player = actor_api.new("creature.target", "player", 0, 0, 7, "east")
    world:place_actor(player); assert(combat_registry.add(combat, player.id, 10))
    equal(combat_registry.get(combat, player.id).health, 10)
    local attack = attacks.try_attack(attack_service, rat.id, player.id)
    assert(attack.success); equal(attack.damage, 2); equal(combat_registry.get(combat, player.id).health, 8)
    assert(combat_registry.apply_damage(combat, rat.id, 20).died)
    equal(codec.serialize(quests.get_snapshot(quest_service)), quest_before_combat)
    assert(world:get_actor(rat.id) ~= nil); equal(world:get_actor_at(1, 0, 7).id, rat.id)
    assert(not world:is_walkable(1, 0, 7, player.id))
end)

test("actor rendering uses creature metadata with Actor type fallback", function()
    events.clear()
    local world = path_world(4, 2)
    local custom = { green_test = { id = "green_test", actor_type = "npc",
        render = { color = { 0.13, 0.77, 0.31, 1 }, size = 17 } } }
    local service = creature_services(world, custom)
    creatures.spawn(service, { id = "npc.render.definition", creature = "green_test",
        x = 1, y = 0, z = 7, facing = "south" })
    local fallback = actor_api.new("npc.render.fallback", "npc", 2, 0, 7); world:place_actor(fallback)
    local viewer = actor_api.new("render.creature.viewer", "player", 0, 0, 7); world:place_actor(viewer)
    local commands = renderer.build(world, viewer, 0, nil, service)
    local by_id = {}; for _, command in ipairs(commands) do by_id[command.id] = command end
    equal(by_id["npc.render.definition:actor"].color[1], 0.13)
    equal(by_id["npc.render.definition:actor"].size, 17)
    equal(by_id["npc.render.fallback:actor"].color[1], 0.78)
    equal(by_id["npc.render.fallback:actor"].size, 22)
end)

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

local function finish_controller(controller, limit)
    for _ = 1, limit or 20 do movement_controller.update(controller, 1) end
end

test("movement controller validates paths and keeps route state outside Actors", function()
    local world = path_world(4, 3)
    local npc = actor_api.new("controller.npc", "npc", 0, 0, 7); world:place_actor(npc)
    local controller = movement_controller.create(world)
    assert(controller.states == nil, "controller must not expose mutable path state")
    equal(movement_controller.get_status(controller, npc.id), "idle")
    equal(movement_controller.get_remaining_steps(controller, npc.id), 0)
    assert(npc.path == nil and npc.path_status == nil)
    local ok, reason = movement_controller.set_path(controller, "missing", {}); assert(not ok); equal(reason, "unknown_actor")
    ok, reason = movement_controller.set_path(controller, npc.id, "bad"); assert(not ok); equal(reason, "invalid_path")
    ok, reason = movement_controller.set_path(controller, npc.id, { { x = 2, y = 0, z = 7 } })
    assert(not ok); equal(reason, "non_adjacent_step")
    ok, reason = movement_controller.set_path(controller, npc.id, { { x = 0, y = 0, z = 6 } })
    assert(not ok); equal(reason, "z_change")
    ok, reason = movement_controller.set_path(controller, npc.id, { { x = 1.5, y = 0, z = 7 } })
    assert(not ok); equal(reason, "invalid_path")
end)

test("movement controller executes supplied paths one shared movement step at a time", function()
    events.clear()
    local world = path_world(4, 3)
    local npc = actor_api.new("controller.walker", "npc", 0, 0, 7); world:place_actor(npc)
    local started, completed, moved = 0, 0, 0
    events.on("actor_path_started", function(payload) started = started + 1; equal(payload.actor_id, npc.id) end)
    events.on("actor_path_completed", function(payload) completed = completed + 1; equal(payload.actor_id, npc.id) end)
    events.on("actor_moved", function(payload) moved = moved + 1; equal(payload.actor_id, npc.id) end)
    local controller = movement_controller.create(world, events)
    local path = { position.new(1, 0, 7), position.new(1, 1, 7), position.new(2, 1, 7) }
    assert(movement_controller.set_path(controller, npc.id, path)); equal(started, 1)
    path[1].x = 99
    equal(movement_controller.get_next_target(controller, npc.id).x, 1)
    movement_controller.update(controller, 100)
    equal(npc.position.x, 1); equal(npc.position.y, 0); equal(moved, 1)
    assert(movement.is_moving(npc)); equal(movement.visual_position(npc).x, 0)
    movement_controller.update(controller, 100)
    equal(npc.position.x, 1); equal(npc.position.y, 0); equal(moved, 1)
    finish_controller(controller)
    equal(npc.position.x, 2); equal(npc.position.y, 1); equal(npc.facing, "east")
    equal(movement_controller.get_status(controller, npc.id), "completed")
    assert(not movement_controller.has_path(controller, npc.id)); equal(completed, 1); equal(moved, 3)
    movement_controller.update(controller, 1); equal(completed, 1)
end)

test("movement controller cancellation and replacement finish committed interpolation", function()
    events.clear()
    local world = path_world(4, 3)
    local actor = actor_api.new("controller.replace", "player", 0, 0, 7); world:place_actor(actor)
    local cancelled = 0
    events.on("actor_path_cancelled", function(payload) cancelled = cancelled + 1; equal(payload.actor_id, actor.id) end)
    local controller = movement_controller.create(world, events)
    assert(movement_controller.set_path(controller, actor.id,
        { position.new(1, 0, 7), position.new(2, 0, 7) }))
    movement_controller.update(controller, 0)
    equal(actor.position.x, 1); assert(movement.is_moving(actor))
    assert(movement_controller.cancel(controller, actor.id)); equal(movement_controller.get_status(controller, actor.id), "cancelled")
    equal(cancelled, 1)
    movement_controller.update(controller, 1)
    equal(movement.visual_position(actor).x, 1); equal(actor.position.x, 1)

    assert(movement_controller.set_path(controller, actor.id,
        { position.new(1, 1, 7), position.new(2, 1, 7) }))
    movement_controller.update(controller, 0)
    assert(movement_controller.set_path(controller, actor.id, { position.new(2, 1, 7) }))
    movement_controller.update(controller, 1)
    equal(actor.position.x, 1); equal(actor.position.y, 1)
    finish_controller(controller)
    equal(actor.position.x, 2); equal(actor.position.y, 1)
    equal(movement_controller.get_status(controller, actor.id), "completed")
end)

test("movement controller blocks stale Actor and door paths without replanning", function()
    events.clear()
    local world = path_world(4, 1)
    local npc = actor_api.new("controller.blocked.actor", "npc", 0, 0, 7); world:place_actor(npc)
    local controller = movement_controller.create(world, events)
    local blocked = 0
    events.on("actor_path_blocked", function(payload) blocked = blocked + 1; equal(payload.reason, "step_blocked") end)
    assert(movement_controller.set_path(controller, npc.id,
        { position.new(1, 0, 7), position.new(2, 0, 7) }))
    world:place_actor(actor_api.new("controller.blocker", "monster", 1, 0, 7))
    movement_controller.update(controller, 1)
    equal(movement_controller.get_status(controller, npc.id), "blocked"); equal(npc.position.x, 0); equal(blocked, 1)
    movement_controller.update(controller, 1); equal(blocked, 1); equal(npc.position.x, 0)

    local door = placement("controller.door", "wood_door", 1, 0, 7, { open = true })
    local door_world = path_world(3, 1, nil, nil, { door })
    local player = actor_api.new("controller.door.player", "player", 0, 0, 7); door_world:place_actor(player)
    local player_controller = movement_controller.create(door_world)
    assert(movement_controller.set_path(player_controller, player.id,
        { position.new(1, 0, 7), position.new(2, 0, 7) }))
    door_world:set_object_state("controller.door", { open = false })
    movement_controller.update(player_controller, 1)
    equal(movement_controller.get_status(player_controller, player.id), "blocked")
    equal(player.position.x, 0)
end)

test("health state validates bounds and applies deterministic clamped damage", function()
    local state = health.create("combat.health.actor", 20)
    equal(health.get_current(state), 20); equal(health.get_max(state), 20); assert(not health.is_dead(state))
    assert(not pcall(health.damage, state, 0)); assert(not pcall(health.damage, state, -1))
    local changed = health.damage(state, 4)
    equal(changed.previous_health, 20); equal(changed.health, 16); equal(changed.damage, 4); assert(not changed.died)
    changed = health.damage(state, 99)
    equal(changed.previous_health, 16); equal(changed.health, 0); assert(changed.died); assert(health.is_dead(state))
    assert(not pcall(health.create, "combat.bad.zero", 0))
    assert(not pcall(health.create, "combat.bad.float", 2.5))
    assert(not pcall(health.damage, state, 1))
end)

test("combat registry owns isolated health, events, death, and explicit cleanup", function()
    events.clear()
    local world = path_world(3, 1)
    local actor = actor_api.new("combat.registry.actor", "monster", 0, 0, 7); world:place_actor(actor)
    local damaged, died = 0, 0
    events.on("actor_damaged", function(payload)
        damaged = damaged + 1; equal(payload.actor_id, actor.id); equal(payload.amount, 3)
    end)
    events.on("actor_died", function(payload) died = died + 1; equal(payload.actor_id, actor.id) end)
    local combat = combat_registry.create(world, events)
    local created = assert(combat_registry.add(combat, actor.id, 5))
    equal(created.health, 5); assert(combat.states == nil)
    created.health = 1; equal(combat_registry.get(combat, actor.id).health, 5)
    equal(combat_registry.apply_damage(combat, actor.id, 0).reason, "invalid_damage")
    local hit = combat_registry.apply_damage(combat, actor.id, 3, { source = { id = "test" } })
    assert(hit.success); equal(hit.previous_health, 5); equal(hit.health, 2); assert(not hit.died); equal(damaged, 1)
    hit.context.source.id = "changed"
    local fatal = combat_registry.apply_damage(combat, actor.id, 9)
    assert(fatal.success and fatal.died); equal(fatal.health, 0); equal(died, 1); equal(damaged, 2)
    local rejected = combat_registry.apply_damage(combat, actor.id, 1)
    assert(not rejected.success); equal(rejected.reason, "actor_dead"); equal(died, 1); equal(damaged, 2)
    equal(combat_registry.apply_damage(combat, "missing", 1).reason, "unknown_actor")
    local removed = assert(combat_registry.remove(combat, actor.id)); assert(removed.dead)
    assert(combat_registry.get(combat, actor.id) == nil)
    local missing, reason = combat_registry.add(combat, "missing", 5); assert(missing == nil); equal(reason, "unknown_actor")
end)

test("combat capabilities stop dead movement, interaction, and supplied routes", function()
    events.clear(); actions.register_defaults()
    local world = path_world(4, 1)
    local actor = actor_api.new("combat.movement.actor", "npc", 0, 0, 7, "east"); world:place_actor(actor)
    local combat = combat_registry.create(world, events); assert(combat_registry.add(combat, actor.id, 2))
    assert(movement.begin(world, actor, 1, 0)); movement.update(actor, 1)
    local controller = movement_controller.create(world, events)
    assert(movement_controller.set_path(controller, actor.id,
        { position.new(2, 0, 7), position.new(3, 0, 7) }))
    movement_controller.update(controller, 0)
    equal(actor.position.x, 2); assert(movement.is_moving(actor))
    assert(combat_registry.apply_damage(combat, actor.id, 2).died)
    movement_controller.update(controller, 1)
    movement_controller.update(controller, 0)
    equal(actor.position.x, 2); equal(movement_controller.get_status(controller, actor.id), "blocked")
    assert(not movement.begin(world, actor, 1, 0))
    local used, reason = interaction.use(world, actor, events); assert(not used); equal(reason, "actor_dead")
    equal(world:get_actor_at(2, 0, 7).id, actor.id)

    combat_registry.remove(combat, actor.id); world:remove_actor(actor.id)
    local living = actor_api.new("combat.living.actor", "player", 0, 0, 7); world:place_actor(living)
    assert(movement.begin(world, living, 1, 0))
end)

test("save v5 preserves player combat state and a fresh registry resets health", function()
    local world, inventory, registry = world_item_fixture(2)
    local actor = actor_api.new("player", "player", 1, 1, 7); actor.inventory = inventory
    actor.equipment = equipment_api.create("equipment.combat.save", actor.id, registry); world:place_actor(actor)
    local combat = combat_registry.create(world); assert(combat_registry.add(combat, actor.id, 100))
    combat_registry.apply_damage(combat, actor.id, 35)
    local saved = save_data.capture(actor, world, world.map.id, combat_registry.get(combat, actor.id))
    local valid, reason = save_data.validate(saved, world.map); assert(valid, reason)
    local restored = save_data.restore_player_combat(saved)
    equal(restored.health, 65); equal(restored.max_health, 100); assert(not restored.dead)
    restored.health = 1; equal(saved.combat.player.health, 65)

    local fresh_world, fresh_inventory, fresh_registry = world_item_fixture(2)
    local fresh_actor = actor_api.new("player", "player", 1, 1, 7); fresh_actor.inventory = fresh_inventory
    fresh_actor.equipment = equipment_api.create("equipment.combat.fresh", fresh_actor.id, fresh_registry)
    fresh_world:place_actor(fresh_actor)
    local fresh_combat = combat_registry.create(fresh_world); combat_registry.add(fresh_combat, fresh_actor.id, 100)
    equal(combat_registry.get(fresh_combat, fresh_actor.id).health, 100)
end)

local function attack_fixture()
    local world = path_world(5, 4)
    local combat = combat_registry.create(world, events)
    local service = attacks.create(world, combat, events)
    local function add(id, actor_type, x, y, health_value, profile)
        local actor = actor_api.new(id, actor_type, x, y, 7, "east"); world:place_actor(actor)
        if health_value then assert(combat_registry.add(combat, id, health_value)) end
        if profile then assert(attacks.add_profile(service, id, profile)) end
        return actor
    end
    return world, combat, service, add
end

test("attack profiles validate and stay isolated from Actors and callers", function()
    events.clear()
    local world, combat, service, add = attack_fixture()
    local player = add("attack.profile.player", "player", 0, 0, 10)
    assert(service.profiles == nil and player.attack == nil)
    local profile = assert(attacks.add_profile(service, player.id, { damage = 5, range = 1, cooldown = 0.75 }))
    equal(profile.damage, 5); equal(profile.range, 1); equal(profile.cooldown, 0.75); equal(profile.cooldown_remaining, 0)
    profile.damage = 99; equal(attacks.get_profile(service, player.id).damage, 5)
    local bad, reason = attacks.add_profile(service, "missing", { damage = 1, range = 1, cooldown = 1 })
    assert(bad == nil); equal(reason, "unknown_actor")
    local no_damage = add("attack.profile.damage", "npc", 1, 0, 10)
    bad, reason = attacks.add_profile(service, no_damage.id, { damage = 0, range = 1, cooldown = 1 })
    assert(bad == nil); equal(reason, "invalid_damage")
    local no_range = add("attack.profile.range", "npc", 2, 0, 10)
    bad, reason = attacks.add_profile(service, no_range.id, { damage = 1, range = 2, cooldown = 1 })
    assert(bad == nil); equal(reason, "invalid_range")
    local no_cooldown = add("attack.profile.cooldown", "npc", 3, 0, 10)
    bad, reason = attacks.add_profile(service, no_cooldown.id, { damage = 1, range = 1, cooldown = 0 })
    assert(bad == nil); equal(reason, "invalid_cooldown")
end)

test("attacks validate Actors, combat state, range, movement, and failed cooldown policy", function()
    events.clear()
    local world, combat, service, add = attack_fixture()
    local player = add("attack.validation.player", "player", 0, 0, 10, { damage = 3, range = 1, cooldown = 0.5 })
    local target = add("attack.validation.target", "monster", 1, 0, 10)
    equal(attacks.try_attack(service, "missing", target.id).reason, "unknown_attacker")
    equal(attacks.try_attack(service, target.id, player.id).reason, "cannot_attack")
    equal(attacks.try_attack(service, player.id, player.id).reason, "invalid_target")
    equal(attacks.try_attack(service, player.id, "missing").reason, "unknown_target")

    local no_combat = add("attack.validation.no_combat", "npc", 4, 3, nil, { damage = 1, range = 1, cooldown = 1 })
    equal(attacks.try_attack(service, no_combat.id, player.id).reason, "attacker_has_no_combat_state")
    local target_no_combat = add("attack.validation.target_no_combat", "npc", 1, 1)
    movement.teleport(world, player, position.new(0, 1, 7))
    equal(attacks.try_attack(service, player.id, target_no_combat.id).reason, "target_has_no_combat_state")
    equal(attacks.get_profile(service, player.id).cooldown_remaining, 0)

    movement.teleport(world, player, position.new(0, 0, 7))
    assert(combat_registry.add(combat, target_no_combat.id, 10))
    equal(attacks.try_attack(service, player.id, target_no_combat.id).reason, "out_of_range")
    local far = add("attack.validation.far", "monster", 3, 0, 10)
    equal(attacks.try_attack(service, player.id, far.id).reason, "out_of_range")
    equal(attacks.get_profile(service, player.id).cooldown_remaining, 0)

    local z_map = { id = "attack_z", version = 1, tile_size = 32, width = 2, height = 1, placements = {
        placement("attack.z7", "grass", 0, 0, 7), placement("attack.z6", "basement_floor", 1, 0, 6),
    } }
    local z_world = world_api.new(z_map, registry_api.new(definitions), state_api.new())
    local z_attacker = actor_api.new("attack.z.attacker", "player", 0, 0, 7); z_world:place_actor(z_attacker)
    local z_target = actor_api.new("attack.z.target", "monster", 1, 0, 6); z_world:place_actor(z_target)
    local z_combat = combat_registry.create(z_world); combat_registry.add(z_combat, z_attacker.id, 10); combat_registry.add(z_combat, z_target.id, 10)
    local z_service = attacks.create(z_world, z_combat); attacks.add_profile(z_service, z_attacker.id, { damage = 1, range = 1, cooldown = 1 })
    equal(attacks.try_attack(z_service, z_attacker.id, z_target.id).reason, "different_z")

    assert(movement.begin(world, player, 0, 1))
    equal(attacks.try_attack(service, player.id, target.id).reason, "attacker_moving")
    movement.update(player, 1); movement.teleport(world, player, position.new(0, 0, 7))
    player.active = false; equal(attacks.try_attack(service, player.id, target.id).reason, "attacker_inactive"); player.active = true

    local dead_attacker = add("attack.validation.dead", "npc", 0, 2, 1, { damage = 1, range = 1, cooldown = 1 })
    combat_registry.apply_damage(combat, dead_attacker.id, 1)
    equal(attacks.try_attack(service, dead_attacker.id, target.id).reason, "attacker_dead")
end)

test("generic attacks deal exact damage, cool down, preserve movement, and order lethal events", function()
    events.clear()
    local world, combat, service, add = attack_fixture()
    local player = add("attack.player", "player", 0, 0, 10, { damage = 5, range = 1, cooldown = 0.75 })
    local rat = add("attack.rat", "monster", 1, 0, 10, { damage = 2, range = 1, cooldown = 1 })
    local order_seen = {}
    events.on("actor_attacked", function(payload)
        order_seen[#order_seen + 1] = "attacked"; equal(payload.damage, 5); equal(payload.target_id, rat.id)
    end)
    events.on("actor_damaged", function() order_seen[#order_seen + 1] = "damaged" end)
    events.on("actor_died", function() order_seen[#order_seen + 1] = "died" end)

    local result = attacks.try_attack(service, player.id, rat.id)
    assert(result.success); equal(result.damage, 5); equal(result.target_health, 5); assert(not result.target_died)
    equal(combat_registry.get(combat, rat.id).health, 5)
    equal(order_seen[1], "attacked"); equal(order_seen[2], "damaged")
    equal(attacks.try_attack(service, player.id, rat.id).reason, "cooldown")
    assert(movement.begin(world, player, 0, 1)); movement.update(player, 1)
    attacks.update(service, 0.74); assert(attacks.get_profile(service, player.id).cooldown_remaining > 0)
    attacks.update(service, 0.02); equal(attacks.get_profile(service, player.id).cooldown_remaining, 0)
    movement.teleport(world, player, position.new(0, 0, 7))
    result = attacks.try_attack(service, player.id, rat.id)
    assert(result.success and result.target_died); equal(result.target_health, 0)
    equal(order_seen[3], "attacked"); equal(order_seen[4], "damaged"); equal(order_seen[5], "died")
    attacks.update(service, 1)
    equal(attacks.try_attack(service, player.id, rat.id).reason, "target_dead")
    equal(#order_seen, 5); equal(combat_registry.get(combat, rat.id).health, 0)

    -- The inert monster uses the same API only because this test explicitly invokes it.
    events.clear()
    local monster_world, monster_combat, monster_service, monster_add = attack_fixture()
    local monster = monster_add("attack.monster", "monster", 0, 0, 10, { damage = 2, range = 1, cooldown = 1 })
    local npc = monster_add("attack.npc", "npc", 1, 0, 10)
    local monster_hit = attacks.try_attack(monster_service, monster.id, npc.id)
    assert(monster_hit.success); equal(monster_combat and combat_registry.get(monster_combat, npc.id).health, 8)
end)

test("equipped main-hand weapons replace unarmed damage without changing identity or cooldown", function()
    events.clear()
    local defs = {}
    for id, definition in pairs(item_definitions) do defs[id] = definition end
    defs.training_charm = { id = "training_charm", name = "Training Charm",
        equipment = { slots = { "main_hand" } } }
    local item_registry = item_registry_api.new(defs)
    local world = path_world(3, 2)
    local attacker = actor_api.new("weapon.monster", "monster", 0, 0, 7, "east"); world:place_actor(attacker)
    local target = actor_api.new("weapon.target", "npc", 1, 0, 7, "west"); world:place_actor(target)
    local combat = combat_registry.create(world, events)
    combat_registry.add(combat, attacker.id, 20); combat_registry.add(combat, target.id, 100)
    local service = attacks.create(world, combat, events, item_registry)
    attacks.add_profile(service, attacker.id, { damage = 5, range = 1, cooldown = 0.5 })
    local inventory = inventory_api.create("inventory.weapon.monster", attacker.id, 3, item_registry)
    local equipment = equipment_api.create("equipment.weapon.monster", attacker.id, item_registry)
    assert(attacks.set_equipment(service, attacker.id, equipment))
    assert(attacker.equipment == nil and service.equipment == nil)

    local attacked_payload
    events.on("actor_attacked", function(payload) attacked_payload = payload end)
    local unarmed = attacks.try_attack(service, attacker.id, target.id)
    assert(unarmed.success); equal(unarmed.damage, 5); equal(unarmed.damage_source, "unarmed")
    assert(unarmed.weapon_item_id == nil); equal(combat_registry.get(combat, target.id).health, 95)
    equal(attacked_payload.damage_source, "unarmed"); assert(attacked_payload.weapon_item_id == nil)
    equal(unarmed.cooldown, 0.5)
    attacks.update(service, 1)

    local sword = item_instance.new({ id = "weapon.same.instance", type = "worn_iron_sword" }, item_registry)
    inventory_api.add_item(inventory, sword)
    assert(equipment_api.equip(equipment, inventory, sword.id, "main_hand"))
    equal(equipment_api.get(equipment, "main_hand").id, sword.id)
    local weapon = attacks.try_attack(service, attacker.id, target.id)
    assert(weapon.success); equal(weapon.damage, 8); equal(weapon.damage_source, "weapon")
    equal(weapon.weapon_item_id, sword.id); equal(weapon.weapon_type, "worn_iron_sword")
    equal(weapon.cooldown, unarmed.cooldown); equal(combat_registry.get(combat, target.id).health, 87)
    equal(attacked_payload.weapon_item_id, sword.id); equal(attacked_payload.weapon_type, "worn_iron_sword")
    equal(attacked_payload.damage, 8)
    attacks.update(service, 1)

    local unequipped, returned = equipment_api.unequip(equipment, inventory, "main_hand")
    assert(unequipped); equal(returned.id, sword.id)
    local fallback = attacks.try_attack(service, attacker.id, target.id)
    assert(fallback.success); equal(fallback.damage, 5); equal(fallback.damage_source, "unarmed")
    attacks.update(service, 1)
    assert(equipment_api.equip(equipment, inventory, sword.id, "main_hand"))
    equal(attacks.get_damage(service, attacker.id).damage, 8)
    equal(attacks.get_damage(service, attacker.id).item_id, sword.id)
    attacks.update(service, 1)
    assert(equipment_api.unequip(equipment, inventory, "main_hand"))

    local charm = item_instance.new({ id = "weapon.nonweapon.instance", type = "training_charm" }, item_registry)
    inventory_api.add_item(inventory, charm)
    assert(equipment_api.equip(equipment, inventory, charm.id, "main_hand"))
    local ordinary = attacks.try_attack(service, attacker.id, target.id)
    assert(ordinary.success); equal(ordinary.damage, 5); equal(ordinary.damage_source, "unarmed")
end)

test("restored equipped weapon identity continues resolving weapon damage", function()
    local registry = item_registry_api.new(item_definitions)
    local inventory = inventory_api.create("inventory.weapon.save", "weapon.save.actor", 1, registry)
    local equipment = equipment_api.create("equipment.weapon.save", "weapon.save.actor", registry)
    inventory_api.add_item(inventory, item_instance.new({ id = "weapon.saved.instance", type = "worn_iron_sword",
        state = { maker = "Greyhaven Smith" } }, registry))
    assert(equipment_api.equip(equipment, inventory, "weapon.saved.instance", "main_hand"))
    local restored = equipment_api.restore(codec.deserialize(codec.serialize(equipment_api.snapshot(equipment))), registry)

    local world = path_world(2, 1)
    local attacker = actor_api.new("weapon.save.actor", "player", 0, 0, 7); world:place_actor(attacker)
    local target = actor_api.new("weapon.save.target", "monster", 1, 0, 7); world:place_actor(target)
    local combat = combat_registry.create(world); combat_registry.add(combat, attacker.id, 20); combat_registry.add(combat, target.id, 20)
    local service = attacks.create(world, combat, nil, registry)
    attacks.add_profile(service, attacker.id, { damage = 5, range = 1, cooldown = 0.75 })
    assert(attacks.set_equipment(service, attacker.id, restored))
    local result = attacks.try_attack(service, attacker.id, target.id)
    assert(result.success); equal(result.damage, 8); equal(result.weapon_item_id, "weapon.saved.instance")
    equal(equipment_api.get(restored, "main_hand").state.maker, "Greyhaven Smith")
end)

test("armor resolver sums equipped metadata deterministically and floors damage at one", function()
    local defs = {}
    for id, definition in pairs(item_definitions) do defs[id] = definition end
    defs.plain_tunic = { id = "plain_tunic", name = "Plain Tunic", equipment = { slots = { "torso" } } }
    local registry = item_registry_api.new(defs)
    local inventory = inventory_api.create("inventory.armor.resolve", "armor.resolve.actor", 4, registry)
    local equipment = equipment_api.create("equipment.armor.resolve", "armor.resolve.actor", registry)
    inventory_api.add_item(inventory, item_instance.new({ id = "armor.resolve.sword", type = "worn_iron_sword" }, registry))
    inventory_api.add_item(inventory, item_instance.new({ id = "armor.resolve.cap", type = "leather_cap" }, registry))
    inventory_api.add_item(inventory, item_instance.new({ id = "armor.resolve.torso", type = "patched_leather_armor" }, registry))
    assert(equipment_api.equip(equipment, inventory, "armor.resolve.sword", "main_hand"))
    assert(equipment_api.equip(equipment, inventory, "armor.resolve.cap", "head"))
    assert(equipment_api.equip(equipment, inventory, "armor.resolve.torso", "torso"))
    local resolved = armor.resolve(equipment, registry, 2)
    equal(resolved.incoming_damage, 2); equal(resolved.armor, 3); equal(resolved.final_damage, 1)
    equal(#resolved.sources, 2); equal(resolved.sources[1].slot, "head"); equal(resolved.sources[1].item_id, "armor.resolve.cap")
    equal(resolved.sources[2].slot, "torso"); equal(resolved.sources[2].item_id, "armor.resolve.torso")
    equal(equipment_api.get(equipment, "main_hand").id, "armor.resolve.sword")

    assert(equipment_api.unequip(equipment, inventory, "torso"))
    equal(armor.resolve(equipment, registry, 8).armor, 1)
    local none = armor.resolve(nil, registry, 8); equal(none.armor, 0); equal(none.final_damage, 8)

    local plain_equipment = equipment_api.create("equipment.armor.plain", "armor.plain.actor", registry)
    local plain_inventory = inventory_api.create("inventory.armor.plain", "armor.plain.actor", 1, registry)
    inventory_api.add_item(plain_inventory, item_instance.new({ id = "armor.plain.item", type = "plain_tunic" }, registry))
    assert(equipment_api.equip(plain_equipment, plain_inventory, "armor.plain.item", "torso"))
    equal(armor.resolve(plain_equipment, registry, 8).final_damage, 8)
end)

test("attack pipeline applies equipped armor once after weapon or unarmed resolution", function()
    events.clear()
    local registry = item_registry_api.new(item_definitions)
    local world = path_world(3, 2)
    local attacker = actor_api.new("armor.attack.player", "player", 0, 0, 7); world:place_actor(attacker)
    local target = actor_api.new("armor.attack.monster", "monster", 1, 0, 7); world:place_actor(target)
    local combat = combat_registry.create(world, events)
    combat_registry.add(combat, attacker.id, 20); combat_registry.add(combat, target.id, 50)
    local service = attacks.create(world, combat, events, registry)
    attacks.add_profile(service, attacker.id, { damage = 5, range = 1, cooldown = 0.75 })

    local payload
    events.on("actor_attacked", function(event) payload = event end)
    local unarmored = attacks.try_attack(service, attacker.id, target.id)
    assert(unarmored.success); equal(unarmored.raw_damage, 5); equal(unarmored.armor, 0); equal(unarmored.damage, 5)
    equal(combat_registry.get(combat, target.id).health, 45)
    attacks.update(service, 1)

    local target_inventory = inventory_api.create("inventory.armor.target", target.id, 3, registry)
    local target_equipment = equipment_api.create("equipment.armor.target", target.id, registry)
    assert(attacks.set_equipment(service, target.id, target_equipment))

    local torso = item_instance.new({ id = "armor.same.torso", type = "patched_leather_armor" }, registry)
    local cap = item_instance.new({ id = "armor.same.cap", type = "leather_cap" }, registry)
    inventory_api.add_item(target_inventory, torso); inventory_api.add_item(target_inventory, cap)
    assert(equipment_api.equip(target_equipment, target_inventory, torso.id, "torso"))
    assert(equipment_api.equip(target_equipment, target_inventory, cap.id, "head"))
    local armored = attacks.try_attack(service, attacker.id, target.id)
    assert(armored.success); equal(armored.raw_damage, 5); equal(armored.armor, 3); equal(armored.damage, 2)
    equal(armored.cooldown, unarmored.cooldown); equal(combat_registry.get(combat, target.id).health, 43)
    equal(payload.raw_damage, 5); equal(payload.armor, 3); equal(payload.damage, 2)
    equal(#armored.armor_sources, 2); equal(equipment_api.get(target_equipment, "torso").id, torso.id)
    attacks.update(service, 1)

    assert(equipment_api.unequip(target_equipment, target_inventory, "torso"))
    local after_unequip = attacks.try_attack(service, attacker.id, target.id)
    equal(after_unequip.armor, 1); equal(after_unequip.damage, 4)
    attacks.update(service, 1)
    assert(equipment_api.equip(target_equipment, target_inventory, torso.id, "torso"))

    local attacker_inventory = inventory_api.create("inventory.armor.attacker", attacker.id, 1, registry)
    local attacker_equipment = equipment_api.create("equipment.armor.attacker", attacker.id, registry)
    inventory_api.add_item(attacker_inventory, item_instance.new({ id = "armor.weapon.sword", type = "worn_iron_sword" }, registry))
    equipment_api.equip(attacker_equipment, attacker_inventory, "armor.weapon.sword", "main_hand")
    attacks.set_equipment(service, attacker.id, attacker_equipment)
    local weapon_against_armor = attacks.try_attack(service, attacker.id, target.id)
    equal(weapon_against_armor.raw_damage, 8); equal(weapon_against_armor.armor, 3); equal(weapon_against_armor.damage, 5)
    equal(combat_registry.get(combat, target.id).health, 34)
end)

test("restored armor equipment continues mitigating without derived save state", function()
    local registry = item_registry_api.new(item_definitions)
    local inventory = inventory_api.create("inventory.armor.save", "armor.save.target", 1, registry)
    local equipment = equipment_api.create("equipment.armor.save", "armor.save.target", registry)
    inventory_api.add_item(inventory, item_instance.new({ id = "armor.saved.instance", type = "patched_leather_armor" }, registry))
    assert(equipment_api.equip(equipment, inventory, "armor.saved.instance", "torso"))
    local restored = equipment_api.restore(codec.deserialize(codec.serialize(equipment_api.snapshot(equipment))), registry)

    local world = path_world(2, 1)
    local attacker = actor_api.new("armor.save.attacker", "monster", 0, 0, 7); world:place_actor(attacker)
    local target = actor_api.new("armor.save.target", "npc", 1, 0, 7); world:place_actor(target)
    local combat = combat_registry.create(world); combat_registry.add(combat, attacker.id, 20); combat_registry.add(combat, target.id, 20)
    local service = attacks.create(world, combat, nil, registry)
    attacks.add_profile(service, attacker.id, { damage = 5, range = 1, cooldown = 1 })
    assert(attacks.set_equipment(service, target.id, restored))
    local result = attacks.try_attack(service, attacker.id, target.id)
    assert(result.success); equal(result.raw_damage, 5); equal(result.armor, 2); equal(result.damage, 3)
    equal(combat_registry.get(combat, target.id).health, 17)
    equal(equipment_api.get(restored, "torso").id, "armor.saved.instance")
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
    equal(registry:get("worn_iron_sword").weapon.damage, 8)
    assert(not pcall(item_registry_api.new, { bad_weapon = { id = "bad_weapon", name = "Bad Weapon",
        equipment = { slots = { "main_hand" } }, weapon = { damage = 0 } } }))
    assert(not pcall(item_registry_api.new, { stack_weapon = { id = "stack_weapon", name = "Stack Weapon",
        stackable = true, max_stack = 20, equipment = { slots = { "main_hand" } }, weapon = { damage = 2 } } }))
    assert(not pcall(item_registry_api.new, { offhand_weapon = { id = "offhand_weapon", name = "Offhand Weapon",
        equipment = { slots = { "off_hand" } }, weapon = { damage = 2 } } }))
    equal(registry:get("patched_leather_armor").armor.defense, 2)
    assert(not pcall(item_registry_api.new, { bad_armor = { id = "bad_armor", name = "Bad Armor",
        equipment = { slots = { "torso" } }, armor = { defense = 0 } } }))
    assert(not pcall(item_registry_api.new, { stack_armor = { id = "stack_armor", name = "Stack Armor",
        stackable = true, max_stack = 20, equipment = { slots = { "torso" } }, armor = { defense = 2 } } }))
    assert(not pcall(item_registry_api.new, { unequipped_armor = { id = "unequipped_armor", name = "No Slot Armor",
        armor = { defense = 2 } } }))
    assert(not pcall(item_registry_api.new, { hand_armor = { id = "hand_armor", name = "Hand Armor",
        equipment = { slots = { "main_hand" } }, armor = { defense = 2 } } }))
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

test("equipment panel snapshots canonical slots without owning equipment state", function()
    local registry = item_registry_api.new(item_definitions)
    local inventory = inventory_api.create("inventory.ui", "ui.hero", 4, registry)
    local equipment = equipment_api.create("equipment.ui", "ui.hero", registry)
    local empty = equipment_panel.snapshot(equipment, registry)
    equal(empty.count, 8); equal(empty.occupied, 0)
    local canonical = equipment_slots.get_definitions()
    for index, entry in ipairs(empty.entries) do
        equal(entry.slot, canonical[index].id); assert(entry.item_id == nil)
    end

    inventory_api.add_item(inventory, item_instance.new({ id = "ui.sword.exact", type = "worn_iron_sword" }, registry))
    inventory_api.add_item(inventory, item_instance.new({ id = "ui.armor.exact", type = "patched_leather_armor" }, registry))
    inventory_api.add_item(inventory, item_instance.new({ id = "ui.herb.inventory", type = "healing_herb" }, registry))
    assert(equipment_api.equip(equipment, inventory, "ui.sword.exact", "main_hand"))
    assert(equipment_api.equip(equipment, inventory, "ui.armor.exact", "torso"))
    local occupied = equipment_panel.snapshot(equipment, registry)
    equal(occupied.occupied, 2)
    local by_slot = {}; for _, entry in ipairs(occupied.entries) do by_slot[entry.slot] = entry end
    equal(by_slot.main_hand.item_id, "ui.sword.exact"); equal(by_slot.main_hand.item_type, "worn_iron_sword")
    equal(by_slot.main_hand.animation, "sword_01")
    equal(by_slot.torso.item_id, "ui.armor.exact"); equal(by_slot.torso.animation, "leather_armor_01")
    for _, entry in ipairs(occupied.entries) do assert(entry.item_id ~= "ui.herb.inventory") end
    by_slot.main_hand.item_id = "ui.mutated.copy"
    equal(equipment_api.get(equipment, "main_hand").id, "ui.sword.exact")

    assert(equipment_api.unequip(equipment, inventory, "main_hand"))
    local without_sword = equipment_panel.snapshot(equipment, registry)
    equal(without_sword.occupied, 1)
    assert(equipment_api.equip(equipment, inventory, "ui.sword.exact", "main_hand"))
    local restored_icon = equipment_panel.snapshot(equipment, registry)
    assert(equipment_panel.fingerprint(without_sword) ~= equipment_panel.fingerprint(restored_icon))

    local restored = equipment_api.restore(codec.deserialize(codec.serialize(equipment_api.snapshot(equipment))), registry)
    local restored_ui = equipment_panel.snapshot(restored, registry)
    equal(restored_ui.occupied, 2)
    equal(equipment_api.get(restored, "main_hand").id, "ui.sword.exact")
    local reset = equipment_api.restore({ id = "equipment.ui", owner_id = "ui.hero", slots = {} }, registry)
    equal(equipment_panel.snapshot(reset, registry).occupied, 0)
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
    for _, command in ipairs(commands) do
        if command.id == "world.herb:1" then rendered = command.animation == "herb_01" end
    end
    assert(rendered, "world item must render from world state")
    local removed = world_items.remove(world, "world.herb")
    equal(removed.item.id, "item.world.herb"); assert(world_items.get(world, "world.herb") == nil)
    equal(#world:get_objects(1, 1, 7), 1)
end)

test("renderer culls by viewport and preserves graphical extents, roofs, and ordering", function()
    local map = { id = "render_culling", version = 1, tile_size = 32, width = 12, height = 4, placements = {
        placement("inside.ground", "grass", 2, 1, 7),
        placement("far.ground", "grass", 9, 1, 7),
        placement("overlap.wide", "wall_block", 0, 1, 7),
        placement("inside.detail", "interior", 2, 1, 7, {}, { interior_group = "test_roof" }),
        placement("inside.roof", "roof", 2, 1, 8, {}, { roof_group = "test_roof" }),
    } }
    local world = world_api.new(map, registry_api.new(definitions), state_api.new())
    local viewer = actor_api.new("render.viewer", "player", 2, 1, 7); world:place_actor(viewer)
    local viewport = viewport_api.new(2, 1, 2, 2, 0)
    local commands = renderer.build(world, viewer, 0, viewport)
    local ids = {}
    for index, command in ipairs(commands) do
        ids[command.id] = true
        if index > 1 then assert(not render_order.less(command, commands[index - 1])) end
    end
    assert(ids["inside.ground:1"], "inside object must render")
    assert(ids["render.viewer:actor"], "Actor without creature definition must retain fallback rendering")
    assert(not ids["far.ground:1"], "far object must be culled")
    assert(ids["overlap.wide:2"], "graphical footprint overlapping the viewport must render")
    assert(not ids["inside.roof:1"], "revealed roof must remain hidden after culling")

    viewer.position = position.new(5, 1, 7)
    commands = renderer.build(world, viewer, 0, viewport)
    ids = {}; for _, command in ipairs(commands) do ids[command.id] = true end
    assert(ids["inside.roof:1"], "unrevealed roof must render after culling")
end)

test("render-piece identity is stable and door animation follows authoritative state", function()
    local map = { id = "render_state", version = 1, tile_size = 32, width = 3, height = 1, placements = {
        placement("render.ground.0", "grass", 0, 0, 7), placement("render.ground.1", "grass", 1, 0, 7),
        placement("render.ground.2", "grass", 2, 0, 7),
        placement("render.door", "wood_door", 1, 0, 7, { open = false }),
    } }
    local world = world_api.new(map, registry_api.new(definitions), state_api.new())
    local viewer = actor_api.new("render.state.viewer", "player", 0, 0, 7); world:place_actor(viewer)
    local function find_door(commands)
        for _, command in ipairs(commands) do if command.id == "render.door:1" then return command end end
    end
    local closed = assert(find_door(renderer.build(world, viewer, 0)))
    equal(closed.animation, "door_closed_01"); equal(closed.object_id, "render.door")
    equal(closed.piece_index, 1)
    world:set_object_state("render.door", { open = true })
    local open = assert(find_door(renderer.build(world, viewer, 0)))
    equal(open.id, closed.id); equal(open.animation, "door_open_01")
    local fallback = render_definition.resolve({})[1]
    equal(fallback.animation, "fallback_01")
end)

test("engine test map loads its stable herb and key placements", function()
    local map = map_loader.load("data.maps.prototype")
    local registry = item_registry_api.new(item_definitions)
    local world = world_api.new(map, registry_api.new(definitions), state_api.new(), registry)
    local creature_service, _, combat, attack_service = creature_services(world)
    for _, actor_placement in ipairs(map.actor_placements) do creatures.spawn(creature_service, actor_placement) end
    equal(world_items.get(world, "world.test.herbs.01").item.id, "test.herbs.01")
    equal(world_items.get(world, "world.test.key.01").item.id, "test.key.01")
    equal(world_items.get(world, "world.test.sword.01").item.id, "test.sword.01")
    equal(world_items.get(world, "world.test.armor.01").item.id, "test.armor.01")
    equal(world:get_actor_at(12, 5, 7).id, "npc_test_villager")
    equal(world:get_actor_at(14, 10, 7).id, "monster_test_rat")
    equal(world:get_actor("monster_test_rat").type, "monster")
    equal(map.actor_placements[1].creature, "test_villager")
    equal(map.actor_placements[2].creature, "rat")
    assert(map.actor_placements[2].type == nil and map.actor_placements[2].attack == nil)
    equal(combat_registry.get(combat, "monster_test_rat").max_health, 20)
    equal(attacks.get_profile(attack_service, "monster_test_rat").damage, 2)
    local viewer = actor_api.new("player.viewer", "player", 9, 2, 7); world:place_actor(viewer)
    local commands = renderer.build(world, viewer, 0, nil, creature_service)
    local render_counts = command_diagnostics.summarize(commands)
    equal(render_counts.total, 332); equal(render_counts.ground, 284)
    equal(render_counts.world_objects, 25); equal(render_counts.multi_piece, 28)
    equal(render_counts.items, 4); equal(render_counts.actors, 3); equal(render_counts.roofs, 16)
    local fixed_viewport = viewport_api.new(viewer.position.x, viewer.position.y, 15, 10, 2)
    local fixed_commands = renderer.build(world, viewer, 0, fixed_viewport, creature_service)
    local fixed_counts = command_diagnostics.summarize(fixed_commands)
    equal(fixed_counts.total, 259); equal(fixed_counts.ground, 212)
    equal(fixed_counts.world_objects, 25); equal(fixed_counts.items, 4)
    equal(fixed_counts.actors, 2); equal(fixed_counts.roofs, 16)
    local npc_rendered, rat_rendered = false, false
    for _, command in ipairs(commands) do
        if command.id == "npc_test_villager:actor" then
            npc_rendered = true; equal(command.animation, "villager_01"); equal(command.size, 22)
        elseif command.id == "monster_test_rat:actor" then
            rat_rendered = true; equal(command.animation, "rat_01")
        end
    end
    assert(npc_rendered, "static NPC must render from actor state")
    assert(rat_rendered, "static rat must render from creature render metadata")
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

test("save v5 serializes empty and populated ownership snapshots safely", function()
    local world, empty_inventory, registry = world_item_fixture(3)
    state_api.set_flag(world.state, "greyhaven.test_dialogue_flag", true)
    world_actions.execute({ type = "set_flag", id = "greyhaven.met_test_villager", value = true },
        { world_state = world.state })
    local actor = actor_api.new("hero", "player", 1, 1, 7); actor.inventory = empty_inventory
    actor.equipment = equipment_api.create("equipment.hero", actor.id, registry)
    local quest_registry = quest_registry_api.new(quest_definitions)
    local quest_service = quests.create(quest_registry)
    assert(quests.start(quest_service, "rat_problem"))
    local empty = save_data.capture(actor, world, world.map.id, nil, quests.get_snapshot(quest_service))
    equal(empty.version, 5); equal(#empty.inventory.items, 0); assert(next(empty.equipment.slots) == nil)
    assert(empty.flags["greyhaven.test_dialogue_flag"])
    assert(empty.flags["greyhaven.met_test_villager"])
    equal(empty.quests.rat_problem.status, quest_statuses.ACTIVE)
    local old = state_api.copy(empty); old.version = 4
    local old_valid, old_reason = save_data.validate(old, world.map)
    assert(not old_valid); equal(old_reason, "unsupported_save_version")

    inventory_api.add_item(actor.inventory, item_instance.new({ id = "save.herb", type = "healing_herb",
        quantity = 8, state = { quality = "dried" } }, registry))
    inventory_api.add_item(actor.inventory, item_instance.new({ id = "save.key", type = "old_iron_key",
        state = { lock = "cellar" } }, registry))
    assert(quests.advance_objective(quest_service, "rat_problem", "investigate", 1))
    local decoded = codec.deserialize(codec.serialize(save_data.capture(actor, world, world.map.id, nil,
        quests.get_snapshot(quest_service))))
    local valid, reason = save_data.validate(decoded, world.map)
    assert(valid, reason); equal(decoded.inventory.items[1].id, "save.herb")
    assert(decoded.flags["greyhaven.test_dialogue_flag"])
    assert(decoded.flags["greyhaven.met_test_villager"])
    equal(decoded.quests.rat_problem.objectives.investigate, 1)
    equal(decoded.inventory.items[1].quantity, 8); equal(decoded.inventory.items[1].state.quality, "dried")
    equal(decoded.inventory.items[2].id, "save.key"); equal(decoded.inventory.items[2].state.lock, "cellar")
    decoded.inventory.items[1].state.quality = "changed"
    equal(inventory_api.get_item(actor.inventory, "save.herb").state.quality, "dried")
    local restored = save_data.restore_inventory(codec.deserialize(codec.serialize(save_data.capture(actor, world, world.map.id))), registry)
    equal(inventory_api.get_item(restored, "save.herb").id, "save.herb")
    equal(inventory_api.get_item(restored, "save.key").id, "save.key")
    local restored_state = state_api.new(decoded)
    assert(state_api.get_flag(restored_state, "greyhaven.test_dialogue_flag"))
    assert(state_api.get_flag(restored_state, "greyhaven.met_test_villager"))
    local restored_quests = quests.create(quest_registry, nil, save_data.restore_quests(decoded))
    equal(quests.get_status(restored_quests, "rat_problem"), quest_statuses.ACTIVE)
    equal(quests.get_objective_progress(restored_quests, "rat_problem", "investigate"), 1)
    local restored_condition_context = { world_state = restored_state, quests = restored_quests,
        quest_registry = quest_registry }
    assert(conditions.evaluate({ type = "quest_status", id = "rat_problem",
        equals = quest_statuses.ACTIVE }, restored_condition_context))
    assert(conditions.evaluate({ type = "quest_objective", quest_id = "rat_problem",
        objective_id = "investigate", complete = true }, restored_condition_context))
    assert(quests.complete(quest_service, "rat_problem"))
    local completed_save = save_data.capture(actor, world, world.map.id, nil, quests.get_snapshot(quest_service))
    local completed_quests = quests.create(quest_registry, nil, save_data.restore_quests(completed_save))
    equal(quests.get_status(completed_quests, "rat_problem"), quest_statuses.COMPLETED)
    local invalid_flags = state_api.copy(decoded); invalid_flags.flags["bad flag"] = true
    local flags_valid, flags_reason = save_data.validate(invalid_flags, world.map)
    assert(not flags_valid); equal(flags_reason, "invalid_world_flags")
    local invalid_quests = state_api.copy(decoded); invalid_quests.quests.rat_problem.status = "failed"
    local quests_valid, quests_reason = save_data.validate(invalid_quests, world.map)
    assert(not quests_valid); equal(quests_reason, "invalid_quest_state")
end)

test("save v5 restores exclusive inventory, equipment, and world ownership", function()
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
    assert(not state_api.get_flag(fresh_world.state, "greyhaven.test_dialogue_flag"))
    assert(not state_api.get_flag(fresh_world.state, "greyhaven.met_test_villager"))
    local fresh_quests = quests.create(quest_registry_api.new(quest_definitions))
    equal(quests.get_status(fresh_quests, "rat_problem"), quest_statuses.NOT_STARTED)
end)

print(string.format("%d Greyhaven Lua tests passed", count))
