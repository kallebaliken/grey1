local M = {}
function M.get_visible_levels(player_z, inspection_offset)
    local viewed = player_z + (inspection_offset or 0)
    return { [viewed] = true, [viewed + 1] = true }, viewed
end
return M
