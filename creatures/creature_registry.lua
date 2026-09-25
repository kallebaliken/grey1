local ids = require "core.ids"
local actor_types = require "actors.actor_types"
local M = {}

local methods = {}
methods.__index = methods
local records = setmetatable({}, { __mode = "k" })
local faction_registries = setmetatable({}, { __mode = "k" })
local dialogue_registries = setmetatable({}, { __mode = "k" })

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, entry in pairs(value) do result[copy(key, seen)] = copy(entry, seen) end
    return result
end

local function positive_integer(value)
    return type(value) == "number" and value == value and value > 0 and value % 1 == 0
end

local function normalize(source, faction_registry, dialogue_registry)
    assert(type(source) == "table", "creature definition must be a table")
    local definition = copy(source)
    definition.id = ids.require_stable(definition.id, "creature definition id")
    definition.actor_type = actor_types.require_valid(definition.actor_type)
    if definition.faction ~= nil then
        ids.require_stable(definition.faction, "creature faction id")
        assert(faction_registry and faction_registry:has(definition.faction),
            "unknown creature faction: " .. definition.faction)
    end
    if definition.dialogue ~= nil then
        ids.require_stable(definition.dialogue, "creature dialogue id")
        assert(dialogue_registry and dialogue_registry:has(definition.dialogue),
            "unknown creature dialogue: " .. definition.dialogue)
    end
    assert(definition.display_name == nil or (type(definition.display_name) == "string"
        and definition.display_name ~= ""), "creature display name must be non-empty")
    if definition.combat then
        assert(type(definition.combat) == "table" and positive_integer(definition.combat.max_health),
            "creature combat max_health must be a positive integer")
    end
    if definition.attack then
        assert(definition.combat ~= nil, "attacking creature requires combat metadata")
        assert(type(definition.attack) == "table" and positive_integer(definition.attack.damage),
            "creature attack damage must be a positive integer")
        assert(definition.attack.range == 1, "creature attack range must be one")
        assert(type(definition.attack.cooldown) == "number" and definition.attack.cooldown > 0,
            "creature attack cooldown must be positive")
    end
    if definition.perception then
        assert(type(definition.perception) == "table", "creature perception metadata must be a table")
        for key in pairs(definition.perception) do
            assert(key == "sight_range", "unknown creature perception field: " .. tostring(key))
        end
        assert(positive_integer(definition.perception.sight_range),
            "creature perception sight_range must be a positive integer")
    end
    if definition.render then
        assert(type(definition.render) == "table", "creature render metadata must be a table")
        if definition.render.color then
            assert(type(definition.render.color) == "table" and #definition.render.color == 4,
                "creature render color must have four channels")
            for _, channel in ipairs(definition.render.color) do
                assert(type(channel) == "number" and channel >= 0 and channel <= 1,
                    "creature render color channels must be between zero and one")
            end
        end
        assert(definition.render.size == nil or (type(definition.render.size) == "number"
            and definition.render.size > 0), "creature render size must be positive")
    end
    return definition
end

function M.new(definitions, faction_registry, dialogue_registry)
    local registry = setmetatable({}, methods)
    records[registry] = {}
    faction_registries[registry] = faction_registry
    dialogue_registries[registry] = dialogue_registry
    for key, definition in pairs(definitions or {}) do
        assert(type(key) == "string" and definition.id == key, "creature definition key/id mismatch")
        registry:register(definition)
    end
    return registry
end

function methods:register(definition)
    local normalized = normalize(definition, faction_registries[self], dialogue_registries[self])
    assert(not records[self][normalized.id], "duplicate creature definition: " .. normalized.id)
    records[self][normalized.id] = normalized
    return copy(normalized)
end

function methods:has(id)
    return records[self][id] ~= nil
end

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
