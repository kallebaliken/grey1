local save_data = require "state.save_data"
local M = {}
local FILE_NAME = "engine_test"

function M.path() return sys.get_save_file("greyhaven", FILE_NAME) end
function M.save(player, world_state, map_id)
    return sys.save(M.path(), save_data.capture(player, world_state, map_id))
end
function M.load(map_id)
    local data = sys.load(M.path())
    if not next(data) then return nil, "not_found" end
    local valid, reason = save_data.validate(data, map_id)
    return valid and data or nil, reason
end
function M.reset() return os.remove(M.path()) end
return M
