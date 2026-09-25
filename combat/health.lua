local ids = require "core.ids"
local M = {}

local function positive_integer(value, label)
    assert(type(value) == "number" and value == value and value % 1 == 0 and value > 0,
        label .. " must be a positive integer")
end

function M.create(actor_id, max_health, current_health)
    actor_id = ids.require_stable(actor_id, "combat actor id")
    positive_integer(max_health, "max health")
    current_health = current_health == nil and max_health or current_health
    assert(type(current_health) == "number" and current_health == current_health and current_health % 1 == 0
        and current_health >= 0 and current_health <= max_health, "health must be an integer within maximum health")
    return { actor_id = actor_id, max_health = max_health, health = current_health, dead = current_health == 0 }
end

function M.get_current(state) return state.health end
function M.get_max(state) return state.max_health end
function M.is_dead(state) return state.dead end

function M.damage(state, amount)
    positive_integer(amount, "damage")
    assert(not state.dead, "actor_dead")
    local previous = state.health
    state.health = math.max(0, previous - amount)
    state.dead = state.health == 0
    return { previous_health = previous, health = state.health, damage = amount, died = state.dead }
end

function M.snapshot(state)
    return { actor_id = state.actor_id, max_health = state.max_health, health = state.health, dead = state.dead }
end

return M
