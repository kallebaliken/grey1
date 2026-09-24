local ids = require "core.ids"
local M = {}

local methods = {}
methods.__index = methods
local registry_definitions = setmetatable({}, { __mode = "k" })

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

local function normalize(key, source)
    assert(type(source) == "table", "item definition must be a table: " .. tostring(key))
    ids.require_stable(key, "item definition key")
    assert(source.id == key, "item definition key/id mismatch: " .. key)
    assert(type(source.name) == "string" and source.name ~= "", "item needs a name: " .. key)
    assert(source.stackable == nil or type(source.stackable) == "boolean", "item stackable must be boolean: " .. key)
    assert(source.weight == nil or (type(source.weight) == "number" and source.weight >= 0), "item weight must be non-negative: " .. key)

    local definition = copy(source)
    definition.stackable = definition.stackable == true
    if definition.stackable then
        definition.max_stack = definition.max_stack or 99
        assert(is_integer(definition.max_stack) and definition.max_stack > 1, "stackable item needs max_stack greater than one: " .. key)
    else
        assert(definition.max_stack == nil or definition.max_stack == 1, "non-stackable item max_stack must be one: " .. key)
        definition.max_stack = 1
    end
    definition.weight = definition.weight or 0
    definition.tags = definition.tags or {}
    assert(type(definition.tags) == "table", "item tags must be a table: " .. key)
    for index, tag in ipairs(definition.tags) do
        assert(type(tag) == "string" and tag ~= "", "item tag must be a non-empty string: " .. key .. "[" .. index .. "]")
    end
    return definition
end

function M.new(definitions)
    assert(type(definitions) == "table", "item definitions must be a table")
    local self = setmetatable({}, methods)
    local owned = {}
    for id, definition in pairs(definitions) do owned[id] = normalize(id, definition) end
    registry_definitions[self] = owned
    return self
end

-- Return a copy so definitions remain immutable from the perspective of callers.
function methods:get(id)
    local definition = assert(registry_definitions[self][id], "unknown item type: " .. tostring(id))
    return copy(definition)
end

function methods:has(id)
    return registry_definitions[self][id] ~= nil
end

return M
