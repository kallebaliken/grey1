local M = { THRESHOLD = 6 }

local function copy(value)
    if not value then return nil end
    local result = {}
    for key, child in pairs(value) do result[key] = child end
    return result
end

local function source_from(target)
    if target.target_type == "inventory_slot" then
        return { type = "inventory_slot", index = target.index, item_id = target.item_id,
            item_type = target.item_type, animation = target.animation }
    end
    if target.target_type == "equipment_slot" then
        return { type = "equipment_slot", slot = target.slot, item_id = target.item_id,
            item_type = target.item_type, animation = target.animation }
    end
end

function M.create()
    return { candidate = nil, active = false }
end

function M.cancel(state)
    state.candidate, state.active, state.pointer_x, state.pointer_y = nil, false, nil, nil
    state.target, state.target_valid, state.target_reason = nil, false, nil
    state.target_action = nil
end

function M.pointer_down(state, target, x, y)
    M.cancel(state)
    if not target or not target.item_id then return false end
    local source = source_from(target)
    if not source then return false end
    state.candidate = { source = source, start_x = x, start_y = y }
    state.pointer_x, state.pointer_y = x, y
    return true
end

function M.pointer_move(state, x, y, target, validation)
    if not state.candidate then return false end
    state.pointer_x, state.pointer_y, state.target = x, y, copy(target)
    state.target_valid = validation and validation.valid == true or false
    state.target_reason = validation and validation.reason or nil
    state.target_action = validation and validation.action or nil
    if not state.active and x and y then
        local dx, dy = x - state.candidate.start_x, y - state.candidate.start_y
        if dx * dx + dy * dy >= M.THRESHOLD * M.THRESHOLD then state.active = true end
    end
    return state.active
end

function M.is_pending(state) return state.candidate ~= nil end
function M.is_active(state) return state.active == true end
function M.get_source(state) return state.candidate and copy(state.candidate.source) or nil end

function M.release(state)
    if not state.candidate then return nil, "cancelled" end
    local source, target, active = copy(state.candidate.source), copy(state.target), state.active
    local item_id, item_type = source.item_id, source.item_type
    M.cancel(state)
    if not active then return nil, "click" end
    if not target then return { type = "drop_item", item_id = item_id, item_type = item_type,
        source = source }, "outside" end
    return { type = "drop_item", item_id = item_id, item_type = item_type,
        source = source, target = target }
end

function M.get_snapshot(state)
    if not state.candidate then return nil end
    local source = state.candidate.source
    return { active = state.active, item_id = source.item_id, item_type = source.item_type,
        animation = source.animation, source = copy(source), target = copy(state.target),
        pointer_x = state.pointer_x, pointer_y = state.pointer_y,
        target_valid = state.target_valid, target_reason = state.target_reason,
        target_action = state.target_action }
end

function M.reconcile(state, equipment_snapshot, inventory_snapshot)
    if not state.candidate then return true end
    local source = state.candidate.source
    if source.type == "inventory_slot" then
        local entry = inventory_snapshot and inventory_snapshot.entries[source.index]
        if entry and entry.item_id == source.item_id then return true end
    elseif source.type == "equipment_slot" then
        for _, entry in ipairs(equipment_snapshot and equipment_snapshot.entries or {}) do
            if entry.slot == source.slot and entry.item_id == source.item_id then return true end
        end
    end
    M.cancel(state)
    return false
end

function M.describe(snapshot)
    if not snapshot then return "none" end
    local source = snapshot.source.type == "equipment_slot"
        and ("equipment." .. snapshot.source.slot) or ("inventory.slot." .. snapshot.source.index)
    local target = snapshot.target and (snapshot.target.target_type == "equipment_slot"
        and ("equipment." .. snapshot.target.slot) or snapshot.target.target_type) or "invalid"
    return string.format("%s | %s | %s -> %s | valid: %s", snapshot.active and "active" or "candidate",
        snapshot.item_id, source, target, snapshot.target_valid and "yes" or "no")
end

return M
