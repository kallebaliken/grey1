local M = {}

local function copy(value)
    if not value then return nil end
    local result = {}
    for key, child in pairs(value) do result[key] = child end
    return result
end

local function location_for(target)
    if target.target_type == "inventory_slot" then
        return { source = "inventory", slot_index = target.index }
    end
    if target.target_type == "equipment_slot" then
        return { source = "equipment", equipment_slot = target.slot }
    end
end

local function same_location(selection, location)
    return selection.source == location.source and selection.slot_index == location.slot_index
        and selection.equipment_slot == location.equipment_slot
end

local function assign(state, target, ready)
    local location = assert(location_for(target), "selection target must be an item slot")
    state.current = {
        source = location.source,
        slot_index = location.slot_index,
        equipment_slot = location.equipment_slot,
        item_id = target.item_id,
        item_type = target.item_type,
        item_name = target.item_name,
        animation = target.animation,
    }
    state.activation_ready = ready == true
end

function M.create()
    return { current = nil, activation_ready = false }
end

function M.clear(state)
    state.current, state.activation_ready = nil, false
end

-- Returns true only when an occupied target is clicked again at the same
-- reconciled location. Empty slots clear selection.
function M.click_target(state, target)
    assert(type(state) == "table", "item selection state is required")
    local location = target and location_for(target)
    if not location or not target.item_id then M.clear(state); return false end
    if state.current and state.current.item_id == target.item_id
        and same_location(state.current, location) then
        if state.activation_ready then return true end
        state.activation_ready = true
        return false
    end
    assign(state, target, true)
    return false
end

function M.get_snapshot(state)
    return copy(state.current)
end

function M.is_selected(state, item_id)
    return state.current ~= nil and state.current.item_id == item_id
end

function M.select_target(state, target)
    if not target or not target.item_id or not location_for(target) then M.clear(state); return false end
    assign(state, target, true)
    return true
end

local function find_target(item_id, equipment_snapshot, inventory_snapshot)
    for index, entry in ipairs(inventory_snapshot and inventory_snapshot.entries or {}) do
        if entry.item_id == item_id then
            return { target_type = "inventory_slot", index = index, item_id = entry.item_id,
                item_type = entry.item_type, item_name = entry.item_name, animation = entry.animation }
        end
    end
    for _, entry in ipairs(equipment_snapshot and equipment_snapshot.entries or {}) do
        if entry.item_id == item_id then
            return { target_type = "equipment_slot", slot = entry.slot, item_id = entry.item_id,
                item_type = entry.item_type, item_name = entry.item_name, animation = entry.animation }
        end
    end
end

-- Follows the exact stable ID while it remains player-owned. Relocation requires
-- one fresh confirming click before an action; vanished/merged IDs clear.
function M.reconcile(state, equipment_snapshot, inventory_snapshot)
    if not state.current then return nil end
    local target = find_target(state.current.item_id, equipment_snapshot, inventory_snapshot)
    if not target then M.clear(state); return nil end
    local location = location_for(target)
    local moved = not same_location(state.current, location)
    assign(state, target, moved and false or state.activation_ready)
    return M.get_snapshot(state)
end

function M.target_name(selection)
    if not selection then return "none" end
    if selection.source == "equipment" then return "equipment." .. selection.equipment_slot end
    return "inventory.slot." .. selection.slot_index
end

function M.describe(selection)
    if not selection then return "none" end
    local slot = selection.source == "equipment" and selection.equipment_slot or selection.slot_index
    return string.format("%s %s | %s [%s]", selection.source, tostring(slot),
        selection.item_type, selection.item_id)
end

return M
