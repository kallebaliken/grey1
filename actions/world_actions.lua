local ids = require "core.ids"
local world_state = require "state.world_state"
local quests = require "quests.quests"
local M = {}

local allowed_fields = {
    set_flag = { type = true, id = true, value = true },
    start_quest = { type = true, id = true },
    advance_quest = { type = true, id = true, objective_id = true, amount = true },
    complete_quest = { type = true, id = true },
}

local function find_objective(definition, objective_id)
    for _, objective in ipairs(definition.objectives) do
        if objective.id == objective_id then return objective end
    end
    return nil
end

local function validate_fields(action)
    local allowed = allowed_fields[action.type]
    assert(allowed, "unknown world action type: " .. tostring(action.type))
    for key in pairs(action) do
        assert(allowed[key], "unknown " .. action.type .. " action field: " .. tostring(key))
    end
end

local function validate(action, quest_registry)
    assert(type(action) == "table", "world action must be a table")
    validate_fields(action)
    if action.type == "set_flag" then
        ids.require_stable(action.id, "world action flag id")
        assert(type(action.value) == "boolean", "set_flag action value must be boolean")
        return true
    end

    assert(type(quest_registry) == "table" and type(quest_registry.get) == "function",
        "quest action validation requires quest registry")
    ids.require_stable(action.id, "world action quest id")
    local definition = quest_registry:get(action.id)
    assert(definition, "unknown world action quest: " .. action.id)
    if action.type == "advance_quest" then
        ids.require_stable(action.objective_id, "world action objective id")
        assert(find_objective(definition, action.objective_id),
            "unknown world action quest objective: " .. action.objective_id)
        assert(type(action.amount) == "number" and action.amount > 0 and action.amount % 1 == 0,
            "advance_quest amount must be a positive integer")
    end
    return true
end

function M.validate(action, quest_registry)
    return validate(action, quest_registry)
end

function M.validate_all(action_list, quest_registry)
    assert(type(action_list) == "table", "world action list must be a table")
    local count = 0
    for key in pairs(action_list) do
        assert(type(key) == "number" and key >= 1 and key % 1 == 0 and key <= #action_list,
            "world action list must be a sequence")
        count = count + 1
    end
    assert(count == #action_list, "world action list must be a sequence")
    for _, action in ipairs(action_list) do validate(action, quest_registry) end
    return true
end

local function validate_context(action_list, context)
    assert(type(context) == "table", "world action context must be a table")
    for _, action in ipairs(action_list) do
        if action.type == "set_flag" then
            assert(type(context.world_state) == "table", "set_flag action context requires world_state")
        else
            assert(type(context.quests) == "table", "quest action context requires quests")
            assert(type(context.quest_registry) == "table", "quest action context requires quest_registry")
        end
    end
end

local function execute_one(action, context)
    if action.type == "set_flag" then
        local previous = world_state.get_flag(context.world_state, action.id)
        world_state.set_flag(context.world_state, action.id, action.value)
        return true, { type = action.type, id = action.id, previous = previous, value = action.value }
    end

    local success, result
    if action.type == "start_quest" then
        success, result = quests.start(context.quests, action.id)
    elseif action.type == "advance_quest" then
        success, result = quests.advance_objective(context.quests, action.id, action.objective_id, action.amount)
    else
        success, result = quests.complete(context.quests, action.id)
    end
    if not success then return false, result end
    local resolved = { type = action.type, id = action.id }
    if action.objective_id then resolved.objective_id = action.objective_id end
    if action.amount then resolved.amount = action.amount end
    if type(result) == "table" then
        for key, value in pairs(result) do resolved[key] = value end
    end
    return true, resolved
end

function M.execute_all(action_list, context, events)
    -- Schema errors never mutate: validate the complete authored list and all
    -- dependencies before executing the first action.
    M.validate_all(action_list, context and context.quest_registry)
    validate_context(action_list, context)
    local results = {}
    for index, action in ipairs(action_list) do
        local success, result = execute_one(action, context)
        if not success then
            -- Runtime failures stop the list. Earlier successful actions remain
            -- committed; rollback is deliberately outside this small executor.
            return nil, { success = false, reason = result, action_index = index,
                type = action.type, id = action.id, results = results }
        end
        results[#results + 1] = result
        if events then events.emit("world_action_executed", result) end
    end
    return results
end

function M.execute(action, context, events)
    local results, failure = M.execute_all({ action }, context, events)
    return results and results[1] or nil, failure
end

return M
