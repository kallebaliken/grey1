local equipment_api = require "items.equipment"
local equipment_slots = require "items.equipment_slots"

local M = {}

local LABELS = {
    head = "H", torso = "T", legs = "L", feet = "F",
    neck = "N", ring = "R", main_hand = "M", off_hand = "O",
}

local function animation_for(definition)
    return definition.render and definition.render.animation or "fallback_01"
end

function M.get_slot_ids()
    local result = {}
    for index, definition in ipairs(equipment_slots.get_definitions()) do result[index] = definition.id end
    return result
end

function M.snapshot(equipment, item_registry)
    assert(type(item_registry) == "table" and type(item_registry.get) == "function",
        "equipment panel requires an item registry")
    local result = { entries = {}, occupied = 0 }
    for _, slot_id in ipairs(M.get_slot_ids()) do
        local item = equipment_api.get(equipment, slot_id)
        local entry = { slot = slot_id, label = assert(LABELS[slot_id], "missing equipment UI label") }
        if item then
            local definition = item_registry:get(item.type)
            entry.item_id = item.id
            entry.item_type = item.type
            entry.item_name = definition.name
            entry.animation = animation_for(definition)
            result.occupied = result.occupied + 1
        end
        result.entries[#result.entries + 1] = entry
    end
    result.count = #result.entries
    return result
end

function M.fingerprint(snapshot)
    local parts = {}
    for _, entry in ipairs(snapshot.entries) do
        parts[#parts + 1] = entry.slot .. "=" .. (entry.item_id or "") .. ":" .. (entry.animation or "")
    end
    return table.concat(parts, "|")
end

function M.describe(snapshot)
    local equipped = {}
    for _, entry in ipairs(snapshot.entries) do
        if entry.item_id then
            equipped[#equipped + 1] = string.format("%s: %s [%s]", entry.slot, entry.item_type, entry.item_id)
        end
    end
    return string.format("slots %d occupied %d%s", snapshot.count, snapshot.occupied,
        #equipped > 0 and (" | " .. table.concat(equipped, ", ")) or "")
end

return M
