local M = {}

function M.new(callbacks, options)
    assert(type(callbacks) == "table" and type(callbacks.create) == "function"
        and type(callbacks.update) == "function" and type(callbacks.remove) == "function",
        "sprite reconciler requires create/update/remove callbacks")
    options = options or {}
    assert(options.max_active == nil or (type(options.max_active) == "number" and options.max_active >= 0),
        "sprite reconciler max_active must be non-negative")
    return { callbacks = callbacks, instances = {}, max_active = options.max_active, last = {
        active = 0, created = 0, reused = 0, removed = 0, failures = 0, deferred = 0,
    } }
end

function M.synchronize(reconciler, commands)
    local seen = {}
    local stats = { active = 0, created = 0, reused = 0, removed = 0, failures = 0, deferred = 0 }
    local prior_active = 0
    for _ in pairs(reconciler.instances) do prior_active = prior_active + 1 end
    local creation_slots = reconciler.max_active and math.max(0, reconciler.max_active - prior_active) or math.huge
    for index, command in ipairs(commands) do
        local entry = reconciler.instances[command.id]
        if entry then
            stats.reused = stats.reused + 1
        elseif creation_slots > 0 then
            local handle = reconciler.callbacks.create(command)
            if handle then
                creation_slots = creation_slots - 1
                entry = { handle = handle, animation = nil }
                reconciler.instances[command.id] = entry
                stats.created = stats.created + 1
            else
                stats.failures = stats.failures + 1
            end
        else
            stats.deferred = stats.deferred + 1
        end
        if entry then
            seen[command.id] = true
            local animation_changed = entry.animation ~= command.animation
            reconciler.callbacks.update(entry.handle, command, index, #commands, animation_changed)
            entry.animation = command.animation
        end
    end
    for piece_id, entry in pairs(reconciler.instances) do
        if not seen[piece_id] then
            reconciler.callbacks.remove(entry.handle)
            reconciler.instances[piece_id] = nil
            stats.removed = stats.removed + 1
        end
    end
    for _ in pairs(reconciler.instances) do stats.active = stats.active + 1 end
    reconciler.last = stats
    return stats
end

function M.clear(reconciler)
    for _, entry in pairs(reconciler.instances) do reconciler.callbacks.remove(entry.handle) end
    reconciler.instances = {}
    reconciler.last = { active = 0, created = 0, reused = 0, removed = 0, failures = 0, deferred = 0 }
end

function M.get_stats(reconciler)
    local stats = {}; for key, value in pairs(reconciler.last) do stats[key] = value end
    return stats
end

return M
