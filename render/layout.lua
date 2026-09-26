local M = {
    VIRTUAL_WIDTH = 1280,
    VIRTUAL_HEIGHT = 720,
    WORLD = { x = 0, y = 8, width = 960, height = 704 },
    SIDEBAR = { x = 960, y = 8, width = 320, height = 704 },
}

function M.physical_transform(width, height)
    assert(type(width) == "number" and width > 0 and type(height) == "number" and height > 0,
        "physical dimensions must be positive")
    local scale = math.min(width / M.VIRTUAL_WIDTH, height / M.VIRTUAL_HEIGHT)
    local scaled_width, scaled_height = M.VIRTUAL_WIDTH * scale, M.VIRTUAL_HEIGHT * scale
    return { scale = scale, x = (width - scaled_width) / 2, y = (height - scaled_height) / 2,
        width = scaled_width, height = scaled_height }
end

function M.virtual_to_physical(transform, x, y)
    return transform.x + x * transform.scale, transform.y + y * transform.scale
end

function M.physical_to_virtual(transform, x, y)
    return (x - transform.x) / transform.scale, (y - transform.y) / transform.scale
end

function M.world_scissor(transform)
    local x, y = M.virtual_to_physical(transform, M.WORLD.x, M.WORLD.y)
    return x, y, M.WORLD.width * transform.scale, M.WORLD.height * transform.scale
end

return M
