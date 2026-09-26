local creatures = require "creatures.creatures"
local world_actions = require "actions.world_actions"
local M = {}

local runtimes = setmetatable({}, { __mode = "k" })
local function runtime(service) return assert(runtimes[service], "unknown event binding service") end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end

local function actor_for_event(service, event_name, payload)
    if event_name ~= "actor_died" then return nil end
    return payload.actor_id and service.world:get_actor(payload.actor_id) or nil
end

local function matches(service, definition, event_name, payload)
    local actor = actor_for_event(service, event_name, payload)
    if not actor then return false end
    local match = definition.match
    if match.actor_id and actor.id ~= match.actor_id then return false end
    if match.actor_type and actor.type ~= match.actor_type then return false end
    if match.actor_definition
        and creatures.get_definition_id(service.creatures, actor.id) ~= match.actor_definition then return false end
    return true
end

function M.handle(service, event_name, payload)
    local results = {}
    for _, definition in ipairs(service.registry:get_for_event(event_name)) do
        if matches(service, definition, event_name, payload or {}) then
            local action_results, failure = world_actions.execute_all(definition.actions,
                service.action_context, service.events)
            results[#results + 1] = {
                binding_id = definition.id,
                source_event = event_name,
                matched = true,
                success = action_results ~= nil,
                action_results = action_results,
                failure = failure,
            }
        end
    end
    runtime(service).last_results = copy(results)
    return results
end

function M.create(registry, events, world, creature_service, action_context)
    assert(type(registry) == "table" and type(registry.get_for_event) == "function",
        "event bindings require a registry")
    assert(type(events) == "table" and type(events.on) == "function" and type(events.off) == "function",
        "event bindings require an event bus")
    assert(type(world) == "table" and type(world.get_actor) == "function", "event bindings require a world")
    assert(type(creature_service) == "table", "event bindings require creature associations")
    local service = { registry = registry, events = events, world = world,
        creatures = creature_service, action_context = action_context }
    local callback = function(payload) M.handle(service, "actor_died", payload) end
    runtimes[service] = { callback = callback, last_results = {} }
    events.on("actor_died", callback)
    return service
end

function M.destroy(service)
    local data = runtime(service)
    service.events.off("actor_died", data.callback)
    runtimes[service] = nil
end

function M.get_last_results(service)
    return copy(runtime(service).last_results)
end

return M
