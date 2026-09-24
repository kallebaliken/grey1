local interaction = require "simulation.interaction"
local transitions = require "simulation.transitions"
local M = {}

function M.register_defaults()
    interaction.register("door", function(world, actor, instance, definition, events)
        local open = not world:object_state(instance.id).open
        world:set_object_state(instance.id, { open = open }, events)
        if events then events.emit(open and "door_opened" or "door_closed", {
            actor_id = actor.id, object_id = instance.id, position = instance.position }) end
        return true
    end)
    interaction.register("stairs", function(world, actor, instance, definition, events)
        return transitions.resolve(world, actor, instance, instance.metadata.transition, events)
    end)
    interaction.register("chest", function(world, actor, instance, definition, events)
        local open = not world:object_state(instance.id).open
        world:set_object_state(instance.id, { open = open }, events)
        return true
    end)
end
return M
