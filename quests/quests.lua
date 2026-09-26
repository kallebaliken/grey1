local statuses = require "quests.quest_statuses"
local M = {}

local runtimes = setmetatable({}, { __mode = "k" })
local function runtime(service) return assert(runtimes[service], "unknown quest service") end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end

local function emit(service, name, payload)
    if service.events then service.events.emit(name, payload) end
end

local function objective(definition, objective_id)
    for _, entry in ipairs(definition.objectives) do
        if entry.id == objective_id then return entry end
    end
    return nil
end

local function validate_snapshot(registry, snapshot)
    assert(type(snapshot) == "table", "quest snapshot must be a table")
    for quest_id, state in pairs(snapshot) do
        local definition = registry:get(quest_id)
        assert(definition, "unknown saved quest: " .. tostring(quest_id))
        assert(type(state) == "table" and (state.status == statuses.ACTIVE
            or state.status == statuses.COMPLETED), "invalid saved quest status")
        assert(type(state.objectives) == "table", "invalid saved quest objectives")
        local expected = {}
        for _, authored in ipairs(definition.objectives) do
            local progress = state.objectives[authored.id]
            assert(type(progress) == "number" and progress >= 0 and progress <= authored.target
                and progress % 1 == 0, "invalid saved objective progress")
            if state.status == statuses.COMPLETED then
                assert(progress == authored.target, "completed quest has incomplete objective")
            end
            expected[authored.id] = true
        end
        for objective_id in pairs(state.objectives) do
            assert(expected[objective_id], "unknown saved objective: " .. tostring(objective_id))
        end
    end
    return true
end

function M.create(registry, events, snapshot)
    assert(type(registry) == "table" and type(registry.get) == "function", "quests require a registry")
    snapshot = snapshot or {}
    validate_snapshot(registry, snapshot)
    local service = { registry = registry, events = events }
    runtimes[service] = { states = copy(snapshot) }
    return service
end

function M.validate_snapshot(registry, snapshot)
    return validate_snapshot(registry, snapshot)
end

function M.get_status(service, quest_id)
    if not service.registry:has(quest_id) then return nil, "unknown_quest" end
    local state = runtime(service).states[quest_id]
    return state and state.status or statuses.NOT_STARTED
end

function M.start(service, quest_id)
    local definition = service.registry:get(quest_id)
    if not definition then return false, "unknown_quest" end
    local existing = runtime(service).states[quest_id]
    if existing then return false, existing.status == statuses.ACTIVE and "already_active" or "already_completed" end
    local state = { status = statuses.ACTIVE, objectives = {} }
    for _, authored in ipairs(definition.objectives) do state.objectives[authored.id] = 0 end
    runtime(service).states[quest_id] = state
    emit(service, "quest_started", { quest_id = quest_id, status = statuses.ACTIVE })
    return true, copy(state)
end

function M.get_objective_progress(service, quest_id, objective_id)
    local definition = service.registry:get(quest_id)
    if not definition then return nil, "unknown_quest" end
    if not objective(definition, objective_id) then return nil, "unknown_objective" end
    local state = runtime(service).states[quest_id]
    if not state then return nil, "not_started" end
    return state.objectives[objective_id]
end

function M.is_objective_complete(service, quest_id, objective_id)
    local definition = service.registry:get(quest_id)
    if not definition then return false, "unknown_quest" end
    local authored = objective(definition, objective_id)
    if not authored then return false, "unknown_objective" end
    local progress, reason = M.get_objective_progress(service, quest_id, objective_id)
    if progress == nil then return false, reason end
    return progress == authored.target
end

function M.advance_objective(service, quest_id, objective_id, amount)
    amount = amount or 1
    if type(amount) ~= "number" or amount <= 0 or amount % 1 ~= 0 then return false, "invalid_amount" end
    local definition = service.registry:get(quest_id)
    if not definition then return false, "unknown_quest" end
    local authored = objective(definition, objective_id)
    if not authored then return false, "unknown_objective" end
    local state = runtime(service).states[quest_id]
    if not state then return false, "not_started" end
    if state.status ~= statuses.ACTIVE then return false, "quest_completed" end
    local previous = state.objectives[objective_id]
    if previous == authored.target then return false, "objective_completed" end
    local progress = math.min(authored.target, previous + amount)
    state.objectives[objective_id] = progress
    local payload = { quest_id = quest_id, objective_id = objective_id, previous = previous,
        progress = progress, target = authored.target }
    emit(service, "quest_objective_progressed", payload)
    if progress == authored.target then emit(service, "quest_objective_completed", payload) end
    return true, copy(payload)
end

function M.complete(service, quest_id)
    local definition = service.registry:get(quest_id)
    if not definition then return false, "unknown_quest" end
    local state = runtime(service).states[quest_id]
    if not state then return false, "not_started" end
    if state.status == statuses.COMPLETED then return false, "already_completed" end
    for _, authored in ipairs(definition.objectives) do
        if state.objectives[authored.id] ~= authored.target then return false, "objectives_incomplete" end
    end
    state.status = statuses.COMPLETED
    emit(service, "quest_completed", { quest_id = quest_id, status = statuses.COMPLETED })
    return true, copy(state)
end

function M.get_snapshot(service)
    return copy(runtime(service).states)
end

return M
