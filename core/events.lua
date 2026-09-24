-- Greyhaven original code. Event delivery is synchronous and local to the game session.
local M = {}
local listeners = {}

function M.on(name, callback)
    assert(type(name) == "string" and type(callback) == "function")
    local bucket = listeners[name] or {}
    listeners[name] = bucket
    bucket[#bucket + 1] = callback
    return callback
end

function M.off(name, callback)
    local bucket = listeners[name]
    if not bucket then return end
    for i = #bucket, 1, -1 do
        if bucket[i] == callback then table.remove(bucket, i) end
    end
end

function M.emit(name, payload)
    local bucket = listeners[name]
    if not bucket then return end
    -- Snapshotting permits listeners to unsubscribe safely during delivery.
    local snapshot = {}
    for i, callback in ipairs(bucket) do snapshot[i] = callback end
    for _, callback in ipairs(snapshot) do callback(payload or {}) end
end

function M.clear()
    listeners = {}
end

return M
