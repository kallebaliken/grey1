local ids = require "core.ids"
local M = {}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

function M.new(saved)
    saved = saved or {}
    return { objects = copy(saved.objects or {}), flags = copy(saved.flags or {}) }
end

function M.get_object(state, id)
    return state.objects[id]
end

function M.patch_object(state, id, patch)
    local current = state.objects[id] or {}
    for key, value in pairs(patch) do current[key] = copy(value) end
    state.objects[id] = current
    return current
end

function M.get_flag(state, id)
    ids.require_stable(id, "world flag id")
    return state.flags[id] == true
end

function M.has_flag(state, id)
    ids.require_stable(id, "world flag id")
    return state.flags[id] ~= nil
end

function M.set_flag(state, id, value)
    ids.require_stable(id, "world flag id")
    assert(type(value) == "boolean", "world flag value must be boolean")
    state.flags[id] = value
    return value
end

function M.copy(value) return copy(value) end

return M
