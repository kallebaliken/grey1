local ids = require "core.ids"
local item_instance = require "items.item_instance"
local position_api = require "world.position"
local tile_api = require "world.tile"
local M = {}

local function require_integer(value, label)
    assert(type(value) == "number" and value == value and value % 1 == 0, label .. " must be an integer")
end

local function copy_world_item(world_item, registry)
    return {
        id = world_item.id,
        type = world_item.type,
        item = item_instance.copy(world_item.item, registry),
        position = position_api.copy(world_item.position),
    }
end

local function validate_position(world, position)
    assert(type(position) == "table", "world item position must be a table")
    require_integer(position.x, "world item x")
    require_integer(position.y, "world item y")
    require_integer(position.z, "world item z")
    assert(position.x >= 0 and position.y >= 0 and position.x < world.map.width and position.y < world.map.height,
        "world item position is outside the map")
    local tile = assert(world:get_tile(position.x, position.y, position.z), "world item requires an existing tile")
    assert(tile_api.has_ground(tile), "world item requires a ground tile")
    return tile
end

function M.default_id(item_id)
    return "world." .. ids.require_stable(item_id, "item instance id")
end

function M.can_place(world, item, position, world_item_id)
    assert(world.item_registry, "world has no item registry")
    local candidate = item_instance.copy(item, world.item_registry)
    local id = ids.require_stable(world_item_id or M.default_id(candidate.id), "world item id")
    validate_position(world, position)
    assert(not world.world_items[id], "duplicate world item id: " .. id)
    assert(not world.objects[id], "world item id conflicts with object id: " .. id)
    for _, existing in pairs(world.world_items) do
        assert(existing.item.id ~= candidate.id, "duplicate world item instance id: " .. candidate.id)
    end
    local definition = world.item_registry:get(candidate.type)
    assert(definition.stack_layer and definition.patterns, "world item type is not renderable: " .. candidate.type)
    return { id = id, item = candidate, definition = definition, position = position_api.copy(position) }
end

function M.place(world, item, position, world_item_id, events)
    local candidate = M.can_place(world, item, position, world_item_id)
    local world_item = { id = candidate.id, type = candidate.item.type,
        item = candidate.item, position = candidate.position }
    world.world_items[world_item.id] = world_item
    tile_api.insert(world:get_tile(position.x, position.y, position.z), world_item, candidate.definition)
    if events then events.emit("world_item_added", { world_item_id = world_item.id, item_id = world_item.item.id,
        item_type = world_item.item.type, quantity = world_item.item.quantity,
        x = position.x, y = position.y, z = position.z }) end
    return copy_world_item(world_item, world.item_registry)
end

function M.get(world, world_item_id)
    local world_item = world.world_items[world_item_id]
    return world_item and copy_world_item(world_item, world.item_registry) or nil
end

function M.get_all(world)
    local result = {}
    for _, world_item in pairs(world.world_items) do result[#result + 1] = copy_world_item(world_item, world.item_registry) end
    table.sort(result, function(left, right) return left.id < right.id end)
    return result
end

function M.set_quantity(world, world_item_id, quantity)
    local world_item = assert(world.world_items[world_item_id], "unknown world item: " .. tostring(world_item_id))
    item_instance.set_quantity(world_item.item, quantity, world.item_registry)
    return copy_world_item(world_item, world.item_registry)
end

function M.remove(world, world_item_id, events)
    local world_item = world.world_items[world_item_id]
    if not world_item then return nil end
    local removed = copy_world_item(world_item, world.item_registry)
    local position = world_item.position
    tile_api.remove(world:get_tile(position.x, position.y, position.z), world_item_id)
    world.world_items[world_item_id] = nil
    if events then events.emit("world_item_removed", { world_item_id = world_item.id, item_id = world_item.item.id,
        item_type = world_item.item.type, quantity = world_item.item.quantity,
        x = position.x, y = position.y, z = position.z }) end
    return removed
end

return M
