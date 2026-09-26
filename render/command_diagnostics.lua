local M = {}

function M.summarize(commands)
    local result = { total = #commands, ground = 0, world_objects = 0, multi_piece = 0,
        items = 0, actors = 0, roofs = 0 }
    for _, command in ipairs(commands) do
        local category = command.category
        if category == "ground" then result.ground = result.ground + 1
        elseif category == "world_object" then result.world_objects = result.world_objects + 1
        elseif category == "item" then result.items = result.items + 1
        elseif category == "actor" then result.actors = result.actors + 1
        elseif category == "roof" then result.roofs = result.roofs + 1 end
        if command.multi_piece then result.multi_piece = result.multi_piece + 1 end
    end
    return result
end

return M
