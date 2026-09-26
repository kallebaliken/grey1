local ids = require "core.ids"
local M = {}

local methods = {}
methods.__index = methods
local records = setmetatable({}, { __mode = "k" })

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end

local function normalize(source)
    assert(type(source) == "table", "quest definition must be a table")
    local definition = {
        id = ids.require_stable(source.id, "quest id"),
        title = source.title,
        objectives = {},
    }
    assert(type(source.title) == "string" and source.title ~= "", "quest title must be non-empty")
    if source.description ~= nil then
        assert(type(source.description) == "string" and source.description ~= "",
            "quest description must be non-empty")
        definition.description = source.description
    end
    assert(type(source.objectives) == "table" and #source.objectives > 0, "quest requires objectives")
    local objective_ids = {}
    for _, source_objective in ipairs(source.objectives) do
        assert(type(source_objective) == "table", "quest objective must be a table")
        local objective_id = ids.require_stable(source_objective.id, "quest objective id")
        assert(not objective_ids[objective_id], "duplicate quest objective: " .. objective_id)
        assert(type(source_objective.description) == "string" and source_objective.description ~= "",
            "quest objective description must be non-empty")
        assert(type(source_objective.target) == "number" and source_objective.target > 0
            and source_objective.target % 1 == 0, "quest objective target must be a positive integer")
        definition.objectives[#definition.objectives + 1] = {
            id = objective_id,
            description = source_objective.description,
            target = source_objective.target,
        }
        objective_ids[objective_id] = true
    end
    return definition
end

function M.new(definitions)
    local registry = setmetatable({}, methods)
    records[registry] = {}
    for key, definition in pairs(definitions or {}) do
        assert(type(key) == "string" and type(definition) == "table" and definition.id == key,
            "quest definition key/id mismatch")
        registry:register(definition)
    end
    return registry
end

function methods:register(definition)
    local normalized = normalize(definition)
    assert(not records[self][normalized.id], "duplicate quest definition: " .. normalized.id)
    records[self][normalized.id] = normalized
    return copy(normalized)
end

function methods:has(id) return records[self][id] ~= nil end
function methods:get(id)
    local definition = records[self][id]
    return definition and copy(definition) or nil
end
function methods:get_all()
    local result = {}
    for _, definition in pairs(records[self]) do result[#result + 1] = copy(definition) end
    table.sort(result, function(left, right) return left.id < right.id end)
    return result
end

return M
