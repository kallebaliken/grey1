local M = {}

function M.new(x, y, z)
    assert(type(x) == "number" and type(y) == "number" and type(z) == "number")
    return { x = x, y = y, z = z }
end

function M.key(x, y, z)
    return string.format("%d:%d:%d", x, y, z)
end

function M.equals(a, b)
    return a.x == b.x and a.y == b.y and a.z == b.z
end

function M.copy(value) return M.new(value.x, value.y, value.z) end

function M.offset(value, dx, dy, dz)
    return M.new(value.x + dx, value.y + dy, value.z + dz)
end

function M.world_to_screen(value, origin, tile_size)
    return (value.x - origin.x) * tile_size, (value.y - origin.y) * tile_size
end

function M.screen_to_world(screen_x, screen_y, origin, tile_size, z)
    return M.new(math.floor(screen_x / tile_size + origin.x), math.floor(screen_y / tile_size + origin.y), z)
end

return M
