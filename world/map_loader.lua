-- Defold discovers Lua build dependencies from literal require calls. Keep every
-- selectable map in this registry instead of requiring a caller-provided name.
local maps = {
    ["data.maps.prototype"] = require("data.maps.prototype"),
}

local M = {}

function M.load(module_name)
    local map = assert(maps[module_name], "unknown map module: " .. tostring(module_name))
    assert(map.version == 1, "unsupported map version")
    assert(map.tile_size == 32, "Greyhaven maps currently require 32px tiles")
    assert(map.width > 0 and map.height > 0 and type(map.placements) == "table")
    local ids = {}
    for _, placement in ipairs(map.placements) do
        assert(type(placement.id) == "string", "placements require stable string ids")
        assert(not ids[placement.id], "duplicate placement id: " .. placement.id)
        ids[placement.id] = true
    end
    local item_ids = {}
    for _, placement in ipairs(map.item_placements or {}) do
        assert(type(placement.id) == "string", "world item placements require stable string ids")
        assert(not ids[placement.id], "duplicate placement id: " .. placement.id)
        assert(type(placement.item) == "table" and type(placement.item.id) == "string", "world item placements require item instances")
        assert(not item_ids[placement.item.id], "duplicate world item instance id: " .. placement.item.id)
        assert(type(placement.position) == "table", "world item placements require positions")
        ids[placement.id], item_ids[placement.item.id] = true, true
    end
    local actor_ids = {}
    for _, placement in ipairs(map.actor_placements or {}) do
        assert(type(placement.id) == "string", "actor placements require stable string ids")
        assert(not actor_ids[placement.id], "duplicate actor id: " .. placement.id)
        assert(type(placement.type) == "string" and type(placement.x) == "number"
            and type(placement.y) == "number" and type(placement.z) == "number",
            "actor placements require type and position")
        if placement.max_health ~= nil then
            assert(type(placement.max_health) == "number" and placement.max_health > 0
                and placement.max_health % 1 == 0, "actor max health must be a positive integer")
        end
        actor_ids[placement.id] = true
    end
    assert(type(map.player_max_health) == "number" and map.player_max_health > 0
        and map.player_max_health % 1 == 0, "player max health must be a positive integer")
    if map.player_inventory then
        assert(type(map.player_inventory.id) == "string" and type(map.player_inventory.owner_id) == "string",
            "player inventory requires stable identity")
        assert(type(map.player_inventory.capacity) == "number" and type(map.player_inventory.items) == "table",
            "player inventory requires capacity and items")
    end
    if map.player_equipment then
        assert(type(map.player_equipment.id) == "string" and type(map.player_equipment.owner_id) == "string"
            and type(map.player_equipment.slots) == "table", "player equipment requires identity and slots")
    end
    return map
end

return M
