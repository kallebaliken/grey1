local ids = require "core.ids"
local movement = require "simulation.movement"
local combat_registry = require "combat.registry"

local M = {}
local runtimes = setmetatable({}, { __mode = "k" })

local function runtime(service)
    return assert(runtimes[service], "unknown attack service")
end

local function failure(reason, attacker_id, target_id, extra)
    local result = { success = false, reason = reason, attacker_id = attacker_id, target_id = target_id }
    for key, value in pairs(extra or {}) do result[key] = value end
    return result
end

local function snapshot(profile, cooldown_remaining)
    return { actor_id = profile.actor_id, damage = profile.damage, range = profile.range,
        cooldown = profile.cooldown, cooldown_remaining = cooldown_remaining }
end

function M.create(world, combat, events)
    assert(type(world) == "table" and type(world.get_actor) == "function", "attack service requires a world")
    assert(type(combat) == "table", "attack service requires a combat registry")
    local service = { world = world, combat = combat, events = events }
    runtimes[service] = { profiles = {}, cooldowns = {} }
    return service
end

function M.add_profile(service, actor_id, definition)
    local actor = service.world:get_actor(actor_id)
    if not actor then return nil, "unknown_actor" end
    if type(definition) ~= "table" then return nil, "invalid_profile" end
    if type(definition.damage) ~= "number" or definition.damage <= 0 or definition.damage % 1 ~= 0 then
        return nil, "invalid_damage"
    end
    if definition.range ~= 1 then return nil, "invalid_range" end
    if type(definition.cooldown) ~= "number" or definition.cooldown <= 0 then return nil, "invalid_cooldown" end
    local data = runtime(service)
    if data.profiles[actor_id] then return nil, "attack_profile_exists" end
    local profile = { actor_id = ids.require_stable(actor_id, "attack actor id"), damage = definition.damage,
        range = definition.range, cooldown = definition.cooldown }
    data.profiles[actor_id], data.cooldowns[actor_id] = profile, 0
    return snapshot(profile, 0)
end

function M.remove_profile(service, actor_id)
    local data = runtime(service)
    local profile = data.profiles[actor_id]
    if not profile then return nil, "unknown_attack_profile" end
    data.profiles[actor_id], data.cooldowns[actor_id] = nil, nil
    return snapshot(profile, 0)
end

function M.get_profile(service, actor_id)
    local data = runtime(service)
    local profile = data.profiles[actor_id]
    return profile and snapshot(profile, data.cooldowns[actor_id]) or nil
end

function M.update(service, dt)
    assert(type(dt) == "number" and dt >= 0, "attack update dt must be non-negative")
    local data = runtime(service)
    local changed = false
    for actor_id, remaining in pairs(data.cooldowns) do
        if remaining > 0 then
            data.cooldowns[actor_id] = math.max(0, remaining - dt)
            changed = true
        end
    end
    return changed
end

function M.try_attack(service, attacker_id, target_id)
    local data = runtime(service)
    local attacker = service.world:get_actor(attacker_id)
    if not attacker then return failure("unknown_attacker", attacker_id, target_id) end
    local profile = data.profiles[attacker_id]
    if not profile then return failure("cannot_attack", attacker_id, target_id) end
    local attacker_combat = combat_registry.get(service.combat, attacker_id)
    if not attacker_combat then return failure("attacker_has_no_combat_state", attacker_id, target_id) end
    if attacker_combat.dead then return failure("attacker_dead", attacker_id, target_id) end
    if not attacker.active then return failure("attacker_inactive", attacker_id, target_id) end
    if movement.is_moving(attacker) then return failure("attacker_moving", attacker_id, target_id) end
    local remaining = data.cooldowns[attacker_id]
    if remaining > 0 then return failure("cooldown", attacker_id, target_id, { cooldown_remaining = remaining }) end
    if attacker_id == target_id then return failure("invalid_target", attacker_id, target_id) end
    local target = service.world:get_actor(target_id)
    if not target then return failure("unknown_target", attacker_id, target_id) end
    local target_combat = combat_registry.get(service.combat, target_id)
    if not target_combat then return failure("target_has_no_combat_state", attacker_id, target_id) end
    if target_combat.dead then return failure("target_dead", attacker_id, target_id) end
    if attacker.position.z ~= target.position.z then return failure("different_z", attacker_id, target_id) end
    local dx = math.abs(attacker.position.x - target.position.x)
    local dy = math.abs(attacker.position.y - target.position.y)
    if dx + dy ~= profile.range then return failure("out_of_range", attacker_id, target_id) end

    if service.events then service.events.emit("actor_attacked", {
        attacker_id = attacker_id, target_id = target_id, damage = profile.damage }) end
    local damage = combat_registry.apply_damage(service.combat, target_id, profile.damage,
        { kind = "attack", attacker_id = attacker_id })
    assert(damage.success, damage.reason)
    data.cooldowns[attacker_id] = profile.cooldown
    return { success = true, attacker_id = attacker_id, target_id = target_id, damage = profile.damage,
        target_health = damage.health, target_died = damage.died, cooldown = profile.cooldown }
end

return M
