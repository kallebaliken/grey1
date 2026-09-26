local M = {}
local render_definition = require "render.render_definition"
local methods = {}
methods.__index = methods

function M.new(definitions)
    local self = setmetatable({ definitions = {} }, methods)
    for id, definition in pairs(definitions) do
        assert(definition.id == id, "object definition key/id mismatch: " .. id)
        assert(definition.patterns and #definition.patterns > 0, "object needs a pattern: " .. id)
        render_definition.normalize(definition.render)
        self.definitions[id] = definition
    end
    return self
end

function methods:get(id) return assert(self.definitions[id], "unknown object type: " .. tostring(id)) end
return M
