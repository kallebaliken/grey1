local M = {
    NOT_STARTED = "not_started",
    ACTIVE = "active",
    COMPLETED = "completed",
}

function M.is_valid(value)
    return value == M.NOT_STARTED or value == M.ACTIVE or value == M.COMPLETED
end

return M
