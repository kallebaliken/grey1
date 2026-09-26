local M = {}
-- Actor and top-object pieces share one Y-sorted world band. The adapter maps
-- the fully sorted list into a small presentation-safe depth interval.
local ORDER = { ground = 10, ground_detail = 20, bottom = 30, actor = 40, top = 40, effect = 50, roof = 60 }
local TIE = { actor = 0, top = 1 }
function M.value(layer) return assert(ORDER[layer], "unknown render layer: " .. tostring(layer)) end
function M.tie(layer) return TIE[layer] or 0 end
function M.less(a, b)
    if a.order ~= b.order then return a.order < b.order end
    local ay, by = a.sort_y or a.y, b.sort_y or b.y
    if ay ~= by then return ay > by end
    if (a.tie or 0) ~= (b.tie or 0) then return (a.tie or 0) < (b.tie or 0) end
    local ax, bx = a.sort_x or a.x, b.sort_x or b.x
    if ax ~= bx then return ax < bx end
    return a.id < b.id
end
return M
