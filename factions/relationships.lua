local M = {
    FRIENDLY = "friendly",
    NEUTRAL = "neutral",
    HOSTILE = "hostile",
}

local VALUES = { friendly = true, neutral = true, hostile = true }

function M.is_valid(value)
    return VALUES[value] == true
end

function M.require_valid(value)
    assert(M.is_valid(value), "unknown faction relationship: " .. tostring(value))
    return value
end

return M
