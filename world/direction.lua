local M = {}
local OFFSETS = {
    north = { x = 0, y = 1 },
    east = { x = 1, y = 0 },
    south = { x = 0, y = -1 },
    west = { x = -1, y = 0 },
}

function M.is_valid(direction)
    return OFFSETS[direction] ~= nil
end

function M.require_valid(direction)
    assert(M.is_valid(direction), "unknown direction: " .. tostring(direction))
    return direction
end

function M.offset(direction)
    local value = assert(OFFSETS[direction], "unknown direction: " .. tostring(direction))
    return value.x, value.y
end

function M.from_delta(dx, dy)
    if dx < 0 then return "west" end
    if dx > 0 then return "east" end
    if dy < 0 then return "south" end
    if dy > 0 then return "north" end
    return nil
end

return M
