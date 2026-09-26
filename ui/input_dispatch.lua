local layout = require "render.layout"
local client_layout = require "ui.client_layout"

local M = {}

local function enrich(target, entry)
    if entry then
        target.item_id = entry.item_id
        target.item_type = entry.item_type
    end
    return target
end

local function equipment_entry(snapshot, slot)
    for _, entry in ipairs(snapshot and snapshot.entries or {}) do
        if entry.slot == slot then return entry end
    end
end

function M.hit_test(x, y, context)
    if layout.classify_virtual_point(x, y) ~= "sidebar" then return nil end
    context = context or {}
    for _, slot in ipairs(client_layout.EQUIPMENT_ORDER) do
        if client_layout.contains(client_layout.EQUIPMENT_SLOTS[slot], x, y) then
            return enrich({ region = "sidebar", target_type = "equipment_slot", slot = slot },
                equipment_entry(context.equipment, slot))
        end
    end
    for index, rect in ipairs(client_layout.INVENTORY_SLOTS) do
        if client_layout.contains(rect, x, y) then
            return enrich({ region = "sidebar", target_type = "inventory_slot", index = index },
                context.inventory and context.inventory.entries[index])
        end
    end
    return nil
end

function M.resolve_physical(transform, physical_x, physical_y, context)
    local x, y = layout.physical_to_virtual(transform, physical_x, physical_y)
    if not x then
        return { physical_x = physical_x, physical_y = physical_y, region = "outside" }
    end
    return { physical_x = physical_x, physical_y = physical_y, virtual_x = x, virtual_y = y,
        region = layout.classify_virtual_point(x, y), target = M.hit_test(x, y, context) }
end

function M.click(pointer, dialogue_active)
    if not pointer.target then return nil, false end
    return { type = "ui_click", target = pointer.target, blocked = dialogue_active == true }, true
end

function M.target_name(target)
    if not target then return "none" end
    if target.target_type == "equipment_slot" then return "equipment." .. target.slot end
    return "inventory.slot." .. target.index
end

function M.describe_target(target)
    local name = M.target_name(target)
    if target and target.item_id then
        return string.format("%s [%s %s]", name, target.item_type, target.item_id)
    end
    return name
end

return M
