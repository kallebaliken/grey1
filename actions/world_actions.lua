local ids = require "core.ids"
local world_state = require "state.world_state"
local M = {}

local function validate(action)
    assert(type(action) == "table", "world action must be a table")
    assert(action.type == "set_flag", "unknown world action type: " .. tostring(action.type))
    ids.require_stable(action.id, "world action flag id")
    assert(type(action.value) == "boolean", "set_flag action value must be boolean")
    for key in pairs(action) do
        assert(key == "type" or key == "id" or key == "value",
            "unknown set_flag action field: " .. tostring(key))
    end
    return true
end

function M.validate(action)
    return validate(action)
end

function M.validate_all(action_list)
    assert(type(action_list) == "table", "world action list must be a table")
    local count = 0
    for key in pairs(action_list) do
        assert(type(key) == "number" and key >= 1 and key % 1 == 0 and key <= #action_list,
            "world action list must be a sequence")
        count = count + 1
    end
    assert(count == #action_list, "world action list must be a sequence")
    for _, action in ipairs(action_list) do
        validate(action)
    end
    return true
end

local function validate_context(context)
    assert(type(context) == "table" and type(context.world_state) == "table",
        "world action context requires world_state")
end

function M.execute_all(action_list, context, events)
    -- Validate the complete batch and its context before the first mutation. With
    -- set_flag as the only action type, no remaining operation can fail midway.
    M.validate_all(action_list)
    validate_context(context)
    local results = {}
    for _, action in ipairs(action_list) do
        local previous = world_state.get_flag(context.world_state, action.id)
        world_state.set_flag(context.world_state, action.id, action.value)
        local result = { type = action.type, id = action.id, previous = previous, value = action.value }
        results[#results + 1] = result
        if events then events.emit("world_action_executed", result) end
    end
    return results
end

function M.execute(action, context, events)
    return M.execute_all({ action }, context, events)[1]
end

return M
