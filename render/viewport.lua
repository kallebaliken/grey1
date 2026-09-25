local M = {}

function M.new(center_x, center_y, width, height, margin)
    assert(type(center_x) == "number" and type(center_y) == "number", "viewport center must be numeric")
    assert(type(width) == "number" and width > 0 and type(height) == "number" and height > 0,
        "viewport dimensions must be positive")
    margin = margin or 0
    assert(type(margin) == "number" and margin >= 0, "viewport margin must be non-negative")
    return {
        min_x = math.floor(center_x - width / 2) - margin,
        max_x = math.ceil(center_x + width / 2) + margin,
        min_y = math.floor(center_y - height / 2) - margin,
        max_y = math.ceil(center_y + height / 2) + margin,
    }
end

function M.intersects(viewport, x, y, width, height)
    width, height = width or 1, height or 1
    return x + width - 1 >= viewport.min_x and x <= viewport.max_x
        and y + height - 1 >= viewport.min_y and y <= viewport.max_y
end

return M
