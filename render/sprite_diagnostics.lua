local M = {}
local current = { active = 0, created = 0, reused = 0, removed = 0, failures = 0, deferred = 0 }

function M.set(stats)
    current = {}
    for key, value in pairs(stats) do current[key] = value end
end

function M.get()
    local result = {}
    for key, value in pairs(current) do result[key] = value end
    return result
end

return M
