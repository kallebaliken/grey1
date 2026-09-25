local function solid(color) return { color } end
local green, dirt, wood = { .25, .46, .22, 1 }, { .46, .34, .20, 1 }, { .48, .31, .18, 1 }
local closed_door, open_door = { .43, .24, .10, 1 }, { .70, .48, .20, .65 }

return {
    grass = { id = "grass", stack_layer = "ground", patterns = { solid(green) } },
    dirt = { id = "dirt", stack_layer = "ground", patterns = { solid(dirt) } },
    wood_floor = { id = "wood_floor", stack_layer = "ground", patterns = { solid(wood) } },
    basement_floor = { id = "basement_floor", stack_layer = "ground", patterns = { solid({ .22, .24, .25, 1 }) } },
    interior = { id = "interior", stack_layer = "ground_detail", patterns = { solid({ .52, .35, .20, .18 }) } },
    wall_block = { id = "wall_block", stack_layer = "top", graphical_width = 2, graphical_height = 2,
        footprint_width = 1, footprint_height = 1, blocking = true, blocks_sight = true, patterns = { {
            { .45, .48, .52, 1 }, { .55, .58, .61, 1 }, { .31, .33, .36, 1 }, { .37, .39, .42, 1 } } } },
    wall = { id = "wall", stack_layer = "top", blocking = true, blocks_sight = true,
        patterns = { solid({ .42, .44, .47, 1 }) } },
    wood_door = { id = "wood_door", stack_layer = "top", interaction = "door", blocking = true,
        blocking_state = function(state) return not state.open end,
        blocks_sight_state = function(state) return not state.open end,
        state_patterns = function(state) return state.open and { solid(open_door) } or { solid(closed_door) } end,
        patterns = { solid(closed_door) } },
    table = { id = "table", stack_layer = "top", blocking = true, patterns = { solid({ .35, .18, .08, 1 }) } },
    chest = { id = "chest", stack_layer = "top", interaction = "chest", blocking = true,
        patterns = { solid({ .70, .44, .12, 1 }) } },
    stairs = { id = "stairs", stack_layer = "bottom", interaction = "stairs", patterns = { solid({ .25, .52, .60, 1 }) } },
    roof = { id = "roof", stack_layer = "roof", graphical_width = 2, graphical_height = 2,
        footprint_width = 1, footprint_height = 1, patterns = { {
            { .32, .10, .12, .94 }, { .38, .12, .13, .94 }, { .43, .14, .14, .94 }, { .35, .10, .12, .94 } } } },
}
