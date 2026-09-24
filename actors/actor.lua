local ids = require "core.ids"
local position = require "world.position"
local M = {}

function M.new(id, actor_type, x, y, z)
    return { id = ids.require_stable(id, "actor id"), type = actor_type,
        tile_position = position.new(x, y, z), visual_position = position.new(x, y, z),
        movement_target = nil, facing = "south", alive = true }
end

return M
