local M = {}

local KNOWN = {
    fallback_01 = true,
    grass_01 = true, dirt_01 = true, wood_floor_01 = true, basement_floor_01 = true, interior_01 = true,
    wall_01 = true, door_closed_01 = true, door_open_01 = true, table_01 = true,
    chest_01 = true, stairs_01 = true, roof_01 = true,
    player_01 = true, villager_01 = true, rat_01 = true,
    herb_01 = true, key_01 = true, sword_01 = true, leather_armor_01 = true,
}

function M.has(animation)
    return KNOWN[animation] == true
end

function M.resolve(animation, fallback)
    return M.has(animation) and animation or (fallback or "fallback_01")
end

return M
