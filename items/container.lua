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
