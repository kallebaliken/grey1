local M = { SIZE = 32 }
function M.coordinates(x, y) return math.floor(x / M.SIZE), math.floor(y / M.SIZE) end
function M.key(chunk_x, chunk_y, z) return string.format("%d:%d:%d", chunk_x, chunk_y, z) end
function M.tile_key(x, y) return string.format("%d:%d", x, y) end
function M.new(chunk_x, chunk_y, z) return { x = chunk_x, y = chunk_y, z = z, tiles = {} } end
return M
