local actor_api = require "actors.actor"
local M = {}

local methods = {}
methods.__index = methods
local records = setmetatable({}, { __mode = "k" })

function M.new()
    local registry = setmetatable({}, methods)
    records[registry] = {}
    return registry
end

function methods:add(actor)
    local owned = records[self]
    assert(not owned[actor.id], "duplicate actor id: " .. actor.id)
    owned[actor.id] = actor
    return actor_api.snapshot(actor)
end

function methods:get(id)
    return records[self][id]
end

function methods:remove(id)
    local actor = records[self][id]
    if not actor then return nil end
    records[self][id] = nil
    return actor_api.snapshot(actor)
end

function methods:get_all()
    local result = {}
    for _, actor in pairs(records[self]) do result[#result + 1] = actor end
    table.sort(result, function(left, right) return left.id < right.id end)
    return result
end

return M
