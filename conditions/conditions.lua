local ids = require "core.ids"
local world_state = require "state.world_state"
local M = {}

local function validate(condition)
    assert(type(condition) == "table", "condition must be a table")
    local is_flag = condition.type ~= nil
    local is_all = condition.all ~= nil
    local is_any = condition.any ~= nil
    local is_not = condition["not"] ~= nil
    local forms = (is_flag and 1 or 0) + (is_all and 1 or 0) + (is_any and 1 or 0) + (is_not and 1 or 0)
    assert(forms == 1, "condition requires exactly one condition form")
    if is_flag then
        assert(condition.type == "flag", "unknown condition type: " .. tostring(condition.type))
        ids.require_stable(condition.id, "condition flag id")
        assert(type(condition.equals) == "boolean", "flag condition equals must be boolean")
    elseif is_all or is_any then
        local group = is_all and condition.all or condition.any
        assert(type(group) == "table" and #group > 0, "condition group must not be empty")
        for _, child in ipairs(group) do validate(child) end
    else
        validate(condition["not"])
    end
    return true
end

function M.validate(condition)
    return validate(condition)
end

local function evaluate(condition, state)
    if condition.type then return world_state.get_flag(state, condition.id) == condition.equals end
    if condition.all then
        for _, child in ipairs(condition.all) do if not evaluate(child, state) then return false end end
        return true
    end
    if condition.any then
        for _, child in ipairs(condition.any) do if evaluate(child, state) then return true end end
        return false
    end
    return not evaluate(condition["not"], state)
end

function M.evaluate(condition, context)
    validate(condition)
    assert(type(context) == "table" and type(context.world_state) == "table",
        "condition context requires world_state")
    return evaluate(condition, context.world_state)
end

return M
