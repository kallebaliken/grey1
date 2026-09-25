local M = {}
local policies = setmetatable({}, { __mode = "k" })

function M.set(actor, capability, policy)
    assert(type(actor) == "table" and type(capability) == "string", "invalid Actor capability")
    assert(policy == nil or type(policy) == "function", "capability policy must be a function")
    local actor_policies = policies[actor]
    if not actor_policies and policy then actor_policies = {}; policies[actor] = actor_policies end
    if actor_policies then
        actor_policies[capability] = policy
        if not next(actor_policies) then policies[actor] = nil end
    end
end

function M.allows(actor, capability)
    local actor_policies = policies[actor]
    local policy = actor_policies and actor_policies[capability]
    return policy == nil or policy(actor) == true
end

function M.clear(actor)
    policies[actor] = nil
end

return M
