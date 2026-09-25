local direction = require "world.direction"
local movement = require "simulation.movement"
local position = require "world.position"

local M = {}
local runtimes = setmetatable({}, { __mode = "k" })

local function states(controller)
    return assert(runtimes[controller], "unknown movement controller")
end

local function integer(value)
    return type(value) == "number" and value == value and value % 1 == 0
end

local function valid_position(value)
    return type(value) == "table" and integer(value.x) and integer(value.y) and integer(value.z)
end

local function emit(controller, name, actor_id, extra)
    if not controller.events then return end
    local payload = { actor_id = actor_id }
    for key, value in pairs(extra or {}) do payload[key] = value end
    controller.events.emit(name, payload)
end

local function actor_for(controller, actor_id)
    return controller.world:get_actor(actor_id)
end

local function block(controller, actor, state, reason)
    state.status = "blocked"
    emit(controller, "actor_path_blocked", actor.id, {
        reason = reason,
        remaining_steps = #state.path - state.next_index + 1,
    })
end

function M.create(world, events)
    assert(type(world) == "table" and type(world.get_actor) == "function", "movement controller requires a world")
    local controller = { world = world, events = events }
    runtimes[controller] = {}
    return controller
end

function M.set_path(controller, actor_id, path)
    local actor = actor_for(controller, actor_id)
    if not actor then return false, "unknown_actor" end
    if type(path) ~= "table" then return false, "invalid_path" end

    local copy, previous = {}, actor.position
    for index = 1, #path do
        local step = path[index]
        if not valid_position(step) then return false, "invalid_path" end
        local dx, dy = step.x - previous.x, step.y - previous.y
        if step.z ~= previous.z then return false, "z_change" end
        if not direction.from_delta(dx, dy) then return false, "non_adjacent_step" end
        copy[index] = position.copy(step)
        previous = step
    end
    for key in pairs(path) do
        if not integer(key) or key < 1 or key > #path then return false, "invalid_path" end
    end

    local state = { path = copy, next_index = 1, status = #copy == 0 and "completed" or "moving" }
    states(controller)[actor_id] = state
    emit(controller, "actor_path_started", actor_id, { steps = #copy })
    if #copy == 0 then emit(controller, "actor_path_completed", actor_id, { position = position.copy(actor.position) }) end
    return true
end

function M.cancel(controller, actor_id)
    if not actor_for(controller, actor_id) then return false, "unknown_actor" end
    local state = states(controller)[actor_id]
    if not state or state.status ~= "moving" then return false, "not_moving" end
    state.path, state.next_index, state.status = {}, 1, "cancelled"
    emit(controller, "actor_path_cancelled", actor_id)
    return true
end

function M.update(controller, dt)
    assert(type(dt) == "number" and dt >= 0, "movement controller dt must be non-negative")
    local actor_ids = {}
    local controller_states = states(controller)
    for actor_id in pairs(controller_states) do actor_ids[#actor_ids + 1] = actor_id end
    table.sort(actor_ids)
    local changed = false
    for _, actor_id in ipairs(actor_ids) do
        local state, actor = controller_states[actor_id], actor_for(controller, actor_id)
        if actor then
            if movement.is_moving(actor) then
                movement.update(actor, dt)
                changed = true
                if not movement.is_moving(actor) and state.status == "moving" and state.next_index > #state.path then
                    state.status = "completed"
                    emit(controller, "actor_path_completed", actor_id, { position = position.copy(actor.position) })
                end
            elseif state.status == "moving" then
                local target = state.path[state.next_index]
                if not target then
                    state.status = "completed"
                    emit(controller, "actor_path_completed", actor_id, { position = position.copy(actor.position) })
                    changed = true
                else
                    local dx, dy = target.x - actor.position.x, target.y - actor.position.y
                    if target.z ~= actor.position.z or not direction.from_delta(dx, dy) then
                        block(controller, actor, state, "path_diverged")
                        changed = true
                    elseif movement.begin(controller.world, actor, dx, dy, controller.events) then
                        state.next_index = state.next_index + 1
                        changed = true
                    else
                        block(controller, actor, state, "step_blocked")
                        changed = true
                    end
                end
            end
        end
    end
    return changed
end

function M.get_status(controller, actor_id)
    if not actor_for(controller, actor_id) then return nil, "unknown_actor" end
    local state = states(controller)[actor_id]
    return state and state.status or "idle"
end

function M.has_path(controller, actor_id)
    return M.get_status(controller, actor_id) == "moving"
end

function M.get_remaining_steps(controller, actor_id)
    if not actor_for(controller, actor_id) then return nil, "unknown_actor" end
    local state = states(controller)[actor_id]
    if not state then return 0 end
    return math.max(0, #state.path - state.next_index + 1)
end

function M.get_next_target(controller, actor_id)
    if not actor_for(controller, actor_id) then return nil, "unknown_actor" end
    local state = states(controller)[actor_id]
    local target = state and state.status == "moving" and state.path[state.next_index] or nil
    return target and position.copy(target) or nil
end

return M
