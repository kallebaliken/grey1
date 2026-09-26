local direction = require "world.direction"
local position = require "world.position"
local capabilities = require "actors.capabilities"
local M = {}

-- Interpolation is presentation runtime keyed by actor identity; it is not Actor state.
local runtime = setmetatable({}, { __mode = "k" })

local function state_for(actor)
    local state = runtime[actor]
    if not state then
        state = { visual_position = position.copy(actor.position), target = nil, speed = 7 }
        runtime[actor] = state
    end
    return state
end

function M.configure(actor, options)
    options = options or {}
    local state = state_for(actor)
    if options.speed ~= nil then
        assert(type(options.speed) == "number" and options.speed > 0, "movement speed must be positive")
        state.speed = options.speed
    end
end

function M.facing_offset(facing)
    return direction.offset(facing)
end

function M.visual_position(actor)
    return position.copy(state_for(actor).visual_position)
end

function M.is_moving(actor)
    return state_for(actor).target ~= nil
end

function M.can_move(world, actor, dx, dy)
    local from = actor.position
    return capabilities.allows(actor, "movement") and not M.is_moving(actor)
        and world:is_walkable(from.x + dx, from.y + dy, from.z, actor.id)
end

function M.begin(world, actor, dx, dy, events)
    if dx == 0 and dy == 0 then return false end
    assert(math.abs(dx) + math.abs(dy) == 1, "actor movement must be one cardinal tile")
    if not capabilities.allows(actor, "movement") then return false end
    local facing = assert(direction.from_delta(dx, dy), "actor movement requires a direction")
    if actor.facing ~= facing then
        local previous = actor.facing
        actor.facing = facing
        if events then events.emit("actor_facing_changed", { actor_id = actor.id, actor_type = actor.type,
            from = previous, to = facing, position = position.copy(actor.position) }) end
    end
    if not M.can_move(world, actor, dx, dy) then return false end
    local from = position.copy(actor.position)
    local destination = position.offset(actor.position, dx, dy, 0)
    world:move_actor(actor, destination)
    actor.position = destination
    state_for(actor).target = { from = from, destination = position.copy(destination), progress = 0 }
    if events then events.emit("actor_moved", { actor_id = actor.id, actor_type = actor.type,
        from = from, to = position.copy(destination) }) end
    return true
end

function M.update(actor, dt)
    local state = state_for(actor)
    local movement = state.target
    if not movement then return false end
    movement.progress = math.min(1, movement.progress + dt * state.speed)
    local from, target = movement.from, movement.destination
    state.visual_position.x = from.x + (target.x - from.x) * movement.progress
    state.visual_position.y = from.y + (target.y - from.y) * movement.progress
    state.visual_position.z = target.z
    if movement.progress == 1 then state.target = nil end
    return true
end

function M.teleport(world, actor, destination)
    world:move_actor(actor, destination)
    actor.position = position.copy(destination)
    local state = state_for(actor)
    state.visual_position, state.target = position.copy(destination), nil
end

function M.reset(actor)
    runtime[actor] = { visual_position = position.copy(actor.position), target = nil, speed = 7 }
end

return M
