local position = require "world.position"
local movement = require "simulation.movement"
local M = {}

function M.resolve(world, actor, instance, transition, events)
    assert(transition, "transition object has no destination")
    local destination
    if transition.x then destination = position.new(transition.x, transition.y, transition.z)
    else destination = position.offset(actor.position, transition.dx or 0, transition.dy or 0, transition.dz or 0) end
    if not world:is_walkable(destination.x, destination.y, destination.z, actor.id) then return false, "destination_blocked" end
    local old_z = actor.position.z
    movement.teleport(world, actor, destination)
    if events then events.emit("actor_z_changed", { actor_id = actor.id, actor_type = actor.type, object_id = instance.id,
        from_z = old_z, to_z = destination.z, position = position.copy(destination) }) end
    return true
end

return M
