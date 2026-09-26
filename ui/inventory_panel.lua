local inventory_api = require "items.inventory"

local M = {}

M.COLUMNS = 4
M.ROWS = 4
M.VISIBLE_SLOTS = M.COLUMNS * M.ROWS

local function animation_for(definition)
    return definition.render and definition.render.animation or "fallback_01"
end

-- Isolated presentation copy in the container's authoritative item order.
function M.snapshot(inventory, item_registry)
    assert(type(item_registry) == "table" and type(item_registry.get) == "function",
        "inventory panel requires an item registry")
    local gameplay = inventory_api.snapshot(inventory)
    local result = {
        capacity = gameplay.capacity,
        occupied = #gameplay.items,
        visible_slots = M.VISIBLE_SLOTS,
        overflow = math.max(0, #gameplay.items - M.VISIBLE_SLOTS),
        entries = {},
    }
    for index, item in ipairs(gameplay.items) do
        if index > M.VISIBLE_SLOTS then break end
        local definition = item_registry:get(item.type)
        result.entries[index] = {
            slot = index, item_id = item.id, item_type = item.type,
            item_name = definition.name, quantity = item.quantity,
            show_quantity = item.quantity > 1,
            animation = animation_for(definition),
        }
    end
    return result
end

function M.fingerprint(snapshot)
    local parts = { tostring(snapshot.capacity), tostring(snapshot.occupied), tostring(snapshot.overflow) }
    for index = 1, snapshot.visible_slots do
        local entry = snapshot.entries[index]
        parts[#parts + 1] = entry and table.concat({ entry.item_id, entry.item_type,
            tostring(entry.quantity), entry.animation }, ":") or ""
    end
    return table.concat(parts, "|")
end

function M.describe(snapshot)
    local items = {}
    for _, entry in ipairs(snapshot.entries) do
        items[#items + 1] = string.format("%d: %s [%s]%s", entry.slot, entry.item_type, entry.item_id,
            entry.quantity > 1 and (" x" .. entry.quantity) or "")
    end
    local overflow = snapshot.overflow > 0 and string.format(" | +%d more", snapshot.overflow) or ""
    return string.format("slots %d/%d%s%s", snapshot.occupied, snapshot.capacity,
        #items > 0 and (" | " .. table.concat(items, ", ")) or "", overflow)
end

return M
