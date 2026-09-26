local M = {}
local world_animations = require "render.world_animations"

M.FALLBACK_ANIMATION = "fallback_01"

local function copy_piece(source, fallback)
    assert(type(source) == "table", "render piece must be a table")
    assert(source.animation == nil or (type(source.animation) == "string" and source.animation ~= ""),
        "render piece animation must be non-empty")
    assert(source.offset_x == nil or type(source.offset_x) == "number", "render piece offset_x must be numeric")
    assert(source.offset_y == nil or type(source.offset_y) == "number", "render piece offset_y must be numeric")
    return { animation = world_animations.resolve(source.animation, fallback), offset_x = source.offset_x or 0,
        offset_y = source.offset_y or 0 }
end

function M.normalize(render, fallback_animation)
    local fallback = fallback_animation or M.FALLBACK_ANIMATION
    if render == nil then return { pieces = { copy_piece({}, fallback) } } end
    assert(type(render) == "table", "render definition must be a table")
    assert(not (render.animation and render.pieces), "render definition cannot combine animation and pieces")
    if render.variants then
        assert(type(render.variants) == "table" and #render.variants > 0,
            "render variants must be a non-empty sequence")
        for _, animation in ipairs(render.variants) do
            assert(type(animation) == "string" and animation ~= "", "render variant must be non-empty")
        end
    end
    local normalized = { pieces = {}, variants = render.variants, state_key = render.state_key,
        state_animations = render.state_animations }
    if render.pieces then
        assert(type(render.pieces) == "table" and #render.pieces > 0,
            "render pieces must be a non-empty sequence")
        for _, piece in ipairs(render.pieces) do
            normalized.pieces[#normalized.pieces + 1] = copy_piece(piece, fallback)
        end
    else
        normalized.pieces[1] = copy_piece({ animation = render.animation, offset_x = render.offset_x,
            offset_y = render.offset_y }, fallback)
    end
    if normalized.state_animations ~= nil then
        assert(type(normalized.state_key) == "string" and normalized.state_key ~= "",
            "stateful render requires state_key")
        assert(type(normalized.state_animations) == "table", "state_animations must be a table")
        for _, animation in pairs(normalized.state_animations) do
            assert(type(animation) == "string" and animation ~= "",
                "state animation must be non-empty")
        end
        assert(#normalized.pieces == 1, "state animations currently require a single render piece")
    end
    return normalized
end

function M.resolve(render, state, variant, fallback_animation)
    local normalized = M.normalize(render, fallback_animation)
    if normalized.variants then
        local index = variant or 1
        normalized.pieces[1].animation = world_animations.resolve(
            normalized.variants[index] or normalized.variants[1], normalized.pieces[1].animation)
    end
    if normalized.state_animations then
        local value = state and state[normalized.state_key]
        normalized.pieces[1].animation = world_animations.resolve(
            normalized.state_animations[tostring(value)] or normalized.pieces[1].animation,
            normalized.pieces[1].animation)
    end
    return normalized.pieces
end

return M
