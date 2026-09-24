local position = require "world.position"
local state_api = require "state.world_state"
local M = { VERSION = 1 }

function M.capture(player, world_state, map_id)
    return { version = M.VERSION, map_id = map_id, player = { x = player.tile_position.x,
        y = player.tile_position.y, z = player.tile_position.z, facing = player.facing },
        objects = state_api.copy(world_state.objects), flags = state_api.copy(world_state.flags) }
end

function M.validate(data, expected_map_id)
    if type(data) ~= "table" or data.version ~= M.VERSION then return false, "unsupported_save_version" end
    if data.map_id ~= expected_map_id then return false, "wrong_map" end
    local p = data.player
    if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" or type(p.z) ~= "number" then
        return false, "invalid_player"
    end
    if type(data.objects) ~= "table" or type(data.flags) ~= "table" then return false, "invalid_world_state" end
    return true
end

function M.restore_player(player, data)
    player.tile_position = position.new(data.player.x, data.player.y, data.player.z)
    player.visual_position = position.copy(player.tile_position)
    player.movement_target, player.facing = nil, data.player.facing or "south"
end

return M
