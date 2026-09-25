local ids = require "core.ids"
local actor_api = require "actors.actor"
local combat_registry = require "combat.registry"
local attacks = require "combat.attacks"
local M = {}

local runtimes = setmetatable({}, { __mode = "k" })

local function runtime(service)
    return assert(runtimes[service], "unknown creature service")
end

local function integer(value)
    return type(value) == "number" and value == value and value % 1 == 0
end

function M.create(world, registry, combat, attack_service, events)
    assert(type(world) == "table" and type(world.place_actor) == "function", "creatures require a world")
    assert(type(registry) == "table" and type(registry.get) == "function", "creatures require a definition registry")
    local service = { world = world, registry = registry, combat = combat, attacks = attack_service, events = events }
    runtimes[service] = { definitions_by_actor = {} }
    return service
end

function M.spawn(service, placement)
    assert(type(placement) == "table", "creature placement must be a table")
    local actor_id = ids.require_stable(placement.id, "creature actor id")
    local definition_id = ids.require_stable(placement.creature, "creature definition reference")
    local definition = service.registry:get(definition_id)
    assert(definition, "unknown creature definition: " .. definition_id)
    assert(not definition.combat or service.combat, "creature combat metadata requires combat service")
    assert(not definition.attack or service.attacks, "creature attack metadata requires attack service")
    assert(integer(placement.x) and integer(placement.y) and integer(placement.z),
        "creature placement coordinates must be integers")
    assert(not service.world:get_actor(actor_id), "duplicate actor id: " .. actor_id)
    local tile = assert(service.world:get_tile(placement.x, placement.y, placement.z), "creature requires a tile")
    assert(not tile.actor_id, "creature tile occupied")

    local actor = actor_api.new(actor_id, definition.actor_type, placement.x, placement.y, placement.z, placement.facing)
    service.world:place_actor(actor, service.events)
    runtime(service).definitions_by_actor[actor_id] = definition_id
    if definition.combat then
        assert(combat_registry.add(service.combat, actor_id, definition.combat.max_health))
    end
    if definition.attack then
        assert(attacks.add_profile(service.attacks, actor_id, definition.attack))
    end
    return actor
end

function M.get_definition_id(service, actor_id)
    return runtime(service).definitions_by_actor[actor_id]
end

function M.get_definition_for_actor(service, actor_id)
    local definition_id = M.get_definition_id(service, actor_id)
    return definition_id and service.registry:get(definition_id) or nil
end

return M
