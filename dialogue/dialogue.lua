local capabilities = require "actors.capabilities"
local combat_registry = require "combat.registry"
local creatures = require "creatures.creatures"
local movement = require "simulation.movement"
local M = {}

local runtimes = setmetatable({}, { __mode = "k" })
local function runtime(service) return assert(runtimes[service], "unknown dialogue service") end
local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}; if seen[value] then return seen[value] end
    local result = {}; seen[value] = result
    for key, entry in pairs(value) do result[copy(key, seen)] = copy(entry, seen) end
    return result
end

function M.create(world, registry, creature_service, combat, events)
    assert(type(world) == "table" and type(world.get_actor) == "function", "dialogue requires a world")
    assert(type(registry) == "table" and type(registry.get) == "function", "dialogue requires a registry")
    assert(type(creature_service) == "table", "dialogue requires creature associations")
    local service = { world = world, registry = registry, creatures = creature_service,
        combat = combat, events = events }
    runtimes[service] = { session = nil }
    return service
end

local function emit(service, name, session, extra)
    if not service.events then return end
    local payload = { player_actor_id = session.player_actor_id, npc_actor_id = session.npc_actor_id,
        dialogue_id = session.dialogue_id, node_id = session.node_id }
    for key, value in pairs(extra or {}) do payload[key] = value end
    service.events.emit(name, payload)
end

function M.is_active(service) return runtime(service).session ~= nil end

function M.close(service, reason)
    local data, session = runtime(service), runtime(service).session
    if not session then return false, "no_active_dialogue" end
    data.session = nil
    emit(service, "dialogue_closed", session, { reason = reason or "closed" })
    return true
end

function M.begin(service, player_actor_id, npc_actor_id)
    local player, npc = service.world:get_actor(player_actor_id), service.world:get_actor(npc_actor_id)
    if not player then return false, "unknown_player" end
    if not npc then return false, "unknown_npc" end
    if not player.active or not capabilities.allows(player, "interaction") then return false, "player_unavailable" end
    local npc_combat = service.combat and combat_registry.get(service.combat, npc_actor_id)
    if npc_combat and npc_combat.dead then return false, "npc_dead" end
    if not npc.active or not capabilities.allows(npc, "interaction") then return false, "npc_unavailable" end
    if player.position.z ~= npc.position.z
        or math.abs(player.position.x - npc.position.x) + math.abs(player.position.y - npc.position.y) ~= 1 then
        return false, "not_adjacent"
    end
    local dx, dy = movement.facing_offset(player.facing)
    if player.position.x + dx ~= npc.position.x or player.position.y + dy ~= npc.position.y then
        return false, "not_facing"
    end
    local creature = creatures.get_definition_for_actor(service.creatures, npc_actor_id)
    if not creature or not creature.dialogue then return false, "no_dialogue" end
    local definition = service.registry:get(creature.dialogue)
    if not definition then return false, "unknown_dialogue" end
    if M.is_active(service) then M.close(service, "replaced") end
    local session = { player_actor_id = player_actor_id, npc_actor_id = npc_actor_id,
        dialogue_id = definition.id, node_id = definition.start }
    runtime(service).session = session
    emit(service, "dialogue_started", session)
    return true, M.get_current(service)
end

function M.get_current(service)
    local session = runtime(service).session
    if not session then return nil end
    local definition = assert(service.registry:get(session.dialogue_id))
    local node = assert(definition.nodes[session.node_id])
    local creature = creatures.get_definition_for_actor(service.creatures, session.npc_actor_id)
    return { player_actor_id = session.player_actor_id, npc_actor_id = session.npc_actor_id,
        dialogue_id = session.dialogue_id, node_id = session.node_id,
        speaker_name = creature.display_name or creature.id, text = node.text, choices = copy(node.choices) }
end

function M.choose(service, choice_id)
    local session = runtime(service).session
    if not session then return false, "no_active_dialogue" end
    local definition = assert(service.registry:get(session.dialogue_id))
    local node = assert(definition.nodes[session.node_id])
    local choice
    for _, candidate in ipairs(node.choices) do if candidate.id == choice_id then choice = candidate; break end end
    if not choice then return false, "invalid_choice" end
    emit(service, "dialogue_choice_selected", session, { choice_id = choice.id })
    if choice.close then return M.close(service, "choice") end
    session.node_id = choice.next
    emit(service, "dialogue_node_changed", session, { choice_id = choice.id })
    return true, M.get_current(service)
end

function M.choose_index(service, index)
    local current = M.get_current(service)
    if not current or not current.choices[index] then return false, "invalid_choice" end
    return M.choose(service, current.choices[index].id)
end

return M
