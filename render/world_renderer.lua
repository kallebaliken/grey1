local instance_api = require "world.object_instance"
local order = require "render.render_order"
local roofs = require "world.roofs"
local z_levels = require "world.z_levels"
local world_items = require "world.world_items"
local actor_renderer = require "render.actor_renderer"
local M = {}

local function append(commands, instance, definition, state, visible, viewed_z, revealed)
    local is_roof = definition.stack_layer == "roof"
    local render = visible[instance.position.z] and (instance.position.z == viewed_z or is_roof)
    if is_roof and revealed[instance.metadata and instance.metadata.roof_group] then render = false end
    if not render then return end
    local patterns = definition.state_patterns and definition.state_patterns(state) or definition.patterns
    local pattern = patterns[instance.variant or 1] or patterns[1]
    for index, color in ipairs(pattern) do
        local width = definition.graphical_width or 1
        commands[#commands + 1] = { id = instance.id .. ":" .. index,
            x = instance.position.x + (index - 1) % width,
            y = instance.position.y + math.floor((index - 1) / width), z = instance.position.z,
            order = order.value(definition.stack_layer), color = color }
    end
end

function M.build(world, player, inspection_offset)
    local commands, revealed = {}, roofs.revealed_groups(world, player)
    local visible, viewed_z = z_levels.get_visible_levels(player.position.z, inspection_offset)
    for _, instance in pairs(world.objects) do
        local definition = world.registry:get(instance.type)
        append(commands, instance, definition, instance_api.state(instance, world.state), visible, viewed_z, revealed)
    end
    for _, world_item in ipairs(world_items.get_all(world)) do
        local definition = world.item_registry:get(world_item.item.type)
        append(commands, world_item, definition, world_item.item.state, visible, viewed_z, revealed)
    end
    actor_renderer.append(commands, world, viewed_z)
    table.sort(commands, order.less)
    return commands, revealed
end
return M
