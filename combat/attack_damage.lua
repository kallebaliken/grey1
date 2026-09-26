local equipment_api = require "items.equipment"
local M = {}

function M.resolve(profile, equipment, item_registry)
    assert(type(profile) == "table" and type(profile.damage) == "number", "attack profile is required")
    if equipment and item_registry then
        local item = equipment_api.get(equipment, "main_hand")
        if item then
            local definition = item_registry:get(item.type)
            if definition.weapon then
                return { damage = definition.weapon.damage, source = "weapon",
                    item_id = item.id, item_type = item.type }
            end
        end
    end
    return { damage = profile.damage, source = "unarmed" }
end

return M
