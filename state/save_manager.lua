local save_data = require "state.save_data"
local M = {}
local FILE_NAME = "engine_test"

function M.path() return sys.get_save_file("greyhaven", FILE_NAME) end
function M.save(player, world, map_id, player_combat)
    local snapshot = save_data.capture(player, world, map_id, player_combat)
    local valid = save_data.validate(snapshot, world.map)
    return valid and sys.save(M.path(), snapshot) or false
end
function M.load(map)
    local data = sys.load(M.path())
    if not next(data) then return nil, "not_found" end
    local valid, reason = save_data.validate(data, map)
    return valid and data or nil, reason
end
function M.reset() return os.remove(M.path()) end
return M
