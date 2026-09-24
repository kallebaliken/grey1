local M = {}
local ORDER = { ground = 10, ground_detail = 20, bottom = 30, top = 40, actor = 50, effect = 60, roof = 70 }

local function less(a, b)
    local ao, bo = ORDER[a.definition.stack_layer] or 40, ORDER[b.definition.stack_layer] or 40
    if ao ~= bo then return ao < bo end
    return a.instance.id < b.instance.id
end

function M.new(x, y, z)
    return { x = x, y = y, z = z, objects = {}, actor_id = nil }
end

function M.insert(tile, instance, definition)
    tile.objects[#tile.objects + 1] = { instance = instance, definition = definition }
    table.sort(tile.objects, less)
end

function M.remove(tile, object_id)
    for index, entry in ipairs(tile.objects) do
        if entry.instance.id == object_id then table.remove(tile.objects, index); return true end
    end
    return false
end

function M.has_ground(tile)
    for _, entry in ipairs(tile.objects) do if entry.definition.stack_layer == "ground" then return true end end
    return false
end

return M
