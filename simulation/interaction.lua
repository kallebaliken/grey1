local movement = require "simulation.movement"
local capabilities = require "actors.capabilities"
local M = { handlers = {} }

function M.register(kind, handler) M.handlers[kind] = handler end

function M.find_target(world, actor)
    local dx, dy = movement.facing_offset(actor.facing)
    local p = actor.position
    local objects = world:get_objects(p.x + dx, p.y + dy, p.z)
    for index = #objects, 1, -1 do
        local entry = objects[index]
        if entry.definition.interaction then return entry.instance, entry.definition end
    end
    return nil
end

function M.use(world, actor, events)
    if not capabilities.allows(actor, "interaction") then return false, "actor_dead" end
    local instance, definition = M.find_target(world, actor)
    if not instance then return false, "nothing_to_use" end
    local handler = M.handlers[definition.interaction]
    if not handler then return false, "unsupported_interaction" end
    local changed, reason = handler(world, actor, instance, definition, events)
    if events then events.emit("actor_interacted", { actor_id = actor.id, actor_type = actor.type, object_id = instance.id,
        position = instance.position, succeeded = changed == true }) end
    return changed, reason
end

return M
