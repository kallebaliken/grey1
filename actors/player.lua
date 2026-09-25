local actor = require "actors.actor"
local M = {}
function M.new(x, y, z)
    return actor.new("player", "player", x, y, z)
end
return M
