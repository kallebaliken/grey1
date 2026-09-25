local M = {}
local TYPES = { player = true, npc = true, monster = true }

function M.is_valid(actor_type)
    return TYPES[actor_type] == true
end

function M.require_valid(actor_type)
    assert(M.is_valid(actor_type), "unknown actor type: " .. tostring(actor_type))
    return actor_type
end

return M
