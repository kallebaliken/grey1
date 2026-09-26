local M = {
    VIRTUAL_WIDTH = 1280,
    VIRTUAL_HEIGHT = 800,
    VIRTUAL = { x = 0, y = 0, width = 1280, height = 800 },
    WORLD = { x = 0, y = 160, width = 960, height = 640 },
    BOTTOM = { x = 0, y = 0, width = 960, height = 160 },
    SIDEBAR = { x = 960, y = 0, width = 320, height = 800 },
}

local function contains(rect, x, y)
    return x >= rect.x and x < rect.x + rect.width and y >= rect.y and y < rect.y + rect.height
end

function M.is_virtual_point(x, y) return contains(M.VIRTUAL, x, y) end
function M.is_world_point(x, y) return contains(M.WORLD, x, y) end
function M.is_bottom_panel_point(x, y) return contains(M.BOTTOM, x, y) end
function M.is_sidebar_point(x, y) return contains(M.SIDEBAR, x, y) end

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
    local virtual_x = (x - transform.x) / transform.scale
    local virtual_y = (y - transform.y) / transform.scale
    if not M.is_virtual_point(virtual_x, virtual_y) then return nil end
    return virtual_x, virtual_y
end

function M.client_viewport(transform)
    return transform.x, transform.y, transform.width, transform.height
end

function M.world_viewport(transform)
    local x, y = M.virtual_to_physical(transform, M.WORLD.x, M.WORLD.y)
    return x, y, M.WORLD.width * transform.scale, M.WORLD.height * transform.scale
end

return M
