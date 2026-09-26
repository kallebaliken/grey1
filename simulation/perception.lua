local ids = require "core.ids"
local combat_registry = require "combat.registry"
local factions = require "factions.factions"
local line_of_sight = require "world.line_of_sight"
local M = {}

local runtimes = setmetatable({}, { __mode = "k" })
local function runtime(service) return assert(runtimes[service], "unknown perception service") end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end

local function validate(config)
    assert(type(config) == "table", "perception configuration must be a table")
    for key in pairs(config) do assert(key == "sight_range", "unknown perception field: " .. tostring(key)) end
    assert(type(config.sight_range) == "number" and config.sight_range > 0
        and config.sight_range % 1 == 0, "perception sight_range must be a positive integer")
    return { sight_range = config.sight_range }
end

local function living(service, actor)
    if not actor or actor.active == false then return false end
    if not service.combat then return true end
    local state = combat_registry.get(service.combat, actor.id)
    return not state or not state.dead
end

function M.create(world, combat, faction_service)
    assert(type(world) == "table" and type(world.get_actor) == "function"
        and type(world.get_actors) == "function" and type(world.blocks_sight) == "function",
        "perception requires a world")
    local service = { world = world, combat = combat, factions = faction_service }
    runtimes[service] = { configurations = {} }
    return service
end

function M.associate(service, actor_id, config)
    ids.require_stable(actor_id, "perception actor id")
    if not service.world:get_actor(actor_id) then return false, "unknown_actor" end
    runtime(service).configurations[actor_id] = validate(config)
    return true
end

function M.get_config(service, actor_id)
    local config = runtime(service).configurations[actor_id]
    return config and copy(config) or nil
end

function M.distance(observer, target)
    return math.abs(observer.position.x - target.position.x)
        + math.abs(observer.position.y - target.position.y)
end

function M.can_perceive(service, observer_id, target_id)
    if observer_id == target_id then return false, "self" end
    local observer, target = service.world:get_actor(observer_id), service.world:get_actor(target_id)
    if not observer then return false, "unknown_observer" end
    if not target then return false, "unknown_target" end
    local config = runtime(service).configurations[observer_id]
    if not config then return false, "no_perception" end
    if not living(service, observer) then return false, "observer_inactive" end
    if not living(service, target) then return false, "target_inactive" end
    if observer.position.z ~= target.position.z then return false, "different_z" end
    local distance = M.distance(observer, target)
    if distance > config.sight_range then return false, "out_of_range" end
    if not line_of_sight.is_clear(service.world, observer.position, target.position) then
        return false, "blocked"
    end
    return true, distance
end

function M.get_perceived_actors(service, observer_id)
    local result = {}
    for _, actor in ipairs(service.world:get_actors()) do
        local visible, distance = M.can_perceive(service, observer_id, actor.id)
        if visible then
            local entry = { actor_id = actor.id, distance = distance }
            if service.factions then
                entry.faction = factions.get_actor_faction(service.factions, actor.id)
                entry.relationship = factions.relationship_between_actors(service.factions, observer_id, actor.id)
            end
            result[#result + 1] = entry
        end
    end
    table.sort(result, function(left, right) return left.actor_id < right.actor_id end)
    return result
end

function M.get_awareness(service, observer_id)
    return { observer_id = observer_id, perceived = M.get_perceived_actors(service, observer_id) }
end

return M
