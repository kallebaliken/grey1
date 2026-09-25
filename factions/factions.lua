local relationships = require "factions.relationships"
local M = {}

local runtimes = setmetatable({}, { __mode = "k" })

local function runtime(service)
    return assert(runtimes[service], "unknown faction service")
end

function M.create(world, registry)
    assert(type(world) == "table" and type(world.get_actor) == "function", "factions require a world")
    assert(type(registry) == "table" and type(registry.relationship) == "function",
        "factions require a faction registry")
    local service = { world = world, registry = registry }
    runtimes[service] = { actors = {} }
    return service
end

function M.associate(service, actor_id, faction_id)
    if not service.world:get_actor(actor_id) then return false, "unknown_actor" end
    if not service.registry:has(faction_id) then return false, "unknown_faction" end
    runtime(service).actors[actor_id] = faction_id
    return true
end

function M.get_actor_faction(service, actor_id)
    if not service.world:get_actor(actor_id) then return nil, "unknown_actor" end
    return runtime(service).actors[actor_id]
end

function M.relationship_between_actors(service, source_actor_id, target_actor_id)
    if not service.world:get_actor(source_actor_id) then return nil, "unknown_source_actor" end
    if not service.world:get_actor(target_actor_id) then return nil, "unknown_target_actor" end
    local associations = runtime(service).actors
    local source_faction, target_faction = associations[source_actor_id], associations[target_actor_id]
    if not source_faction or not target_faction then return relationships.NEUTRAL end
    return service.registry:relationship(source_faction, target_faction)
end

function M.are_friendly(service, source_actor_id, target_actor_id)
    return M.relationship_between_actors(service, source_actor_id, target_actor_id) == relationships.FRIENDLY
end

function M.are_neutral(service, source_actor_id, target_actor_id)
    return M.relationship_between_actors(service, source_actor_id, target_actor_id) == relationships.NEUTRAL
end

function M.are_hostile(service, source_actor_id, target_actor_id)
    return M.relationship_between_actors(service, source_actor_id, target_actor_id) == relationships.HOSTILE
end

return M
