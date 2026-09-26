local equipment_api = require "items.equipment"
local inventory_api = require "items.inventory"
local equipment_slots = require "items.equipment_slots"

local M = {}

local function unequip_result(target, success, reason, item)
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

local function equip_result(target, success, reason, slot, item)
    return {
        handled = true,
        success = success,
        action = "equip",
        slot = slot,
        index = target.index,
        item_id = item and item.id or target.item_id,
        item_type = item and item.type or target.item_type,
        reason = reason,
    }
end

local function compatible_empty_slot(equipment, definition)
    local allowed = {}
    for _, slot in ipairs(definition.equipment.slots) do allowed[slot] = true end
    for _, canonical in ipairs(equipment_slots.get_definitions()) do
        if allowed[canonical.id] and equipment_api.is_slot_empty(equipment, canonical.id) then
            return canonical.id
        end
    end
    return nil
end

-- Translates semantic Equipment and Inventory intents into authoritative transfer APIs.
-- The dispatcher and GUI remain read-only; Inventory/Container and Equipment own mutation rules.
function M.handle_intent(intent, context)
    if not intent or intent.type ~= "ui_click" or not intent.target then
        return { handled = false, success = false, reason = "unsupported_intent" }
    end
    local target = intent.target
    if target.target_type ~= "equipment_slot" and target.target_type ~= "inventory_slot" then
        return { handled = false, success = false, reason = "unsupported_intent" }
    end
    local action = target.target_type == "equipment_slot" and "unequip" or "equip"
    if intent.blocked then
        if action == "unequip" then return unequip_result(target, false, "input_locked") end
        return equip_result(target, false, "input_locked")
    end
    assert(type(context) == "table", "equipment UI controller requires context")
    assert(context.equipment and context.inventory, "equipment UI controller requires ownership state")
    if action == "unequip" then
        if not equipment_api.get(context.equipment, target.slot) then
            return unequip_result(target, false, "empty_slot")
        end
        local success, item_or_reason = equipment_api.unequip(context.equipment, context.inventory,
            target.slot, context.events)
        if not success then return unequip_result(target, false, item_or_reason) end
        return unequip_result(target, true, nil, item_or_reason)
    end

    if not target.item_id then return equip_result(target, false, "empty_slot") end
    assert(context.item_registry, "inventory equip requires an item registry")
    local item = inventory_api.get_item(context.inventory, target.item_id)
    if not item then return equip_result(target, false, "empty_slot") end
    local definition = context.item_registry:get(item.type)
    if not definition.equipment then return equip_result(target, false, "not_equippable", nil, item) end
    local slot = compatible_empty_slot(context.equipment, definition)
    if not slot then return equip_result(target, false, "slot_occupied", nil, item) end
    local success, item_or_reason = equipment_api.equip(context.equipment, context.inventory,
        item.id, slot, context.events)
    if not success then return equip_result(target, false, item_or_reason, slot, item) end
    return equip_result(target, true, nil, slot, item_or_reason)
end

local function definition_allows(definition, slot)
    if not definition.equipment then return false end
    for _, allowed in ipairs(definition.equipment.slots) do
        if allowed == slot then return true end
    end
    return false
end

function M.validate_drop(intent, context)
    if not intent or intent.type ~= "drop_item" or not intent.source then
        return { valid = false, reason = "cancelled" }
    end
    if not intent.target then return { valid = false, reason = "outside" } end
    if intent.source.type == "inventory_slot" then
        local item = inventory_api.get_item_at(context.inventory, intent.source.index)
        if not item or item.id ~= intent.item_id then return { valid = false, reason = "item_missing" } end
        if intent.target.target_type == "inventory_slot" then
            local preview = inventory_api.preview_slot_drop(context.inventory,
                intent.source.index, intent.target.index)
            preview.item = item
            return preview
        end
        if intent.target.target_type ~= "equipment_slot" then
            return { valid = false, reason = "unsupported_drop" }
        end
        local definition = context.item_registry:get(item.type)
        if not definition_allows(definition, intent.target.slot) then
            return { valid = false, reason = "incompatible_slot" }
        end
        if not equipment_api.is_slot_empty(context.equipment, intent.target.slot) then
            return { valid = false, reason = "slot_occupied" }
        end
        return { valid = true, action = "equip", item = item, slot = intent.target.slot }
    end
    if intent.source.type == "equipment_slot" then
        local item = equipment_api.get(context.equipment, intent.source.slot)
        if not item or item.id ~= intent.item_id then return { valid = false, reason = "item_missing" } end
        if intent.target.target_type ~= "inventory_panel"
            and intent.target.target_type ~= "inventory_slot" then
            return { valid = false, reason = "unsupported_drop" }
        end
        return { valid = true, action = "unequip", item = item, slot = intent.source.slot }
    end
    return { valid = false, reason = "unsupported_drop" }
end

function M.handle_drop(intent, context)
    local validation = M.validate_drop(intent, context)
    if not validation.valid then
        return { handled = true, success = false, action = "drop", item_id = intent and intent.item_id,
            reason = validation.reason }
    end
    local success, item_or_reason
    if validation.action and validation.action:match("^inventory_") then
        local inventory_result = inventory_api.drop_slot(context.inventory,
            intent.source.index, intent.target.index)
        inventory_result.handled = true
        return inventory_result
    elseif validation.action == "equip" then
        success, item_or_reason = equipment_api.equip(context.equipment, context.inventory,
            validation.item.id, validation.slot, context.events)
    else
        success, item_or_reason = equipment_api.unequip(context.equipment, context.inventory,
            validation.slot, context.events)
    end
    if not success then
        return { handled = true, success = false, action = validation.action,
            item_id = validation.item.id, reason = item_or_reason,
            target_slot = validation.action == "equip" and validation.slot or nil }
    end
    return { handled = true, success = true, action = validation.action,
        item_id = item_or_reason.id, item_type = item_or_reason.type,
        target_slot = validation.action == "equip" and validation.slot or nil,
        source_slot = validation.action == "unequip" and validation.slot or nil }
end

return M
