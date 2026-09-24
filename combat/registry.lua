local capabilities = require "actors.capabilities"
local health = require "combat.health"
local M = {}
local runtimes = setmetatable({}, { __mode = "k" })

local function states(registry)
    return assert(runtimes[registry], "unknown combat registry")
end

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}; if seen[value] then return seen[value] end
    local result = {}; seen[value] = result
    for key, entry in pairs(value) do result[copy(key, seen)] = copy(entry, seen) end
    return result
end

function M.create(world, events)
    assert(type(world) == "table" and type(world.get_actor) == "function", "combat registry requires a world")
    local registry = { world = world, events = events }
    runtimes[registry] = {}
    return registry
end

function M.add(registry, actor_id, max_health, current_health)
    local actor = registry.world:get_actor(actor_id)
    if not actor then return nil, "unknown_actor" end
    local actor_states = states(registry)
    if actor_states[actor_id] then return nil, "combat_state_exists" end
    local state = health.create(actor_id, max_health, current_health)
    actor_states[actor_id] = state
    capabilities.set(actor, "movement", function() return not health.is_dead(state) end)
    capabilities.set(actor, "interaction", function() return not health.is_dead(state) end)
    return health.snapshot(state)
end

function M.remove(registry, actor_id)
    local state = states(registry)[actor_id]
    if not state then return nil, "unknown_combat_state" end
    local actor = registry.world:get_actor(actor_id)
    if actor then
        capabilities.set(actor, "movement", nil)
        capabilities.set(actor, "interaction", nil)
    end
    states(registry)[actor_id] = nil
    return health.snapshot(state)
end

function M.get(registry, actor_id)
    local state = states(registry)[actor_id]
    return state and health.snapshot(state) or nil
end

function M.is_actor_alive(registry, actor_id)
    local state = states(registry)[actor_id]
    return state ~= nil and not health.is_dead(state)
end

function M.apply_damage(registry, actor_id, amount, context)
    local state = states(registry)[actor_id]
    if not state then return { success = false, reason = "unknown_actor", actor_id = actor_id } end
    if health.is_dead(state) then return { success = false, reason = "actor_dead", actor_id = actor_id } end
    if type(amount) ~= "number" or amount ~= amount or amount % 1 ~= 0 or amount <= 0 then
        return { success = false, reason = "invalid_damage", actor_id = actor_id }
    end
    local changed = health.damage(state, amount)
    local result = { success = true, actor_id = actor_id, damage = changed.damage,
        previous_health = changed.previous_health, health = changed.health, died = changed.died,
        context = copy(context or {}) }
    if registry.events then
        registry.events.emit("actor_damaged", { actor_id = actor_id, amount = amount,
            previous_health = changed.previous_health, health = changed.health, context = copy(context or {}) })
        if changed.died then registry.events.emit("actor_died", { actor_id = actor_id }) end
    end
    return result
end

return M
