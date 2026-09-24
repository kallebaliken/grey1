local ids = require "core.ids"
local actor_types = require "actors.actor_types"
local position = require "world.position"
local direction = require "world.direction"
local M = {}

local function require_integer(value, label)
    assert(type(value) == "number" and value == value and value % 1 == 0, label .. " must be an integer")
end

function M.new(id, actor_type, x, y, z, facing)
    require_integer(x, "actor x"); require_integer(y, "actor y"); require_integer(z, "actor z")
    return { id = ids.require_stable(id, "actor id"), type = actor_types.require_valid(actor_type),
        position = position.new(x, y, z), facing = direction.require_valid(facing or "south"), active = true }
end

function M.snapshot(actor)
    return { id = actor.id, type = actor.type, position = position.copy(actor.position),
        facing = actor.facing, active = actor.active }
end

return M
