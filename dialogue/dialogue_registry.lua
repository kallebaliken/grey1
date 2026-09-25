local ids = require "core.ids"
local conditions = require "conditions.conditions"
local world_actions = require "actions.world_actions"
local M = {}

local methods = {}
methods.__index = methods
local records = setmetatable({}, { __mode = "k" })

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}; seen[value] = result
    for key, entry in pairs(value) do result[copy(key, seen)] = copy(entry, seen) end
    return result
end

local function normalize(source, quest_registry)
    assert(type(source) == "table", "dialogue definition must be a table")
    local definition = { id = ids.require_stable(source.id, "dialogue id"),
        start = ids.require_stable(source.start, "dialogue start node"), nodes = {}, node_order = {} }
    assert(type(source.nodes) == "table" and #source.nodes > 0, "dialogue requires nodes")
    for _, source_node in ipairs(source.nodes) do
        assert(type(source_node) == "table", "dialogue node must be a table")
        local node_id = ids.require_stable(source_node.id, "dialogue node id")
        assert(not definition.nodes[node_id], "duplicate dialogue node: " .. node_id)
        assert(type(source_node.text) == "string" and source_node.text ~= "", "dialogue node text must be non-empty")
        assert(type(source_node.choices) == "table" and #source_node.choices > 0,
            "dialogue node requires choices: " .. node_id)
        local node, choices = { id = node_id, text = source_node.text, choices = {} }, {}
        for _, source_choice in ipairs(source_node.choices) do
            assert(type(source_choice) == "table", "dialogue choice must be a table")
            local choice_id = ids.require_stable(source_choice.id, "dialogue choice id")
            assert(not choices[choice_id], "duplicate dialogue choice: " .. node_id .. ":" .. choice_id)
            assert(type(source_choice.text) == "string" and source_choice.text ~= "",
                "dialogue choice text must be non-empty")
            local has_next = source_choice.next ~= nil
            local closes = source_choice.close == true
            assert(has_next ~= closes, "dialogue choice requires exactly one next or close behavior")
            assert(source_choice.close == nil or source_choice.close == true, "dialogue choice close must be true")
            local choice = { id = choice_id, text = source_choice.text }
            if has_next then choice.next = ids.require_stable(source_choice.next, "dialogue next node")
            else choice.close = true end
            if source_choice.conditions ~= nil then
                assert(type(source_choice.conditions) == "table" and #source_choice.conditions > 0,
                    "dialogue choice conditions must not be empty")
                choice.conditions = copy(source_choice.conditions)
                for _, condition in ipairs(choice.conditions) do conditions.validate(condition, quest_registry) end
            end
            if source_choice.actions ~= nil then
                assert(type(source_choice.actions) == "table" and #source_choice.actions > 0,
                    "dialogue choice actions must not be empty")
                world_actions.validate_all(source_choice.actions)
                choice.actions = copy(source_choice.actions)
            end
            node.choices[#node.choices + 1], choices[choice_id] = choice, true
        end
        definition.nodes[node_id] = node
        definition.node_order[#definition.node_order + 1] = node_id
    end
    assert(definition.nodes[definition.start], "dialogue start node does not exist: " .. definition.start)
    for _, node in pairs(definition.nodes) do
        for _, choice in ipairs(node.choices) do
            assert(not choice.next or definition.nodes[choice.next],
                "dialogue choice references unknown node: " .. tostring(choice.next))
        end
    end
    return definition
end

function M.new(definitions, quest_registry)
    local registry = setmetatable({}, methods)
    records[registry] = { definitions = {}, quest_registry = quest_registry }
    for key, definition in pairs(definitions or {}) do
        assert(type(key) == "string" and type(definition) == "table" and definition.id == key,
            "dialogue definition key/id mismatch")
        registry:register(definition)
    end
    return registry
end

function methods:register(definition)
    local record = records[self]
    local normalized = normalize(definition, record.quest_registry)
    assert(not record.definitions[normalized.id], "duplicate dialogue definition: " .. normalized.id)
    record.definitions[normalized.id] = normalized
    return copy(normalized)
end

function methods:has(id) return records[self].definitions[id] ~= nil end
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

return M
