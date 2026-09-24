local ids = require "core.ids"
local M = {}

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do result[copy(key, seen)] = copy(child, seen) end
    return result
end

local function is_integer(value)
    return type(value) == "number" and value == value and value % 1 == 0
end

local function require_quantity(quantity, definition)
    assert(is_integer(quantity) and quantity > 0, "item quantity must be a positive integer")
    assert(quantity <= definition.max_stack, "item quantity exceeds max_stack for " .. definition.id)
end

function M.new(data, registry)
    assert(type(data) == "table", "item instance data must be a table")
    ids.require_stable(data.id, "item instance id")
    ids.require_stable(data.type, "item type")
    local definition = registry:get(data.type)
    local quantity = data.quantity or 1
    require_quantity(quantity, definition)
    assert(data.state == nil or type(data.state) == "table", "item state must be a table")
    return {
        id = data.id,
        type = data.type,
        quantity = quantity,
        state = copy(data.state or {}),
    }
end

function M.set_quantity(instance, quantity, registry)
    local definition = registry:get(instance.type)
    require_quantity(quantity, definition)
    instance.quantity = quantity
    return instance
end

function M.remaining_capacity(instance, registry)
    return registry:get(instance.type).max_stack - instance.quantity
end

function M.copy(instance, registry)
    return M.new(instance, registry)
end

return M
