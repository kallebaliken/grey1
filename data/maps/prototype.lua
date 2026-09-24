local placements, sequence = {}, 0
local function place(object_type, x, y, z, options)
    options = options or {}; sequence = sequence + 1
    placements[#placements + 1] = { id = options.id or string.format("greyhaven.test.obj_%04d", sequence),
        type = object_type, x = x, y = y, z = z, variant = options.variant or 1,
        state = options.state or {}, metadata = options.metadata or {} }
end

for y = 0, 13 do for x = 0, 17 do place((x == 8 or x == 9) and "dirt" or "grass", x, y, 7) end end

-- Cottage at Z7. Interior markers are logical ground details used by roof policy.
for y = 4, 7 do for x = 3, 6 do
    place("wood_floor", x, y, 7)
    place("interior", x, y, 7, { metadata = { interior_group = "house_01" } })
end end
place("wall_block", 3, 8, 7); place("wall_block", 5, 8, 7)
for y = 4, 7 do place("wall", 2, y, 7); place("wall", 7, y, 7) end
place("wall_block", 3, 3, 7); place("wall", 5, 3, 7)
place("wood_door", 6, 3, 7, { id = "greyhaven.house01.front_door", state = { open = false },
    metadata = { reveal_zone = { x1 = 6, y1 = 2, x2 = 6, y2 = 3, z = 7, roof_group = "house_01" } } })
place("table", 4, 6, 7); place("chest", 3, 6, 7, { id = "greyhaven.house01.chest" })
place("stairs", 5, 7, 7, { id = "greyhaven.house01.stairs_down",
    metadata = { transition = { x = 5, y = 5, z = 6 } } })
for _, p in ipairs({ {3,4}, {5,4}, {3,6}, {5,6} }) do
    place("roof", p[1], p[2], 8, { metadata = { roof_group = "house_01" } })
end

-- Basement at Z6 with a return stair; only this level is interactive after transition.
for y = 3, 7 do for x = 3, 7 do place("basement_floor", x, y, 6) end end
for x = 3, 7 do place("wall", x, 2, 6); place("wall", x, 8, 6) end
for y = 3, 7 do place("wall", 2, y, 6); place("wall", 8, y, 6) end
place("stairs", 5, 4, 6, { id = "greyhaven.house01.stairs_up",
    metadata = { transition = { x = 5, y = 6, z = 7 } } })

return { version = 1, id = "greyhaven.engine_test", tile_size = 32, width = 18, height = 14,
    player_spawn = { x = 9, y = 2, z = 7, facing = "west" }, placements = placements,
    item_placements = {
        { id = "world.test.herbs.01", item = { id = "test.herbs.01", type = "healing_herb", quantity = 10,
            state = { quality = "fresh" } },
            position = { x = 8, y = 2, z = 7 } },
        { id = "world.test.key.01", item = { id = "test.key.01", type = "old_iron_key" },
            position = { x = 10, y = 2, z = 7 } },
    },
    player_inventory = { id = "inventory.player", owner_id = "player", capacity = 2, items = {
        { id = "test.starter.000001", type = "healing_herb", quantity = 15, state = { quality = "fresh" } },
    } } }
