-- Deterministic text codec used by pure-Lua tests and diagnostics. Runtime persistence uses sys.save/sys.load.
local M = {}
local function keys(value)
    local result = {}; for key in pairs(value) do result[#result + 1] = key end
    table.sort(result, function(a, b) return tostring(a) < tostring(b) end); return result
end
local function encode(value)
    local kind = type(value)
    if kind == "nil" then return "nil" elseif kind == "boolean" or kind == "number" then return tostring(value)
    elseif kind == "string" then return string.format("%q", value) elseif kind == "table" then
        local parts = {}; for _, key in ipairs(keys(value)) do
            parts[#parts + 1] = "[" .. encode(key) .. "]=" .. encode(value[key])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    error("unsupported save value: " .. kind)
end
function M.serialize(value) return "return " .. encode(value) end
function M.deserialize(value)
    local chunk, message
    if loadstring then
        chunk, message = loadstring(value, "greyhaven_save")
        if chunk then setfenv(chunk, {}) end
    else
        chunk, message = load(value, "greyhaven_save", "t", {})
    end
    assert(chunk, message)
    return chunk()
end
return M
