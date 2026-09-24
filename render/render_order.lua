local M = {}
local ORDER = { ground = 10, ground_detail = 20, bottom = 30, top = 40, actor = 50, effect = 60, roof = 70 }
function M.value(layer) return assert(ORDER[layer], "unknown render layer: " .. tostring(layer)) end
function M.less(a, b)
    if a.order ~= b.order then return a.order < b.order end
    if a.y ~= b.y then return a.y > b.y end
    if a.x ~= b.x then return a.x < b.x end
    return a.id < b.id
end
return M
