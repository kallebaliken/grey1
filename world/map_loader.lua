local M = {}

function M.load(module_name)
    local map = require(module_name)
    assert(map.version == 1, "unsupported map version")
    assert(map.tile_size == 32, "Greyhaven maps currently require 32px tiles")
    assert(map.width > 0 and map.height > 0 and type(map.placements) == "table")
    local ids = {}
    for _, placement in ipairs(map.placements) do
        assert(type(placement.id) == "string", "placements require stable string ids")
        assert(not ids[placement.id], "duplicate placement id: " .. placement.id)
        ids[placement.id] = true
    end
    return map
end

return M
