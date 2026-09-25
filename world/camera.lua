local M = {}
M.DEFAULT_ZOOM = 2

local function valid_zoom(zoom)
    return type(zoom) == "number" and zoom >= 1 and zoom <= 3 and zoom % 1 == 0
end

function M.new(view_width, view_height, zoom)
    zoom = zoom or M.DEFAULT_ZOOM
    assert(valid_zoom(zoom), "camera zoom must be an integer from 1 to 3")
    return { width = view_width, height = view_height, x = 0, y = 0, zoom = zoom }
end
function M.follow(camera, x, y) camera.x, camera.y = x, y end
function M.project(camera, world_x, world_y, tile_size)
    local display_tile_size = tile_size * camera.zoom
    return camera.width / 2 + (world_x - camera.x) * display_tile_size,
        camera.height / 2 + (world_y - camera.y) * display_tile_size
end
function M.scale_pixels(camera, pixels) return pixels * camera.zoom end
function M.visible_tiles(camera, tile_size)
    local display_tile_size = tile_size * camera.zoom
    return camera.width / display_tile_size, camera.height / display_tile_size
end
return M
