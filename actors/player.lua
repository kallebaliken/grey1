local actor = require "actors.actor"
local M = {}
function M.new(x, y, z)
    local player = actor.new("player", "player", x, y, z)
    player.movement_speed = 7
    return player
end
return M
