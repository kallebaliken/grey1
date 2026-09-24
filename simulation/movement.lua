local position = require "world.position"
local M = {}
local FACING = { north = { 0, 1 }, south = { 0, -1 }, east = { 1, 0 }, west = { -1, 0 } }

function M.facing_offset(facing) return FACING[facing][1], FACING[facing][2] end

function M.can_move(world, actor, dx, dy)
    local from = actor.tile_position
    return not actor.movement_target and world:is_walkable(from.x + dx, from.y + dy, from.z, actor.id)
end

function M.begin(world, actor, dx, dy, events)
    if dx == 0 and dy == 0 then return false end
    if dx < 0 then actor.facing = "west" elseif dx > 0 then actor.facing = "east"
    elseif dy < 0 then actor.facing = "south" else actor.facing = "north" end
    if not M.can_move(world, actor, dx, dy) then return false end
    local from, destination = position.copy(actor.tile_position), position.offset(actor.tile_position, dx, dy, 0)
    world:move_actor(actor, destination)
    actor.tile_position = destination
    actor.movement_target = { from = from, destination = position.copy(destination), progress = 0 }
    if events then events.emit("actor_moved", { actor_id = actor.id, from = from, to = position.copy(destination) }) end
    return true
end

function M.update(actor, dt)
    local movement = actor.movement_target
    if not movement then return false end
    movement.progress = math.min(1, movement.progress + dt * actor.movement_speed)
    local from, target = movement.from, movement.destination
    actor.visual_position.x = from.x + (target.x - from.x) * movement.progress
    actor.visual_position.y = from.y + (target.y - from.y) * movement.progress
    actor.visual_position.z = target.z
    if movement.progress == 1 then actor.movement_target = nil end
    return true
end

function M.teleport(world, actor, destination)
    world:move_actor(actor, destination)
    actor.tile_position, actor.visual_position, actor.movement_target = position.copy(destination), position.copy(destination), nil
end
return M
