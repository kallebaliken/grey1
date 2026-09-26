local ids = require "core.ids"
local relationships = require "factions.relationships"
local M = {}

local methods = {}
methods.__index = methods
local records = setmetatable({}, { __mode = "k" })

local function copy(value)
    local result = {}
    for key, entry in pairs(value) do result[key] = entry end
    return result
end

function M.new(definitions, authored_relationships)
    local registry = setmetatable({}, methods)
    records[registry] = { definitions = {}, relationships = {} }
    for key, definition in pairs(definitions or {}) do
        assert(type(key) == "string" and type(definition) == "table" and definition.id == key,
            "faction definition key/id mismatch")
        registry:register(definition)
    end
    local owned = records[registry]
    for source_id, targets in pairs(authored_relationships or {}) do
        assert(owned.definitions[source_id], "unknown source faction: " .. tostring(source_id))
        assert(type(targets) == "table", "faction relationships must be a table")
        owned.relationships[source_id] = {}
        for target_id, value in pairs(targets) do
            assert(owned.definitions[target_id], "unknown target faction: " .. tostring(target_id))
            owned.relationships[source_id][target_id] = relationships.require_valid(value)
        end
    end
    return registry
end

function methods:register(definition)
    assert(type(definition) == "table", "faction definition must be a table")
    local id = ids.require_stable(definition.id, "faction id")
    assert(type(definition.display_name) == "string" and definition.display_name ~= "",
        "faction display name must be non-empty")
    local owned = records[self].definitions
    assert(not owned[id], "duplicate faction definition: " .. id)
    owned[id] = { id = id, display_name = definition.display_name }
    return copy(owned[id])
end

function methods:has(id)
    return records[self].definitions[id] ~= nil
end

function methods:get(id)
    local definition = records[self].definitions[id]
    return definition and copy(definition) or nil
end

function methods:get_all()
    local result = {}
    for _, definition in pairs(records[self].definitions) do result[#result + 1] = copy(definition) end
    table.sort(result, function(left, right) return left.id < right.id end)
    return result
end

function methods:relationship(source_id, target_id)
    local owned = records[self]
    assert(owned.definitions[source_id], "unknown source faction: " .. tostring(source_id))
    assert(owned.definitions[target_id], "unknown target faction: " .. tostring(target_id))
    local authored = owned.relationships[source_id] and owned.relationships[source_id][target_id]
    if authored then return authored end
    if source_id == target_id then return relationships.FRIENDLY end
    return relationships.NEUTRAL
end

return M
