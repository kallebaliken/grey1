local instance_api = require "world.object_instance"
local order = require "render.render_order"
local roofs = require "world.roofs"
local z_levels = require "world.z_levels"
local world_items = require "world.world_items"
local actor_renderer = require "render.actor_renderer"
local viewport_api = require "render.viewport"
local render_definition = require "render.render_definition"
local M = {}

local function append(commands, instance, definition, state, visible, viewed_z, revealed, viewport, category)
    local is_roof = definition.stack_layer == "roof"
    local render = visible[instance.position.z] and (instance.position.z == viewed_z or is_roof)
    if is_roof and revealed[instance.metadata and instance.metadata.roof_group] then render = false end
    if not render then return end
    local pieces = render_definition.resolve(definition.render, state, instance.variant)
    for index, piece in ipairs(pieces) do
        local piece_x = instance.position.x + piece.offset_x / 32
        local piece_y = instance.position.y + piece.offset_y / 32
        if viewport_api.intersects(viewport, piece_x, piece_y) then
            commands[#commands + 1] = { id = instance.id .. ":" .. index,
                object_id = instance.id, piece_index = index,
                x = instance.position.x, y = instance.position.y, z = instance.position.z,
                sort_x = piece_x, sort_y = piece_y,
                offset_x = piece.offset_x, offset_y = piece.offset_y,
                order = order.value(definition.stack_layer), tie = order.tie(definition.stack_layer),
                animation = piece.animation, category = is_roof and "roof" or category,
                multi_piece = #pieces > 1 }
        end
    end
end

function M.build(world, player, inspection_offset, viewport, creature_service)
    local commands, revealed = {}, roofs.revealed_groups(world, player)
    local visible, viewed_z = z_levels.get_visible_levels(player.position.z, inspection_offset)
    viewport = viewport or viewport_api.new(player.position.x, player.position.y, 30, 20, 2)
    for _, instance in pairs(world.objects) do
        local definition = world.registry:get(instance.type)
        local category = (definition.stack_layer == "ground" or definition.stack_layer == "ground_detail")
            and "ground" or "world_object"
        append(commands, instance, definition, instance_api.state(instance, world.state), visible, viewed_z,
            revealed, viewport, category)
    end
    for _, world_item in ipairs(world_items.get_all(world)) do
        local definition = world.item_registry:get(world_item.item.type)
        append(commands, world_item, definition, world_item.item.state, visible, viewed_z, revealed,
            viewport, "item")
    end
    actor_renderer.append(commands, world, viewed_z, viewport, creature_service)
    table.sort(commands, order.less)
    return commands, revealed
end
return M
