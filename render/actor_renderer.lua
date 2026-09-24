local movement = require "simulation.movement"
local order = require "render.render_order"
local viewport_api = require "render.viewport"
local M = {}

local COLORS = {
    player = { 0.20, 0.45, 0.92, 1 },
    npc = { 0.78, 0.48, 0.24, 1 },
    monster = { 0.72, 0.20, 0.24, 1 },
}

function M.append(commands, world, viewed_z, viewport)
    for _, actor in ipairs(world:get_actors()) do
        if actor.active and actor.position.z == viewed_z
            and viewport_api.intersects(viewport, actor.position.x, actor.position.y) then
            local visual = movement.visual_position(actor)
            commands[#commands + 1] = { id = actor.id .. ":actor", x = visual.x, y = visual.y, z = visual.z,
                order = order.value("actor"), color = COLORS[actor.type], size = 22 }
        end
    end
end

return M
