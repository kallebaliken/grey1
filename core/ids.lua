local M = {}

function M.require_stable(id, label)
    assert(type(id) == "string" and id ~= "", (label or "id") .. " must be a stable non-empty string")
    assert(id:match("^[%w%._%-]+$"), (label or "id") .. " contains unsupported characters")
    return id
end

function M.new_allocator(existing)
    local used, counters = {}, {}
    local allocator = {}
    function allocator:reserve(id)
        M.require_stable(id)
        assert(not used[id], "duplicate reserved id: " .. id)
        used[id] = true
        return id
    end
    function allocator:next(prefix)
        M.require_stable(prefix, "id prefix")
        local value = counters[prefix] or 0
        repeat
            value = value + 1
        until not used[string.format("%s.%06d", prefix, value)]
        counters[prefix] = value
        return self:reserve(string.format("%s.%06d", prefix, value))
    end
    for _, id in ipairs(existing or {}) do allocator:reserve(id) end
    return allocator
end

return M
