local ids = require "core.ids"
local container_api = require "items.container"
local M = {}

local inventories = setmetatable({}, { __mode = "k" })
local inventory_mt = {
    __index = function(inventory, key)
        local record = inventories[inventory]
        if record and (key == "id" or key == "owner_id") then return record[key] end
        return nil
    end,
    __newindex = function()
        error("inventory identity is read-only", 2)
    end,
}

local function record_for(inventory)
    return assert(inventories[inventory], "invalid inventory")
end

function M.create(id, owner_id, capacity, registry)
    ids.require_stable(id, "inventory id")
    ids.require_stable(owner_id, "inventory owner id")
    assert(type(registry) == "table" and type(registry.get) == "function", "inventory requires an item registry")
    local inventory = setmetatable({}, inventory_mt)
    inventories[inventory] = {
        id = id,
        owner_id = owner_id,
        container = container_api.create(id .. ".items", capacity),
        registry = registry,
    }
    return inventory
end

function M.get_container(inventory)
    return record_for(inventory).container
end

function M.add_item(inventory, item)
    local record = record_for(inventory)
    return container_api.add_item(record.container, item, record.registry)
end

function M.remove_item(inventory, item_id)
    local record = record_for(inventory)
    return container_api.remove_item(record.container, item_id, record.registry)
end

function M.get_item(inventory, item_id)
    local record = record_for(inventory)
    return container_api.get_item(record.container, item_id, record.registry)
end

function M.get_items(inventory)
    local record = record_for(inventory)
    return container_api.get_items(record.container, record.registry)
end

function M.get_item_at(inventory, index)
    local record = record_for(inventory)
    return container_api.get_item_at(record.container, index, record.registry)
end

function M.move_slot(inventory, from_index, to_index)
    local record = record_for(inventory)
    return container_api.move_slot(record.container, from_index, to_index, record.registry)
end

function M.preview_slot_drop(inventory, from_index, to_index)
    local record = record_for(inventory)
    return container_api.preview_slot_drop(record.container, from_index, to_index, record.registry)
end

function M.drop_slot(inventory, from_index, to_index)
    local record = record_for(inventory)
    return container_api.drop_slot(record.container, from_index, to_index, record.registry)
end

function M.get_count(inventory)
    return container_api.get_count(record_for(inventory).container)
end

function M.get_remaining_capacity(inventory)
    return container_api.get_remaining_capacity(record_for(inventory).container)
end

function M.is_full(inventory)
    return container_api.is_full(record_for(inventory).container)
end

function M.get_quantity(inventory, type_id)
    local record = record_for(inventory)
    record.registry:get(type_id)
    local quantity = 0
    for _, item in ipairs(container_api.get_items(record.container, record.registry)) do
        if item.type == type_id then quantity = quantity + item.quantity end
    end
    return quantity
end

function M.has_item_type(inventory, type_id)
    return M.get_quantity(inventory, type_id) > 0
end

function M.snapshot(inventory)
    local record = record_for(inventory)
    return { id = record.id, owner_id = record.owner_id, capacity = record.container.capacity,
        items = container_api.get_items(record.container, record.registry) }
end

function M.restore(snapshot, registry)
    assert(type(snapshot) == "table" and type(snapshot.items) == "table", "invalid inventory snapshot")
    ids.require_stable(snapshot.id, "inventory id")
    ids.require_stable(snapshot.owner_id, "inventory owner id")
    local inventory = setmetatable({}, inventory_mt)
    inventories[inventory] = { id = snapshot.id, owner_id = snapshot.owner_id, registry = registry,
        container = container_api.restore(snapshot.id .. ".items", snapshot.capacity, snapshot.items, registry) }
    return inventory
end

return M
