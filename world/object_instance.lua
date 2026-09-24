local ids = require "core.ids"
local position = require "world.position"
local state_api = require "state.world_state"
local M = {}

function M.new(placement)
    ids.require_stable(placement.id, "object id")
    return { id = placement.id, type = placement.type, position = position.new(placement.x, placement.y, placement.z),
        variant = placement.variant or 1, initial_state = state_api.copy(placement.state or {}), metadata = state_api.copy(placement.metadata or {}) }
end

function M.state(instance, world_state)
    local result = state_api.copy(instance.initial_state)
    for key, value in pairs(state_api.get_object(world_state, instance.id) or {}) do result[key] = state_api.copy(value) end
    return result
end

return M
