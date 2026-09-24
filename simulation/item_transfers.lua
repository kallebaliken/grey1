local inventory_api = require "items.inventory"
local world_items = require "world.world_items"
local M = {}

local function payload(actor_id, world_item, quantity)
    return { actor_id = actor_id, world_item_id = world_item.id, item_id = world_item.item.id,
        item_type = world_item.item.type, quantity = quantity,
        x = world_item.position.x, y = world_item.position.y, z = world_item.position.z }
end

function M.pickup(world, inventory, world_item_id, actor_id, events)
    local world_item = world_items.get(world, world_item_id)
    if not world_item then return { inserted_quantity = 0, remainder = nil }, "not_found" end
    local definition = world.item_registry:get(world_item.item.type)
    if not definition.pickupable then return { inserted_quantity = 0, remainder = world_item.item }, "not_pickupable" end

    local result = inventory_api.add_item(inventory, world_item.item)
    if result.inserted_quantity == 0 then return result, "inventory_full" end
    if result.remainder then
        world_items.set_quantity(world, world_item_id, result.remainder.quantity)
    else
        world_items.remove(world, world_item_id, events)
    end
    if events then events.emit("item_picked_up", payload(actor_id, world_item, result.inserted_quantity)) end
    return result
end

function M.drop(world, inventory, item_id, position, actor_id, events)
    local item = inventory_api.get_item(inventory, item_id)
    if not item then return nil, "not_found" end
    local world_item_id = world_items.default_id(item.id)
    world_items.can_place(world, item, position, world_item_id)
    local removed = assert(inventory_api.remove_item(inventory, item_id), "inventory item disappeared during drop")
    local placed = world_items.place(world, removed, position, world_item_id, events)
    if events then events.emit("item_dropped", payload(actor_id, placed, placed.item.quantity)) end
    return placed
end

return M
