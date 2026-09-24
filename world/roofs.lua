local M = {}

function M.interior_group(world, position)
    for _, entry in ipairs(world:get_objects(position.x, position.y, position.z)) do
        local metadata = entry.instance.metadata
        if metadata and metadata.interior_group then return metadata.interior_group end
    end
end

function M.revealed_groups(world, player)
    local groups = {}
    local group = M.interior_group(world, player.position)
    if group then groups[group] = true end
    for _, instance in pairs(world.objects) do
        local reveal = instance.metadata.reveal_zone
        if reveal and player.position.z == reveal.z and player.position.x >= reveal.x1
            and player.position.x <= reveal.x2 and player.position.y >= reveal.y1
            and player.position.y <= reveal.y2 then groups[reveal.roof_group] = true end
    end
    return groups
end

return M
