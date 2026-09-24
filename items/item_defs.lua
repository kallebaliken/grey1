-- Original Greyhaven content. These records describe item types, not owned items.
return {
    healing_herb = {
        id = "healing_herb",
        name = "Healing Herb",
        stackable = true,
        max_stack = 20,
        weight = 0.1,
        tags = { "consumable", "herb" },
        pickupable = true,
        stack_layer = "bottom",
        interaction = "pickup",
        patterns = { { { 0.25, 0.72, 0.28, 1 } } },
    },
    old_iron_key = {
        id = "old_iron_key",
        name = "Old Iron Key",
        stackable = false,
        weight = 0.2,
        tags = { "key" },
        pickupable = true,
        stack_layer = "bottom",
        interaction = "pickup",
        patterns = { { { 0.88, 0.72, 0.20, 1 } } },
    },
    worn_iron_sword = {
        id = "worn_iron_sword", name = "Worn Iron Sword", pickupable = true,
        tags = { "equipment", "weapon" }, stack_layer = "bottom", interaction = "pickup",
        patterns = { { { 0.66, 0.68, 0.72, 1 } } },
        equipment = { slots = { "main_hand", "off_hand" } },
    },
    leather_cap = {
        id = "leather_cap", name = "Leather Cap", pickupable = true,
        tags = { "equipment", "armor" }, stack_layer = "bottom", interaction = "pickup",
        patterns = { { { 0.47, 0.28, 0.14, 1 } } },
        equipment = { slots = { "head" } },
    },
    patched_leather_armor = {
        id = "patched_leather_armor", name = "Patched Leather Armor", pickupable = true,
        tags = { "equipment", "armor" }, stack_layer = "bottom", interaction = "pickup",
        patterns = { { { 0.40, 0.23, 0.12, 1 } } },
        equipment = { slots = { "torso" } },
    },
}
