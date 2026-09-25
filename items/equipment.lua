local ids = require "core.ids"
local inventory_api = require "items.inventory"
local item_instance = require "items.item_instance"
local default_slots = require "items.equipment_slots"
local M = {}

local equipment_records = setmetatable({}, { __mode = "k" })
local equipment_mt = {
    __index = function(equipment, key)
        local record = equipment_records[equipment]
        if record and (key == "id" or key == "owner_id") then return record[key] end
        return nil
    end,
    __newindex = function()
        error("equipment identity is read-only", 2)
    end,
}

local function record_for(equipment)
    return assert(equipment_records[equipment], "invalid equipment")
end

local function allows(definition, slot_id)
    local policy = definition.equipment
    if not policy then return false end
    for _, allowed in ipairs(policy.slots) do if allowed == slot_id then return true end end
    return false
end

function M.create(id, owner_id, registry, slot_definitions)
    ids.require_stable(id, "equipment id")
    ids.require_stable(owner_id, "equipment owner id")
    assert(type(registry) == "table" and type(registry.get) == "function", "equipment requires an item registry")
    local source = slot_definitions or default_slots.get_definitions()
    assert(type(source) == "table", "equipment requires slot definitions")
    local slots, order = {}, {}
    for _, definition in ipairs(source) do
        local slot_id = ids.require_stable(definition.id, "equipment slot id")
        assert(slots[slot_id] == nil, "duplicate equipment slot: " .. slot_id)
        slots[slot_id] = false
        order[#order + 1] = slot_id
    end
    local equipment = setmetatable({}, equipment_mt)
    equipment_records[equipment] = { id = id, owner_id = owner_id, registry = registry, slots = slots, order = order }
    return equipment
end

function M.get(equipment, slot_id)
    local record = record_for(equipment)
    assert(record.slots[slot_id] ~= nil, "unknown equipment slot: " .. tostring(slot_id))
    local item = record.slots[slot_id]
    return item and item_instance.copy(item, record.registry) or nil
end

function M.get_items(equipment)
    local record, result = record_for(equipment), {}
    for _, slot_id in ipairs(record.order) do
        local item = record.slots[slot_id]
        if item then result[slot_id] = item_instance.copy(item, record.registry) end
    end
    return result
end

function M.is_slot_empty(equipment, slot_id)
    return M.get(equipment, slot_id) == nil
end

function M.can_equip(equipment, item, slot_id)
    local record = record_for(equipment)
    if record.slots[slot_id] == nil then return false, "unknown_slot" end
    local candidate = item_instance.copy(item, record.registry)
    if record.slots[slot_id] then return false, "slot_occupied" end
    if not allows(record.registry:get(candidate.type), slot_id) then return false, "slot_not_allowed" end
    return true
end

function M.equip(equipment, inventory, item_id, slot_id, events)
    local record = record_for(equipment)
    if inventory.owner_id ~= record.owner_id then return false, "owner_mismatch" end
    local item = inventory_api.get_item(inventory, item_id)
    if not item then return false, "item_not_found" end
    local allowed, reason = M.can_equip(equipment, item, slot_id)
    if not allowed then return false, reason end
    local removed = assert(inventory_api.remove_item(inventory, item_id), "inventory item disappeared during equip")
    record.slots[slot_id] = item_instance.copy(removed, record.registry)
    if events then events.emit("item_equipped", { equipment_id = record.id, owner_id = record.owner_id,
        item_id = removed.id, item_type = removed.type, slot = slot_id }) end
    return true, item_instance.copy(removed, record.registry)
end

function M.unequip(equipment, inventory, slot_id, events)
    local record = record_for(equipment)
    if inventory.owner_id ~= record.owner_id then return false, "owner_mismatch" end
    if record.slots[slot_id] == nil then return false, "unknown_slot" end
    local item = record.slots[slot_id]
    if not item then return false, "slot_empty" end
    local result = inventory_api.add_item(inventory, item)
    if result.inserted_quantity ~= item.quantity or result.remainder then return false, "inventory_full" end
    record.slots[slot_id] = false
    if events then events.emit("item_unequipped", { equipment_id = record.id, owner_id = record.owner_id,
        item_id = item.id, item_type = item.type, slot = slot_id }) end
    return true, item_instance.copy(item, record.registry)
end

function M.snapshot(equipment)
    local record = record_for(equipment)
    return { id = record.id, owner_id = record.owner_id, slots = M.get_items(equipment) }
end

function M.restore(snapshot, registry, slot_definitions)
    assert(type(snapshot) == "table" and type(snapshot.slots) == "table", "invalid equipment snapshot")
    local equipment = M.create(snapshot.id, snapshot.owner_id, registry, slot_definitions)
    local record = record_for(equipment)
    local seen = {}
    for slot_id, item in pairs(snapshot.slots) do
        assert(not seen[item.id], "duplicate equipped item id: " .. tostring(item.id))
        local allowed, reason = M.can_equip(equipment, item, slot_id)
        assert(allowed, reason)
        record.slots[slot_id] = item_instance.copy(item, registry)
        seen[item.id] = true
    end
    return equipment
end

return M
