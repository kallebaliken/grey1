local ids = require "core.ids"
local item_instance = require "items.item_instance"
local M = {}

-- Container metadata and contents are private. Callers receive read-only scalar
-- metadata and validated copies of every item.
local storage = setmetatable({}, { __mode = "k" })
local container_mt = {
    __index = function(container, key)
        local record = storage[container]
        if record and (key == "id" or key == "capacity") then return record[key] end
        return nil
    end,
    __newindex = function()
        error("container metadata is read-only", 2)
    end,
}

local function is_integer(value)
    return type(value) == "number" and value == value and value % 1 == 0
end

local function equal(left, right, seen)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right
    for key, value in pairs(left) do
        if not equal(value, right[key], seen) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function record_for(container)
    return assert(storage[container], "invalid container")
end

function M.create(id, capacity)
    ids.require_stable(id, "container id")
    assert(is_integer(capacity) and capacity >= 0, "container capacity must be a non-negative integer")
    local container = setmetatable({}, container_mt)
    storage[container] = { id = id, capacity = capacity, items = {} }
    return container
end

function M.restore(id, capacity, items, registry)
    assert(type(items) == "table" and #items <= capacity, "container snapshot exceeds capacity")
    local container = M.create(id, capacity)
    local record, seen = record_for(container), {}
    for index, item in ipairs(items) do
        assert(not seen[item.id], "duplicate item instance id in container: " .. tostring(item.id))
        record.items[index] = item_instance.copy(item, registry)
        seen[item.id] = true
    end
    return container
end

function M.get_count(container)
    return #record_for(container).items
end

function M.get_remaining_capacity(container)
    local record = record_for(container)
    return record.capacity - #record.items
end

function M.is_full(container)
    return M.get_remaining_capacity(container) == 0
end

function M.get_item(container, item_id, registry)
    ids.require_stable(item_id, "item instance id")
    for _, item in ipairs(record_for(container).items) do
        if item.id == item_id then return item_instance.copy(item, registry) end
    end
    return nil
end

function M.get_items(container, registry)
    local result = {}
    for index, item in ipairs(record_for(container).items) do result[index] = item_instance.copy(item, registry) end
    return result
end

function M.get_item_at(container, index, registry)
    assert(is_integer(index) and index >= 1, "container index must be a positive integer")
    local item = record_for(container).items[index]
    return item and item_instance.copy(item, registry) or nil
end

function M.move_slot(container, from_index, to_index, registry)
    local record = record_for(container)
    assert(is_integer(from_index) and from_index >= 1, "source index must be a positive integer")
    assert(is_integer(to_index) and to_index >= 1 and to_index <= record.capacity,
        "target index must be within container capacity")
    local items = record.items
    if not items[from_index] then return { success = false, reason = "item_missing" } end
    local effective_to = math.min(to_index, #items)
    if from_index == effective_to then
        return { success = false, reason = "same_slot", action = "inventory_no_op",
            item_id = items[from_index].id, from = from_index, to = effective_to }
    end
    local item = table.remove(items, from_index)
    table.insert(items, effective_to, item)
    return { success = true, action = "inventory_move", item_id = item.id,
        from = from_index, to = effective_to }
end

function M.preview_slot_drop(container, from_index, to_index, registry)
    local record = record_for(container)
    if not is_integer(from_index) or not is_integer(to_index) or from_index < 1 or to_index < 1
        or to_index > record.capacity then return { valid = false, reason = "invalid_slot" } end
    local source, target = record.items[from_index], record.items[to_index]
    if not source then return { valid = false, reason = "item_missing" } end
    if from_index == to_index then return { valid = true, action = "inventory_no_op" } end
    if not target then return { valid = true, action = "inventory_move" } end
    local definition = registry:get(source.type)
    if definition.stackable and target.type == source.type and equal(target.state, source.state)
        and target.quantity < definition.max_stack then
        local transferred = math.min(source.quantity, definition.max_stack - target.quantity)
        return { valid = true, action = "inventory_merge", transferred = transferred,
            source_remainder = source.quantity - transferred }
    end
    return { valid = true, action = "inventory_swap" }
end

-- Compact ordered entries have no persistent holes. Dropping on an empty visible
-- position appends to the occupied sequence; occupied positions swap unless an
-- authoritative same-type/state stack merge can transfer quantity.
function M.drop_slot(container, from_index, to_index, registry)
    local preview = M.preview_slot_drop(container, from_index, to_index, registry)
    if not preview.valid then return { success = false, reason = preview.reason } end
    local items = record_for(container).items
    local source, target = items[from_index], items[to_index]
    if preview.action == "inventory_no_op" then
        return { success = false, reason = "same_slot", action = preview.action,
            item_id = source.id, from = from_index, to = to_index }
    end
    if preview.action == "inventory_move" then
        return M.move_slot(container, from_index, to_index, registry)
    end
    if preview.action == "inventory_swap" then
        items[from_index], items[to_index] = target, source
        return { success = true, action = preview.action, source_item_id = source.id,
            target_item_id = target.id, from = from_index, to = to_index }
    end
    local transferred = preview.transferred
    item_instance.set_quantity(target, target.quantity + transferred, registry)
    local remainder = source.quantity - transferred
    if remainder == 0 then table.remove(items, from_index)
    else item_instance.set_quantity(source, remainder, registry) end
    local target_index = to_index
    if remainder == 0 and from_index < to_index then target_index = to_index - 1 end
    return { success = true, action = preview.action, source_item_id = source.id,
        target_item_id = target.id, transferred = transferred, source_remainder = remainder,
        from = from_index, to = target_index, selected_item_id = remainder > 0 and source.id or target.id }
end

-- Returns inserted quantity plus an isolated remainder carrying the incoming ID.
-- Existing compatible stack IDs survive merges; the incoming ID survives only
-- when some or all of its quantity occupies a new slot or remains uninserted.
function M.add_item(container, incoming, registry)
    local record = record_for(container)
    local items = record.items
    local candidate = item_instance.copy(incoming, registry)
    for _, item in ipairs(items) do
        assert(item.id ~= candidate.id, "duplicate item instance id in container: " .. candidate.id)
    end

    local definition = registry:get(candidate.type)
    local requested = candidate.quantity
    local remaining = requested
    if definition.stackable then
        for _, item in ipairs(items) do
            if item.type == candidate.type and equal(item.state, candidate.state) then
                local moved = math.min(definition.max_stack - item.quantity, remaining)
                item.quantity = item.quantity + moved
                remaining = remaining - moved
                if remaining == 0 then break end
            end
        end
    end

    if remaining > 0 and #items < record.capacity then
        item_instance.set_quantity(candidate, remaining, registry)
        items[#items + 1] = candidate
        remaining = 0
    end

    local remainder = nil
    if remaining > 0 then
        remainder = item_instance.copy(candidate, registry)
        item_instance.set_quantity(remainder, remaining, registry)
    end
    return { inserted_quantity = requested - remaining, remainder = remainder }
end

function M.remove_item(container, item_id, registry)
    ids.require_stable(item_id, "item instance id")
    local items = record_for(container).items
    for index, item in ipairs(items) do
        if item.id == item_id then
            table.remove(items, index)
            return item_instance.copy(item, registry)
        end
    end
    return nil
end

return M
