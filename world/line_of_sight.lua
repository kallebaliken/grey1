local M = {}

-- Trace between logical tile centres. Exact corner ties advance diagonally, so
-- corner-adjacent tiles are not treated as occupying the line itself.
function M.trace(x0, y0, x1, y1)
    local points = { { x = x0, y = y0 } }
    local dx, dy = math.abs(x1 - x0), math.abs(y1 - y0)
    local sx = x1 > x0 and 1 or (x1 < x0 and -1 or 0)
    local sy = y1 > y0 and 1 or (y1 < y0 and -1 or 0)
    local ix, iy = 0, 0
    while ix < dx or iy < dy do
        local horizontal = (1 + 2 * ix) * dy
        local vertical = (1 + 2 * iy) * dx
        if horizontal == vertical then
            ix, iy = ix + 1, iy + 1
        elseif horizontal < vertical then
            ix = ix + 1
        else
            iy = iy + 1
        end
        points[#points + 1] = { x = x0 + ix * sx, y = y0 + iy * sy }
    end
    return points
end

function M.is_clear(world, from, target)
    if from.z ~= target.z then return false end
    local points = M.trace(from.x, from.y, target.x, target.y)
    -- Both endpoints are visible by definition. Actor occupancy is deliberately
    -- ignored; only intervening authored world blockers participate.
    for index = 2, #points - 1 do
        local point = points[index]
        if world:blocks_sight(point.x, point.y, from.z) then return false end
    end
    return true
end

return M
