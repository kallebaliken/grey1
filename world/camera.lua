local M = {}
function M.new(view_width, view_height) return { width = view_width, height = view_height, x = 0, y = 0 } end
function M.follow(camera, x, y) camera.x, camera.y = x, y end
function M.project(camera, world_x, world_y, tile_size)
    return camera.width / 2 + (world_x - camera.x) * tile_size,
        camera.height / 2 + (world_y - camera.y) * tile_size
end
return M
