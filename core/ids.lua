local M = {}

function M.require_stable(id, label)
    assert(type(id) == "string" and id ~= "", (label or "id") .. " must be a stable non-empty string")
    assert(id:match("^[%w%._%-]+$"), (label or "id") .. " contains unsupported characters")
    return id
end

return M
