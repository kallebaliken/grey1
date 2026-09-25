local ids = require "core.ids"
local world_state = require "state.world_state"
local quest_statuses = require "quests.quest_statuses"
local quests = require "quests.quests"
local M = {}

local function find_objective(definition, objective_id)
    for _, objective in ipairs(definition.objectives) do
        if objective.id == objective_id then return objective end
    end
    return nil
end

local function validate(condition, quest_registry)
    assert(type(condition) == "table", "condition must be a table")
    local is_typed = condition.type ~= nil
    local is_all = condition.all ~= nil
    local is_any = condition.any ~= nil
    local is_not = condition["not"] ~= nil
    local forms = (is_typed and 1 or 0) + (is_all and 1 or 0) + (is_any and 1 or 0) + (is_not and 1 or 0)
    assert(forms == 1, "condition requires exactly one condition form")
    if is_typed then
        if condition.type == "flag" then
            ids.require_stable(condition.id, "condition flag id")
            assert(type(condition.equals) == "boolean", "flag condition equals must be boolean")
        elseif condition.type == "quest_status" then
            assert(type(quest_registry) == "table" and type(quest_registry.get) == "function"
                and type(quest_registry.has) == "function",
                "quest condition validation requires quest registry")
            ids.require_stable(condition.id, "condition quest id")
            assert(quest_registry:has(condition.id), "unknown condition quest: " .. condition.id)
            assert(quest_statuses.is_valid(condition.equals), "invalid quest condition status")
        elseif condition.type == "quest_objective" then
            assert(type(quest_registry) == "table" and type(quest_registry.get) == "function",
                "quest condition validation requires quest registry")
            ids.require_stable(condition.quest_id, "condition quest id")
            ids.require_stable(condition.objective_id, "condition objective id")
            local definition = quest_registry:get(condition.quest_id)
            assert(definition, "unknown condition quest: " .. condition.quest_id)
            assert(find_objective(definition, condition.objective_id),
                "unknown condition quest objective: " .. condition.objective_id)
            assert(type(condition.complete) == "boolean", "quest objective condition complete must be boolean")
        else
            error("unknown condition type: " .. tostring(condition.type))
        end
    elseif is_all or is_any then
        local group = is_all and condition.all or condition.any
        assert(type(group) == "table" and #group > 0, "condition group must not be empty")
        for _, child in ipairs(group) do validate(child, quest_registry) end
    else
        validate(condition["not"], quest_registry)
    end
    return true
end

function M.validate(condition, quest_registry)
    return validate(condition, quest_registry)
end

local function evaluate(condition, context)
    if condition.type == "flag" then
        return world_state.get_flag(context.world_state, condition.id) == condition.equals
    elseif condition.type == "quest_status" then
        return quests.get_status(context.quests, condition.id) == condition.equals
    elseif condition.type == "quest_objective" then
        local complete = quests.is_objective_complete(context.quests, condition.quest_id, condition.objective_id)
        return complete == condition.complete
    end
    if condition.all then
        for _, child in ipairs(condition.all) do if not evaluate(child, context) then return false end end
        return true
    end
    if condition.any then
        for _, child in ipairs(condition.any) do if evaluate(child, context) then return true end end
        return false
    end
    return not evaluate(condition["not"], context)
end

local function uses_quests(condition)
    if condition.type then return condition.type == "quest_status" or condition.type == "quest_objective" end
    for _, child in ipairs(condition.all or condition.any or {}) do
        if uses_quests(child) then return true end
    end
    return condition["not"] and uses_quests(condition["not"]) or false
end

function M.evaluate(condition, context)
    assert(type(context) == "table", "condition context must be a table")
    validate(condition, context.quest_registry)
    assert(type(context) == "table" and type(context.world_state) == "table",
        "condition context requires world_state")
    if uses_quests(condition) then
        assert(type(context.quests) == "table", "quest condition context requires quests")
    end
    return evaluate(condition, context)
end

return M
