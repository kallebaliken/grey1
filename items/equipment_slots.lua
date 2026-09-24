-- Canonical Greyhaven equipment layout. Add future slots here, not in policies.
local definitions = {
    { id = "head" },
    { id = "torso" },
    { id = "legs" },
    { id = "feet" },
    { id = "neck" },
    { id = "ring" },
    { id = "main_hand" },
    { id = "off_hand" },
}

local by_id = {}
for _, definition in ipairs(definitions) do by_id[definition.id] = true end

local M = {}
function M.has(id) return by_id[id] == true end
function M.get_definitions()
    local result = {}
    for index, definition in ipairs(definitions) do result[index] = { id = definition.id } end
    return result
end
return M
