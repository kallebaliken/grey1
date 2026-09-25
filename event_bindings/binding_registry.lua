local ids = require "core.ids"
local actor_types = require "actors.actor_types"
local world_actions = require "actions.world_actions"
local M = {}

local SUPPORTED_EVENTS = { actor_died = true }
local DEFINITION_FIELDS = { id = true, event = true, match = true, actions = true }
local MATCH_FIELDS = { actor_id = true, actor_type = true, actor_definition = true }
local methods = {}
methods.__index = methods
local records = setmetatable({}, { __mode = "k" })

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end

local function normalize(source, creature_registry, quest_registry)
    assert(type(source) == "table", "event binding must be a table")
    for key in pairs(source) do
        assert(DEFINITION_FIELDS[key], "unsupported event binding field: " .. tostring(key))
    end
    local definition = {
        id = ids.require_stable(source.id, "event binding id"),
        event = source.event,
        match = {},
        actions = copy(source.actions),
    }
    assert(SUPPORTED_EVENTS[source.event], "unsupported binding event: " .. tostring(source.event))
    assert(type(source.match) == "table", "event binding match must be a table")
    local match_count = 0
    for key, value in pairs(source.match) do
        assert(MATCH_FIELDS[key], "unsupported event binding match: " .. tostring(key))
        match_count = match_count + 1
        if key == "actor_id" then
            definition.match.actor_id = ids.require_stable(value, "event binding actor id")
        elseif key == "actor_type" then
            definition.match.actor_type = actor_types.require_valid(value)
        else
            local definition_id = ids.require_stable(value, "event binding creature definition")
            assert(type(creature_registry) == "table" and creature_registry:has(definition_id),
                "unknown event binding creature definition: " .. definition_id)
            definition.match.actor_definition = definition_id
        end
    end
    assert(match_count > 0, "event binding requires at least one match field")
    assert(type(source.actions) == "table" and #source.actions > 0,
        "event binding actions must not be empty")
    world_actions.validate_all(source.actions, quest_registry)
    return definition
end

function M.new(definitions, creature_registry, quest_registry)
    local registry = setmetatable({}, methods)
    records[registry] = { definitions = {}, creature_registry = creature_registry,
        quest_registry = quest_registry }
    for key, definition in pairs(definitions or {}) do
        assert(type(key) == "string" and type(definition) == "table" and definition.id == key,
            "event binding key/id mismatch")
        registry:register(definition)
    end
    return registry
end

function methods:register(definition)
    local record = records[self]
    local normalized = normalize(definition, record.creature_registry, record.quest_registry)
    assert(not record.definitions[normalized.id], "duplicate event binding: " .. normalized.id)
    record.definitions[normalized.id] = normalized
    return copy(normalized)
end

function methods:get(id)
    local definition = records[self].definitions[id]
    return definition and copy(definition) or nil
end

function methods:has(id)
    return records[self].definitions[id] ~= nil
end

function methods:get_all()
    local result = {}
    for _, definition in pairs(records[self].definitions) do result[#result + 1] = copy(definition) end
    table.sort(result, function(left, right) return left.id < right.id end)
    return result
end

function methods:get_for_event(event_name)
    local result = {}
    for _, definition in ipairs(self:get_all()) do
        if definition.event == event_name then result[#result + 1] = definition end
    end
    return result
end

return M
