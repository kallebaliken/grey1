local M = {}

-- Canonical virtual-client hit rectangles. Centres and sizes match the authored
-- slot nodes in main/world.gui; sidebar-local X coordinates include its +960 X.
local EQUIPMENT_SIZE = 28
local INVENTORY_SIZE = 34

local function centred_rect(x, y, size)
    return { x = x - size / 2, y = y - size / 2, width = size, height = size }
end

M.EQUIPMENT_SLOTS = {
    head = centred_rect(1120, 484, EQUIPMENT_SIZE),
    torso = centred_rect(1120, 424, EQUIPMENT_SIZE),
    legs = centred_rect(1120, 364, EQUIPMENT_SIZE),
    feet = centred_rect(1120, 334, EQUIPMENT_SIZE),
    neck = centred_rect(1055, 454, EQUIPMENT_SIZE),
    ring = centred_rect(1185, 454, EQUIPMENT_SIZE),
    main_hand = centred_rect(1055, 394, EQUIPMENT_SIZE),
    off_hand = centred_rect(1185, 394, EQUIPMENT_SIZE),
}

M.EQUIPMENT_ORDER = { "head", "torso", "legs", "feet", "neck", "ring", "main_hand", "off_hand" }

M.INVENTORY_SLOTS = {}
for index = 1, 16 do
    local column = (index - 1) % 4
    local row = math.floor((index - 1) / 4)
    M.INVENTORY_SLOTS[index] = centred_rect(1030 + column * 60, 244 - row * 40, INVENTORY_SIZE)
end
M.INVENTORY_PANEL = { x = 976, y = 78, width = 288, height = 220 }

function M.contains(rect, x, y)
    return x >= rect.x and x < rect.x + rect.width and y >= rect.y and y < rect.y + rect.height
end

return M
