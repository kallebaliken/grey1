local equipment_api = require "items.equipment"

local M = {}

local function result(target, success, reason, item)
    return {
        handled = true,
        success = success,
        action = "unequip",
        slot = target.slot,
        item_id = item and item.id or target.item_id,
        item_type = item and item.type or target.item_type,
        reason = reason,
    }
end

-- Translates a semantic UI intent into the existing authoritative transfer API.
-- The dispatcher and GUI remain read-only; Equipment owns the mutation rules.
function M.handle_intent(intent, context)
    if not intent or intent.type ~= "ui_click" or not intent.target
        or intent.target.target_type ~= "equipment_slot" then
        return { handled = false, success = false, reason = "unsupported_intent" }
    end
    local target = intent.target
    if intent.blocked then return result(target, false, "input_locked") end
    assert(type(context) == "table", "equipment UI controller requires context")
    assert(context.equipment and context.inventory, "equipment UI controller requires ownership state")
    if not equipment_api.get(context.equipment, target.slot) then
        return result(target, false, "empty_slot")
    end
    local success, item_or_reason = equipment_api.unequip(context.equipment, context.inventory,
        target.slot, context.events)
    if not success then return result(target, false, item_or_reason) end
    return result(target, true, nil, item_or_reason)
end

return M
