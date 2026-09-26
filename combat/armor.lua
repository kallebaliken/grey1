local equipment_api = require "items.equipment"
local M = {}

function M.resolve(equipment, item_registry, incoming_damage)
    assert(type(incoming_damage) == "number" and incoming_damage > 0 and incoming_damage % 1 == 0,
        "incoming damage must be a positive integer")
    local sources, total = {}, 0
    if equipment and item_registry then
        for slot, item in pairs(equipment_api.get_items(equipment)) do
            local definition = item_registry:get(item.type)
            if definition.armor then
                sources[#sources + 1] = { slot = slot, item_id = item.id,
                    item_type = item.type, defense = definition.armor.defense }
                total = total + definition.armor.defense
            end
        end
        table.sort(sources, function(left, right)
            if left.slot ~= right.slot then return left.slot < right.slot end
            return left.item_id < right.item_id
        end)
    end
    return { incoming_damage = incoming_damage, armor = total,
        final_damage = math.max(1, incoming_damage - total), sources = sources }
end

return M
